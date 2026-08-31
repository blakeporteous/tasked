//
//  Comment.swift
//  Tasked
//
//  New (Feed engagement pass): backs post comments. Lives in the
//  "posts/{postId}/comments" subcollection so comments are naturally scoped per
//  post and can be paged/queried without touching the post document itself.
//

import Foundation
import Firebase

struct Comment: Identifiable, Codable, Hashable {
    let id: String
    let postId: String
    let ownerUid: String
    // Denormalized so CommentsView can render a row without a per-comment user fetch.
    var username: String
    var profileImageUrl: String?
    let text: String
    let timestamp: Timestamp
}

extension Comment {
    static var MOCK_COMMENTS: [Comment] = [
        .init(id: NSUUID().uuidString, postId: "post1", ownerUid: NSUUID().uuidString, username: "Ahsoka", profileImageUrl: nil, text: "Love this!", timestamp: Timestamp()),
        .init(id: NSUUID().uuidString, postId: "post1", ownerUid: NSUUID().uuidString, username: "Yoda", profileImageUrl: nil, text: "Do or do not, there is no like button try", timestamp: Timestamp())
    ]
}
