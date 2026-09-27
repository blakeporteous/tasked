//
//  AppNotification.swift
//  Tasked
//
//  New in this pass (Feature 4). Named AppNotification (not Notification) to avoid
//  colliding with Foundation's Notification type.
//  Updated (Notifications-Accept pass): added timeAgo, a short, ROUNDED
//  relative-time string shown on each row in NotificationsView.
//  Updated (Comment likes + replies pass): timeAgo's bucket/rounding logic
//  moved into the shared RelativeTime helper (Comment.timeAgo uses it too)
//  — behavior is unchanged, just de-duplicated.
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

extension AppNotification {
    /// Short, ROUNDED "time ago" string — "5h", "1d", "2w".
    var timeAgo: String {
        RelativeTime.string(since: timestamp)
    }
}
