//
//  PostService.swift
//  Tasked
//
//  Created by Blake Porteous on 13/08/2025.
//  Updated: fetchFeedPosts is now scoped to the signed-in user's friends (Feature 5),
//  since posts should follow the same privacy rules as profiles.
//

import Foundation
import Firebase

struct PostService {

    private static let postsCollection = Firestore.firestore().collection("posts")

    /// Feed = the signed-in user's own posts + their friends' posts, newest first.
    static func fetchFeedPosts(for currentUser: User) async throws -> [Post] {
        var ownerUids = currentUser.friendUids
        ownerUids.append(currentUser.id)
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
}
