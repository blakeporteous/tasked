//
//  NotificationsViewModel.swift
//  Tasked
//
//  New in this pass (Feature 4). Owned once, near the top of the view hierarchy
//  (MainTabView), and shared via @EnvironmentObject so the unread badge on the
//  Feed bell and the notifications list itself always agree.
//  Updated (Grouped notifications pass): added NotificationSection and
//  groupedNotifications, which buckets `notifications` (already newest-first
//  from the Firestore listener) into "Last 24 Hours" / "Last 2 Days" /
//  "This Week" / "This Month" / "Older" based on elapsed time since each
//  notification's timestamp — mirrors the same rounded, elapsed-time
//  thinking RelativeTime.swift already uses for the per-row "5h"/"1d"
//  labels, just bucketed instead of formatted. Order within each bucket is
//  preserved from the source array.
//

import Foundation
import FirebaseFirestore

/// One time-bucketed section of the notifications list — "Last 24 Hours",
/// "This Week", etc. — with the notifications that fall into it, still in
/// their original (newest-first) order.
struct NotificationSection: Identifiable {
    let title: String
    let notifications: [AppNotification]
    var id: String { title }
}

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    /// Bucket boundaries, in days-elapsed-since-posted. A notification lands
    /// in the first bucket whose upper bound it's still under.
    private static let bucketOrder: [(title: String, maxDays: Double)] = [
        ("Last 24 Hours", 1),
        ("Last 2 Days", 3),
        ("This Week", 7),
        ("This Month", 30),
        ("Older", .infinity)
    ]

    /// `notifications` grouped into time buckets for display. Empty buckets
    /// are simply omitted rather than shown with no rows.
    var groupedNotifications: [NotificationSection] {
        let now = Date()
        var buckets: [String: [AppNotification]] = [:]

        for notification in notifications {
            let daysAgo = now.timeIntervalSince(notification.timestamp.dateValue()) / 86_400
            let title = Self.bucketOrder.first { daysAgo < $0.maxDays }?.title ?? "Older"
            buckets[title, default: []].append(notification)
        }

        return Self.bucketOrder.compactMap { bucket in
            guard let items = buckets[bucket.title], !items.isEmpty else { return nil }
            return NotificationSection(title: bucket.title, notifications: items)
        }
    }

    func startListening(uid: String) {
        listener?.remove()
        listener = NotificationService.listen(for: uid) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let notifications):
                self.notifications = notifications
            case .failure(let error):
                self.errorMessage = "Couldn't load notifications: \(error.localizedDescription)"
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        notifications = []
    }

    func markAllRead() async {
        let unreadIds = notifications.filter { !$0.isRead }.map(\.id)
        await NotificationService.markAsRead(unreadIds)
    }

    /// Removes a notification immediately in the UI (so a swipe-to-delete
    /// feels instant) and reverts it if the Firestore delete actually fails.
    /// Doesn't touch `errorMessage` on failure — that property blanks the
    /// whole list in NotificationsView, which would be a much worse outcome
    /// for a single failed swipe than just having the row reappear.
    func delete(_ notification: AppNotification) async {
        let previous = notifications
        notifications.removeAll { $0.id == notification.id }

        let success = await NotificationService.delete(notification.id)
        if !success {
            notifications = previous
        }
    }

    deinit {
        listener?.remove()
    }
}
