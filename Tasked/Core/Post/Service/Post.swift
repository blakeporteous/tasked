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
//  Updated (Public/private pass): added `isPublic`, stamped onto every post at
//  upload time from the owner's account-level isPublicAccount setting (see
//  User.swift, PublicPrivateView, UploadPostViewModel). Defaults to true for
//  posts written before this field existed — matches the Firestore rules'
//  `resource.data.get('isPublic', true)` fallback, so an old post's read
//  access doesn't change just because it predates this field.
//  Updated (Location pass): added `location` (a display string like "Auckland,
//  New Zealand") plus `locationLatitude`/`locationLongitude`, set either from
//  the photo's own embedded GPS metadata or a manual pick in
//  LocationPickerView (see UploadPostViewModel). All three postdate every
//  existing post, so they decode with nil fallbacks like taskId already does.
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
    /// Whether this post is visible to anyone signed in (true) or only to
    /// the owner's friends (false) — see canReadPost() in the Firestore
    /// rules. Set once at upload time from the owner's account-level privacy
    /// setting; changing that setting later doesn't retroactively touch
    /// posts already uploaded.
    var isPublic: Bool = true
    /// Display name for where this was posted — e.g. "Auckland, New
    /// Zealand". Either pulled automatically from the photo's own GPS EXIF
    /// data, or picked manually via LocationPickerView. nil if neither
    /// happened (no GPS data and the person skipped picking one).
    var location: String?
    var locationLatitude: Double?
    var locationLongitude: Double?
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
        case isPublic
        case location
        case locationLatitude
        case locationLongitude
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
        isPublic: Bool = true,
        location: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
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
        self.isPublic = isPublic
        self.location = location
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
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

        // These fields postdate a lot of existing posts — default instead of
        // failing the whole decode when they're missing.
        likedBy = try container.decodeIfPresent([String].self, forKey: .likedBy) ?? []
        commentsCount = try container.decodeIfPresent(Int.self, forKey: .commentsCount) ?? 0
        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true

        location = try container.decodeIfPresent(String.self, forKey: .location)
        locationLatitude = try container.decodeIfPresent(Double.self, forKey: .locationLatitude)
        locationLongitude = try container.decodeIfPresent(Double.self, forKey: .locationLongitude)

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
            location: "Auckland, New Zealand",
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
