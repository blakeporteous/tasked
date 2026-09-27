//
//  NotificationPreferences.swift
//  Tasked
//
//  New: backs the "Notification Settings" screen. Stored as a nested map on
//  the user's own document (field: notificationPreferences), so it's read
//  right off AuthService.currentUser like everything else and needs no
//  separate collection or fetch.
//
//  This single set of toggles gates BOTH the in-app bell/badge and push:
//  NotificationService.create checks isEnabled(for:) before writing anything
//  to the "notifications" collection, and the Cloud Function that sends the
//  actual push (functions/index.js) only ever fires off documents that made
//  it past that check. Disable "Likes" here and a like neither shows up in
//  the bell nor triggers a push — there's only one gate to reason about.
//

import Foundation

struct NotificationPreferences: Codable, Hashable {
    var likesEnabled: Bool = true
    var commentsEnabled: Bool = true
    var friendRequestsEnabled: Bool = true

    /// Whether a notification of `type` (one of the NotificationType.* raw
    /// strings) should be created at all. Unrecognized types default to
    /// enabled, matching NotificationsView's own "did something" fallback —
    /// a future notification type should be visible until someone adds a
    /// dedicated toggle for it, not silently swallowed.
    func isEnabled(for type: String) -> Bool {
        switch type {
        case NotificationType.like:
            return likesEnabled
        case NotificationType.comment:
            return commentsEnabled
        case NotificationType.friendRequestReceived, NotificationType.friendRequestAccepted:
            return friendRequestsEnabled
        default:
            return true
        }
    }
}
