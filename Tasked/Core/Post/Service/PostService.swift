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
//  Updated (Post deletion): added deletePost(_:), which clears the comments
//  subcollection first (Firestore doesn't cascade-delete subcollections) before
//  deleting the post document itself.
//  Updated (Streaks): added createPost(_:ownerUid:), which writes the post and
//  updates the owning user's currentStreak/lastPostWeekStart in one
//  transaction, so a post can never succeed without the streak reflecting it.
//  Updated (Profile-grid live pass): added listenToUserPosts(uid:onChange:), a
//  real-time listener for one user's own posts. Replaces the one-shot
//  fetchUserPosts(uid:) as what backs PostGridView.
//  Updated (Edit comment pass): added editComment(postId:commentId:newText:),
//  which updates a comment's text and flags isEdited. Doesn't bump
//  commentsCount (nothing was added or removed) and doesn't touch the
//  notification that was already sent when the comment was first posted.
//  Updated (Delete comment pass): added deleteComment(postId:commentId:),
//  which removes the comment doc and decrements the post's denormalized
//  commentsCount in one batch so the count can't drift from the actual
//  comment documents. Firestore rules gate WHO may call this — the
//  comment's own owner, or the post's owner acting as moderator.
//  Updated (Delete-to-repost pass): deletePost(_:) now also clears the
//  owner's lastPostWeekStart and rolls currentStreak back by 1 — but only
//  when the deleted post is the one that had set them — in the same
//  transaction as the delete.
//  Updated (Public/private retroactive pass): added
//  updateAllPostsVisibility(ownerUid:isPublic:), called from
//  SettingsViewModel whenever the account-level privacy toggle changes.
//  Chunks into batches of 500 (Firestore's per-batch write cap).
//  Updated (Comment likes + replies pass): addComment(to:text:currentUser:)
//  now takes an optional parentCommentId — passing one turns the write into
//  a REPLY (just another doc in the same subcollection) instead of a
//  top-level comment; commentsCount is bumped the same way either way.
//  Added toggleCommentLike(postId:commentId:currentUser:), mirroring
//  toggleLike(post:) exactly (same transaction shape) but scoped to a
//  comment doc instead of a post doc. Needs a matching Firestore rule (see
//  firestore.rules) — comments previously only allowed the OWNER to update
//  text/isEdited, nothing let another user touch likes/likedBy on it.
//

import Foundation
import Firebase
import FirebaseFirestore

struct PostService {

    private static let postsCollection = Firestore.firestore().collection("posts")

    // MARK: - Live feed (current week, friends + self)

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

    @discardableResult
    static func listenToUserPosts(uid: String, onChange: @escaping (Result<[Post], Error>) -> Void) -> ListenerRegistration {
        postsCollection
            .whereField("ownerUid", isEqualTo: uid)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                var posts = snapshot?.documents.compactMap { try? $0.data(as: Post.self) } ?? []
                posts.sort { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
                onChange(.success(posts))
            }
    }

    // MARK: - Likes (posts)

    @discardableResult
    static func toggleLike(post: Post, currentUser: User) async throws -> Bool {
        let ref = postsCollection.document(post.id)

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

    // MARK: - Comments (and replies)

    /// Adds a comment to `post` — or, if `parentCommentId` is supplied, adds
    /// a REPLY to that top-level comment instead. A reply is just another
    /// document in the same "comments" subcollection with parentCommentId
    /// set; commentsCount is bumped the same way either way, so the count
    /// shown on FeedCell includes replies too.
    @discardableResult
    static func addComment(to post: Post, text: String, currentUser: User, parentCommentId: String? = nil) async throws -> Comment {
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
            timestamp: Timestamp(),
            parentCommentId: parentCommentId
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

    static func editComment(postId: String, commentId: String, newText: String) async throws {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Comment can't be empty."])
        }

        try await postsCollection.document(postId).collection("comments").document(commentId)
            .updateData(["text": trimmed, "isEdited": true])
    }

    static func deleteComment(postId: String, commentId: String) async throws {
        let postRef = postsCollection.document(postId)
        let commentRef = postRef.collection("comments").document(commentId)

        let batch = Firestore.firestore().batch()
        batch.deleteDocument(commentRef)
        batch.updateData(["commentsCount": FieldValue.increment(Int64(-1))], forDocument: postRef)
        try await batch.commit()
    }

    /// Toggles the current user's like on a single comment (or reply) —
    /// same transaction shape as toggleLike(post:), just scoped to a
    /// comment doc instead of a post doc. Requires the matching Firestore
    /// rule (see firestore.rules) that lets any signed-in user touch
    /// likes/likedBy on a comment they don't own.
    @discardableResult
    static func toggleCommentLike(postId: String, commentId: String, currentUser: User) async throws -> Bool {
        let ref = postsCollection.document(postId).collection("comments").document(commentId)

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
        return nowLiked
    }

    static func fetchComments(postId: String) async throws -> [Comment] {
        let snapshot = try await postsCollection.document(postId).collection("comments")
            .order(by: "timestamp", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Comment.self) }
    }

    // MARK: - Create (with streak update)

    @discardableResult
    static func createPost(_ post: Post, ownerUid: String) async throws -> Int {
        let postRef = postsCollection.document(post.id)
        let userRef = Firestore.firestore().collection("users").document(ownerUid)
        let currentWeekStart = DateWeek.startOfWeek(containing: post.timestamp.dateValue())
        let previousWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart

        guard let encodedPost = try? Firestore.Encoder().encode(post) else {
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Something went wrong preparing your post."])
        }

        let result: Any? = try await Firestore.firestore().runTransaction { (transaction, errorPointer) -> Any? in
            let userSnapshot: DocumentSnapshot
            do {
                userSnapshot = try transaction.getDocument(userRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            let existingStreak = userSnapshot.get("currentStreak") as? Int ?? 0
            let lastPostWeekStart = (userSnapshot.get("lastPostWeekStart") as? Timestamp)?.dateValue()

            let newStreak: Int
            if let lastPostWeekStart, lastPostWeekStart == currentWeekStart {
                newStreak = existingStreak
            } else if let lastPostWeekStart, lastPostWeekStart == previousWeekStart {
                newStreak = existingStreak + 1
            } else {
                newStreak = 1
            }

            transaction.setData(encodedPost, forDocument: postRef)
            transaction.updateData([
                "currentStreak": newStreak,
                "lastPostWeekStart": Timestamp(date: currentWeekStart)
            ], forDocument: userRef)

            return newStreak
        }

        guard let newStreak = result as? Int else {
            throw NSError(domain: "PostService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Couldn't confirm your streak update."])
        }
        return newStreak
    }

    // MARK: - Delete

    static func deletePost(_ post: Post) async throws {
        let postRef = postsCollection.document(post.id)
        let userRef = Firestore.firestore().collection("users").document(post.ownerUid)
        let postWeekStart = DateWeek.startOfWeek(containing: post.timestamp.dateValue())

        let commentsSnapshot = try await postRef.collection("comments").getDocuments()
        if !commentsSnapshot.documents.isEmpty {
            let batch = Firestore.firestore().batch()
            for doc in commentsSnapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }

        _ = try await Firestore.firestore().runTransaction { (transaction, errorPointer) -> Any? in
            let userSnapshot: DocumentSnapshot
            do {
                userSnapshot = try transaction.getDocument(userRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            transaction.deleteDocument(postRef)

            let lastPostWeekStart = (userSnapshot.get("lastPostWeekStart") as? Timestamp)?.dateValue()
            if let lastPostWeekStart, lastPostWeekStart == postWeekStart {
                let existingStreak = userSnapshot.get("currentStreak") as? Int ?? 0
                transaction.updateData([
                    "currentStreak": max(0, existingStreak - 1),
                    "lastPostWeekStart": FieldValue.delete()
                ], forDocument: userRef)
            }

            return nil
        }
    }

    // MARK: - Privacy (retroactive)

    static func updateAllPostsVisibility(ownerUid: String, isPublic: Bool) async throws {
        let snapshot = try await postsCollection
            .whereField("ownerUid", isEqualTo: ownerUid)
            .getDocuments()

        guard !snapshot.documents.isEmpty else { return }

        for chunk in snapshot.documents.chunked(into: 500) {
            let batch = Firestore.firestore().batch()
            for doc in chunk {
                batch.updateData(["isPublic": isPublic], forDocument: doc.reference)
            }
            try await batch.commit()
        }
    }
}
