//
//  User.swift
//  Tasked
//

import Foundation
import FirebaseAuth

struct User: Identifiable, Hashable, Codable {
    let id: String
    
    var username: String
    var usernameLower: String
    
    var profileImageUrl: String?
    var fullname: String?
    var bio: String?
    
    var friendUids: [String] = []
    
    let email: String
    
    var friendsCount: Int { friendUids.count }
    
    var isCurrentUser: Bool {
        guard let currentUid = Auth.auth().currentUser?.uid else { return false }
        return currentUid == id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case usernameLower
        case profileImageUrl
        case fullname
        case bio
        case friendUids
        case email
    }

    init(
        id: String,
        username: String,
        usernameLower: String? = nil,
        profileImageUrl: String? = nil,
        fullname: String? = nil,
        bio: String? = nil,
        friendUids: [String] = [],
        email: String
    ) {
        self.id = id
        self.username = username
        self.usernameLower = usernameLower ?? username.lowercased()
        self.profileImageUrl = profileImageUrl
        self.fullname = fullname
        self.bio = bio
        self.friendUids = friendUids
        self.email = email
    }


    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)

        username = try container.decode(String.self, forKey: .username)

        // Supports old accounts that don't have usernameLower yet
        usernameLower = try container.decodeIfPresent(
            String.self,
            forKey: .usernameLower
        ) ?? username.lowercased()

        profileImageUrl = try container.decodeIfPresent(
            String.self,
            forKey: .profileImageUrl
        )

        fullname = try container.decodeIfPresent(
            String.self,
            forKey: .fullname
        )

        bio = try container.decodeIfPresent(
            String.self,
            forKey: .bio
        )

        friendUids = try container.decodeIfPresent(
            [String].self,
            forKey: .friendUids
        ) ?? []

        email = try container.decode(
            String.self,
            forKey: .email
        )
    }
}

extension User {
    static var MOCK_USERS: [User] = [
        .init(id: NSUUID().uuidString, username: "Mandolorian", profileImageUrl: nil, fullname: "Din Djarin", bio: "This is the way", friendUids: [], email: "mando@gmail.com"),
        .init(id: NSUUID().uuidString, username: "Ahsoka", profileImageUrl: nil, fullname: "Ahsoka Tano", bio: "Snips", friendUids: [], email: "ashoka@gmail.com"),
        .init(id: NSUUID().uuidString, username: "Anakin", profileImageUrl: nil, fullname: "Anakin Skywalker", bio: "Skyguy", friendUids: [], email: "anakin@gmail.com"),
        .init(id: NSUUID().uuidString, username: "Yoda", profileImageUrl: nil, fullname: "Yoda", bio: "Do or do not there is no try", friendUids: [], email: "yoda@gmail.com"),
    ]
}
