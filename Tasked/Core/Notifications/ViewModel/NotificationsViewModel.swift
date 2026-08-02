//
//  NotificationsViewModel.swift
//  Tasked
//
//  New in this pass (Feature 4). Owned once, near the top of the view hierarchy
//  (MainTabView), and shared via @EnvironmentObject so the unread badge on the
//  Feed bell and the notifications list itself always agree.
//

import Foundation
import FirebaseFirestore

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
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

    deinit {
        listener?.remove()
    }
}
