//
//  Comment.swift
//  Tasked
//
//  New (Feed engagement pass): backs post comments. Lives in the
//  "posts/{postId}/comments" subcollection so comments are naturally scoped per
//  post and can be paged/queried without touching the post document itself.
//  Updated (Edit comment pass): text is now mutable so a comment can be
//  edited after posting, and isEdited flags that it's been changed so
//  CommentsView can show a small "(edited)" marker. Custom init(from:) uses
//  decodeIfPresent for isEdited with a false fallback — same pattern as
//  Post.swift — since every comment written before this update has no
//  isEdited field at all.
//  Updated (Comment likes + replies pass): added likes/likedBy, mirroring
//  Post's own like pattern (see PostService.toggleCommentLike) — a
//  denormalized count plus the raw uid list so "did I like this" can be
//  checked client-side. Added parentCommentId: a REPLY is just another
//  comment document in the same subcollection, with this set to the
//  TOP-LEVEL comment it belongs to (nil for a top-level comment) —
//  CommentsViewModel groups replies under their parent client-side rather
//  than needing a separate nested subcollection. All three fields postdate
//  a lot of existing comments, so init(from:) decodes them with fallbacks
//  the same way isEdited already is — nothing needs to be migrated. Added
//  `timeAgo`, matching AppNotification's short/rounded style via the shared
//  RelativeTime helper.
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
    var text: String
    var isEdited: Bool = false
    let timestamp: Timestamp

    /// Uids of everyone who's liked this comment, plus a denormalized count
    /// — same pattern as Post.likes/likedBy, kept in sync via
    /// PostService.toggleCommentLike's transaction.
    var likes: Int = 0
    var likedBy: [String] = []

    /// Set only on a REPLY — the id of the TOP-LEVEL comment it belongs to.
    /// nil for a top-level comment. Replies live in this same subcollection
    /// (not a separate nested one) so fetchComments(postId:) can fetch a
    /// post's whole comment thread in one query.
    var parentCommentId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case ownerUid
        case username
        case profileImageUrl
        case text
        case isEdited
        case timestamp
        case likes
        case likedBy
        case parentCommentId
    }

    // Writing a custom init(from:) below disables Swift's free memberwise
    // initializer, so this restores it explicitly.
    init(
        id: String,
        postId: String,
        ownerUid: String,
        username: String,
        profileImageUrl: String? = nil,
        text: String,
        isEdited: Bool = false,
        timestamp: Timestamp,
        likes: Int = 0,
        likedBy: [String] = [],
        parentCommentId: String? = nil
    ) {
        self.id = id
        self.postId = postId
        self.ownerUid = ownerUid
        self.username = username
        self.profileImageUrl = profileImageUrl
        self.text = text
        self.isEdited = isEdited
        self.timestamp = timestamp
        self.likes = likes
        self.likedBy = likedBy
        self.parentCommentId = parentCommentId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        ownerUid = try container.decode(String.self, forKey: .ownerUid)
        username = try container.decode(String.self, forKey: .username)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        text = try container.decode(String.self, forKey: .text)
        isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        timestamp = try container.decode(Timestamp.self, forKey: .timestamp)

        // Postdate a lot of existing comments — default instead of failing
        // the whole decode when they're missing.
        likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
        likedBy = try container.decodeIfPresent([String].self, forKey: .likedBy) ?? []
        parentCommentId = try container.decodeIfPresent(String.self, forKey: .parentCommentId)
    }

    func isLiked(by uid: String?) -> Bool {
        guard let uid else { return false }
        return likedBy.contains(uid)
    }
}

extension Comment {
    /// Short, ROUNDED "time ago" string — "5h", "1d", "2w".
    var timeAgo: String {
        RelativeTime.string(since: timestamp)
    }
}

extension Comment {
    static var MOCK_COMMENTS: [Comment] = [
        .init(id: NSUUID().uuidString, postId: "post1", ownerUid: NSUUID().uuidString, username: "Ahsoka", profileImageUrl: nil, text: "Love this!", timestamp: Timestamp()),
        .init(id: NSUUID().uuidString, postId: "post1", ownerUid: NSUUID().uuidString, username: "Yoda", profileImageUrl: nil, text: "Do or do not, there is no like button try", timestamp: Timestamp())
    ]
}
