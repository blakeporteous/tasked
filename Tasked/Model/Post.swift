//
//  Post.swift
//  Tasked
//
//  Created by Blake Porteous on 24/03/2025.
//

import Foundation
import Firebase

struct Post: Identifiable, Hashable, Codable {
    let id: String
    let ownerUid: String
    var taskId: String?
    let caption: String
    var likes: Int
    let imageUrl: String
    let timestamp: Timestamp
    var user: User?
}

extension Post {
    static var MOCK_POSTS: [Post] = [
        .init(
            id: NSUUID().uuidString,
            ownerUid: NSUUID().uuidString,
            taskId: nil,
            caption: "This is a test caption",
            likes: 234,
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
            imageUrl: "Yoda",
            timestamp: Timestamp(),
            user: User.MOCK_USERS[3]
        ),
    ]
}
