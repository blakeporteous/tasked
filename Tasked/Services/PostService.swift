//
//  PostService.swift
//  Tasked
//
//  Created by Blake Porteous on 13/08/2025.
//  Updated: fetchFeedPosts is now scoped to the signed-in user's friends (Feature 5),
//  since posts should follow the same privacy rules as profiles.
//  Updated (Feed engagement pass): added like toggling and comments. Likes are
//  stored as a denormalized `likes` counter plus a `likedBy` uid array so the UI
//  can both show a count and know whether the current user has already liked a
//  post, without reading a subcollection — the two are kept in sync via a
//  Firestore transaction. Comments live in a `posts/{postId}/comments`
//  subcollection with a denormalized `commentsCount` on the post itself so
//  FeedCell can show a count cheaply.
//  Updated (own-posts pass): the feed is now friends-only — the signed-in
//  user's own posts no longer show up in their own Home feed. They're still
//  fully visible on the user's own profile grid (PostGridViewModel calls
//  fetchUserPosts separately), this only affects the Home feed query.
//

import Foundation
import Firebase
import FirebaseFirestore

struct PostService {

    private static let postsCollection = Firestore.firestore().collection("posts")

    // MARK: - Live feed (current week, friends only)

    /// Real-time feed scoped to the signed-in user's friends (NOT including
    /// their own posts — see own-posts pass note above) AND to
    /// [weekStart, weekEnd). Firestore's `in` operator caps at 30 values, so
    /// friend lists larger than that get one listener per chunk; every
    /// chunk's latest results are merged and re-sorted client-side whenever
    /// ANY of them reports a change, which is how a friend's new post
    /// appears immediately without the user having to refresh. The caller
    /// owns tearing these down (`ListenerRegistration.remove()`) and
    /// re-creating them with a new [weekStart, weekEnd) when the calendar
    /// week rolls over — see FeedViewModel.
    ///
    /// Firestore index required: composite index on `posts` —
    /// ownerUid (Ascending), timestamp (Ascending). Combining an `in` filter
    /// on one field with a range filter on another always needs a composite
    /// index; Firestore will also print a direct "create it" link in the
    /// Xcode console the first time this runs without one.
    @discardableResult
    static func listenToFeedPosts(
        for currentUser: User,
        weekStart: Date,
        weekEnd: Date,
        onChange: @escaping (Result<[Post], Error>) -> Void
    ) -> [ListenerRegistration] {
        let ownerUids = currentUser.friendUids
        guard !ownerUids.isEmpty else {
            onChange(.success([]))
            return []
        }

        let startTimestamp = Timestamp(date: weekStart)
        let endTimestamp = Timestamp(date: weekEnd)
        let chunks = ownerUids.chunked(into: 30)

        // Keyed by chunk index so a merge always uses each chunk's most
        // recent snapshot, even though chunks report in on their own schedule.
        var latestResultsByChunk: [Int: [Post]] = [:]

        var registrations: [ListenerRegistration] = []

        for (index, chunk) in chunks.enumerated() {
            let registration = postsCollection
                .whereField("ownerUid", in: chunk)
                .whereField("timestamp", isGreaterThanOrEqualTo: startTimestamp)
                .whereField("timestamp", isLessThan: endTimestamp)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        onChange(.failure(error))
                        return
                    }

                    let posts = snapshot?.documents.compactMap { try? $0.data(as: Post.self) } ?? []
                    latestResultsByChunk[index] = posts

                    // Wait for every chunk to have reported at least once so
                    // the UI doesn't flash a partial feed while the rest are
                    // still loading their first snapshot.
                    guard latestResultsByChunk.count == chunks.count else { return }

                    var merged = latestResultsByChunk.values.flatMap { $0 }
                    merged.sort { $0.timestamp.dateValue() > $1.timestamp.dateValue() }

                    Task { @MainActor in
                        let hydrated = await hydrateUsers(for: merged)
                        onChange(.success(hydrated))
                    }
                }
            registrations.append(registration)
        }

        return registrations
    }

    /// Attaches each post's owning User, caching lookups so several posts by
    /// the same friend in one batch only trigger one fetch.
    private static func hydrateUsers(for posts: [Post]) async -> [Post] {
        var posts = posts
        var userCache: [String: User] = [:]
        for i in 0..<posts.count {
            let uid = posts[i].ownerUid
            if let cached = userCache[uid] {
                posts[i].user = cached
            } else if let fetched = try? await UserService.fetchUser(withUid: uid) {
                userCache[uid] = fetched
                posts[i].user = fetched
            }
        }
        return posts
    }

    /// Superseded by listenToFeedPosts(for:weekStart:weekEnd:onChange:) for
    /// the actual feed (real-time + week-scoped). Left in place — unused by
    /// the feed now, but harmless to keep around for any one-shot/all-time
    /// use case (e.g. a future "past weeks" screen).
    ///
    /// Feed = the signed-in user's friends' posts, newest first. Does NOT
    /// include the signed-in user's own posts — see own-posts pass note above.
    static func fetchFeedPosts(for currentUser: User) async throws -> [Post] {
        let ownerUids = currentUser.friendUids
        guard !ownerUids.isEmpty else { return [] }

        var allPosts: [Post] = []
        for chunk in ownerUids.chunked(into: 30) {
            let snapshot = try await postsCollection
                .whereField("ownerUid", in: chunk)
                .getDocuments()
            allPosts += try snapshot.documents.compactMap { try $0.data(as: Post.self) }
        }

        var posts = allPosts.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }

        // Hydrate the owning user for each post. Cache lookups so we don't
        // re-fetch the same user doc once per post.
        var userCache: [String: User] = [:]
        for i in 0..<posts.count {
            let uid = posts[i].ownerUid
            if let cached = userCache[uid] {
                posts[i].user = cached
            } else if let fetched = try? await UserService.fetchUser(withUid: uid) {
                userCache[uid] = fetched
                posts[i].user = fetched
            }
        }

        return posts
    }

    static func fetchUserPosts(uid: String) async throws -> [Post] {
        let snapshot = try await postsCollection.whereField("ownerUid", isEqualTo: uid).getDocuments()
        return try snapshot.documents.compactMap({ try $0.data(as: Post.self) })
    }

    // MARK: - Likes

    /// Toggles the current user's like on `post`. Uses a transaction so the
    /// `likes` counter and `likedBy` array can never drift apart under
    /// concurrent likes. Returns the new liked state (true = now liked). Only
    /// fires a notification when the post goes from unliked -> liked.
    @discardableResult
    static func toggleLike(post: Post, currentUser: User) async throws -> Bool {
        let ref = postsCollection.document(post.id)

        // Typed as `Any?` (rather than `Bool?`) because some FirebaseFirestore SDK
        // versions only expose the non-generic runTransaction overload, which
        // returns Any? — the generic Bool? form silently falls back to Any and
        // won't compile as a Bool condition below without this explicit cast.
        let result: Any? = try await Firestore.firestore().runTransaction { (transaction, errorPointer) -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            var likedBy = snapshot.get("likedBy") as? [String] ?? []
            var likes = snapshot.get("likes") as? Int ?? 0
            let alreadyLiked = likedBy.contains(currentUser.id)

            if alreadyLiked {
                likedBy.removeAll { $0 == currentUser.id }
                likes = max(0, likes - 1)
            } else {
                likedBy.append(currentUser.id)
                likes += 1
            }

            transaction.updateData(["likedBy": likedBy, "likes": likes], forDocument: ref)
            return !alreadyLiked
        }

        guard let nowLiked = result as? Bool else {
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Couldn't update like state."])
        }

        if nowLiked {
            await NotificationService.create(
                recipientUid: post.ownerUid,
                actorUid: currentUser.id,
                type: NotificationType.like,
                postId: post.id
            )
        }

        return nowLiked
    }

    // MARK: - Comments

    /// Adds a comment to `post`, bumps its denormalized `commentsCount`, and
    /// notifies the post's owner. The comment write and the count bump happen
    /// in a batch so the count can't fall out of sync with the actual comments.
    @discardableResult
    static func addComment(to post: Post, text: String, currentUser: User) async throws -> Comment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Comment can't be empty."])
        }

        let commentRef = postsCollection.document(post.id).collection("comments").document()
        let comment = Comment(
            id: commentRef.documentID,
            postId: post.id,
            ownerUid: currentUser.id,
            username: currentUser.username,
            profileImageUrl: currentUser.profileImageUrl,
            text: trimmed,
            timestamp: Timestamp()
        )

        let batch = Firestore.firestore().batch()
        try batch.setData(from: comment, forDocument: commentRef)
        batch.updateData(["commentsCount": FieldValue.increment(Int64(1))], forDocument: postsCollection.document(post.id))
        try await batch.commit()

        await NotificationService.create(
            recipientUid: post.ownerUid,
            actorUid: currentUser.id,
            type: NotificationType.comment,
            postId: post.id
        )

        return comment
    }

    /// Newest-first comments for `postId`.
    static func fetchComments(postId: String) async throws -> [Comment] {
        let snapshot = try await postsCollection.document(postId).collection("comments")
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Comment.self) }
    }
}
