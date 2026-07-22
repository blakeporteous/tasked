//
//  User.swift
//  Tasked
//
//  Created by Blake Porteous on 18/03/2025.
//

import Foundation
import FirebaseAuth

struct User: Identifiable, Hashable, Codable {
    let id: String
    var username: String
    var profileImageUrl: String?
    var fullname: String?
    var bio: String?
    var followersCount: Int = 0
    var followingCount: Int = 0
    let email: String
    
    var isCurrentUser: Bool {
        guard let currentUid = Auth.auth().currentUser?.uid else { return false }
        return currentUid == id
    }
    
    enum CodingKeys: String, CodingKey {
        case id, username, profileImageUrl, fullname, bio, followersCount, followingCount, email
    }
    
    init(id: String, username: String, profileImageUrl: String? = nil, fullname: String? = nil, bio: String? = nil, followersCount: Int = 0, followingCount: Int = 0, email: String) {
        self.id = id
        self.username = username
        self.profileImageUrl = profileImageUrl
        self.fullname = fullname
        self.bio = bio
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.email = email
    }
    
    // Custom decoding: old documents written before followersCount/followingCount
    // existed shouldn't fail to decode just because those keys are missing.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        fullname = try container.decodeIfPresent(String.self, forKey: .fullname)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
        followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        email = try container.decode(String.self, forKey: .email)
    }
}

extension User {
    static var MOCK_USERS: [User] = [
        .init(id: NSUUID().uuidString, username: "Mandolorian", profileImageUrl: nil, fullname: "Din Djarin", bio: "This is the way", followersCount: 12, followingCount: 8, email: "mando@gmail.com"),
        .init(id: NSUUID().uuidString, username: "Ahsoka", profileImageUrl: nil, fullname: "Ahsoka Tano", bio: "Snips", followersCount: 20, followingCount: 5, email: "ashoka@gmail.com"),
        .init(id: NSUUID().uuidString, username: "Anakin", profileImageUrl: nil, fullname: "Anakin Skywalker", bio: "Skyguy", followersCount: 30, followingCount: 15, email: "anakin@gmail.com"),
        .init(id: NSUUID().uuidString, username: "Yoda", profileImageUrl: nil, fullname: "Yoda", bio: "Do or do not there is no try", followersCount: 900, followingCount: 2, email: "yoda@gmail.com"),
    ]
}
