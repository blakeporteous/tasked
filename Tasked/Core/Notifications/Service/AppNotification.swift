//
//  AppNotification.swift
//  Tasked
//
//  New in this pass (Feature 4). Named AppNotification (not Notification) to avoid
//  colliding with Foundation's Notification type.
//

import Foundation
import Firebase

struct AppNotification: Identifiable, Codable, Hashable {
    let id: String
    let recipientUid: String
    let actorUid: String
    /// "friendRequestReceived", "friendRequestAccepted", "like" — kept as a plain
    /// string (not an enum) so Firestore documents never fail to decode if a new
    /// type is added server-side before the client is updated.
    let type: String
    var postId: String?
    var isRead: Bool
    let timestamp: Timestamp
}
