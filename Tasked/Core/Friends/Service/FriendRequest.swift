//
//  FriendRequest.swift
//  Tasked
//
//  New collection backing the friends system: "friendRequests".
//  Document id is always "{fromUid}_{toUid}" so a pair can never have duplicate requests.
//

import Foundation
import Firebase

struct FriendRequest: Identifiable, Codable, Hashable {
    let id: String
    let fromUid: String
    let toUid: String
    var status: String // "pending", "accepted", "declined"
    let timestamp: Timestamp
}
