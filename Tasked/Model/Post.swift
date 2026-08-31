//
//  Post.swift
//  Tasked
//
//  Created by Blake Porteous on 24/03/2025.
//  Updated (Feed engagement pass): added `likedBy` (uids of everyone who's liked
//  the post) so likes can be toggled and "did I like this" checked client-side,
//  and `commentsCount` so FeedCell can show a comment count without loading the
//  whole comments subcollection.
//  Fixed: Swift's synthesized Decodable does NOT fall back to a property's
//  default value when its key is missing from the document — it still throws
//  keyNotFound (surfaced to users as "the data couldn't be read because it is
//  missing"). Every post written before this update has no `likedBy`/
//  `commentsCount` field, so the whole feed failed to decode. Added a custom
//  init(from:) that uses decodeIfPresent with explicit fallbacks for those two
//  fields — encode(to:) is still synthesized automatically since only
//  Decodable's initializer is overridden here (same pattern as User.swift).
//

import Foundation
import Firebase

struct Post: Identifiable, Hashable, Codable {
    let id: String
    let ownerUid: String
    var taskId: String?
    let caption: String
    var likes: Int
    var likedBy: [String] = []
    var commentsCount: Int = 0
    let imageUrl: String
    let timestamp: Timestamp
    var user: User?

    func isLiked(by uid: String?) -> Bool {
        guard let uid else { return false }
        return likedBy.contains(uid)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUid
        case taskId
        case caption
        case likes
        case likedBy
        case commentsCount
        case imageUrl
        case timestamp
        case user
    }

    // Writing a custom init(from:) below disables Swift's free memberwise
    // initializer, so this restores it explicitly — matches the parameter
    // order every existing call site (UploadPostViewModel, MOCK_POSTS) uses.
    init(
        id: String,
        ownerUid: String,
        taskId: String? = nil,
        caption: String,
        likes: Int,
        likedBy: [String] = [],
        commentsCount: Int = 0,
        imageUrl: String,
        timestamp: Timestamp,
        user: User? = nil
    ) {
        self.id = id
        self.ownerUid = ownerUid
        self.taskId = taskId
        self.caption = caption
        self.likes = likes
        self.likedBy = likedBy
        self.commentsCount = commentsCount
        self.imageUrl = imageUrl
        self.timestamp = timestamp
        self.user = user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        ownerUid = try container.decode(String.self, forKey: .ownerUid)
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
        caption = try container.decode(String.self, forKey: .caption)
        likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0

        // These two fields postdate a lot of existing posts — default instead
        // of failing the whole decode when they're missing.
        likedBy = try container.decodeIfPresent([String].self, forKey: .likedBy) ?? []
        commentsCount = try container.decodeIfPresent(Int.self, forKey: .commentsCount) ?? 0

        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        timestamp = try container.decode(Timestamp.self, forKey: .timestamp)
        user = try container.decodeIfPresent(User.self, forKey: .user)
    }
}

extension Post {
    static var MOCK_POSTS: [Post] = [
        .init(
            id: NSUUID().uuidString,
            ownerUid: NSUUID().uuidString,
            taskId: nil,
            caption: "This is a test caption",
            likes: 234,
            likedBy: [],
            commentsCount: 3,
            imageUrl: "Mandalorian",
            timestamp: Timestamp(),
            user: User.MOCK_USERS[0]
        ),
        .init(
            id: NSUUID().uuidString,
            ownerUid: NSUUID().uuidString,
            taskId: nil,
            caption: "Another amazing caption",
            likes: 421,
            likedBy: [],
            commentsCount: 12,
            imageUrl: "Ahsoka",
            timestamp: Timestamp(),
            user: User.MOCK_USERS[1]
        ),
        .init(
            id: NSUUID().uuidString,
            ownerUid: NSUUID().uuidString,
            taskId: nil,
            caption: "I don't know how to caption this",
            likes: 12,
            likedBy: [],
            commentsCount: 0,
            imageUrl: "Anakin",
            timestamp: Timestamp(),
            user: User.MOCK_USERS[2]
        ),
        .init(
            id: NSUUID().uuidString,
            ownerUid: NSUUID().uuidString,
            taskId: nil,
            caption: "We really got this before GTA6",
            likes: 81,
            likedBy: [],
            commentsCount: 1,
            imageUrl: "Yoda",
            timestamp: Timestamp(),
            user: User.MOCK_USERS[3]
        ),
    ]
}
