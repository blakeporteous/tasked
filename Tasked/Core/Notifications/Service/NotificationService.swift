//
//  NotificationService.swift
//  Tasked
//
//  New in this pass (Feature 4). Backs the notifications feed. Writes are fire-and-forget
//  from the caller's point of view (a failed notification write should never block the
//  action that triggered it, e.g. accepting a friend request).
//  Updated (Feed engagement pass): added the "comment" notification type, fired
//  from PostService.addComment alongside the existing "like" type fired from
//  PostService.toggleLike.
//  Updated (Notification settings + push): create(_:) now checks the
//  recipient's NotificationPreferences before writing. If disabled, nothing
//  is written — which means it never shows up in their bell/badge, and the
//  sendPushNotification Cloud Function (which only fires off documents
//  created here) never runs for it either. One gate, both effects.
//

import Foundation
import Firebase
import FirebaseFirestore

enum NotificationType {
    static let friendRequestReceived = "friendRequestReceived"
    static let friendRequestAccepted = "friendRequestAccepted"
    static let like = "like"
    static let comment = "comment"
}

struct NotificationService {

    private static let collection = Firestore.firestore().collection("notifications")

    static func create(recipientUid: String, actorUid: String, type: String, postId: String? = nil) async {
        guard recipientUid != actorUid else { return } // don't notify yourself

        // Respect the recipient's notification preferences before writing
        // anything. Fails open (still creates the notification) if the
        // recipient's doc can't be fetched, since that's a much less bad
        // outcome than silently dropping a real notification.
        if let recipient = try? await UserService.fetchUser(withUid: recipientUid),
           !recipient.notificationPreferences.isEnabled(for: type) {
            return
        }

        let ref = collection.document()
        var data: [String: Any] = [
            "id": ref.documentID,
            "recipientUid": recipientUid,
            "actorUid": actorUid,
            "type": type,
            "isRead": false,
            "timestamp": Timestamp()
        ]
        if let postId { data["postId"] = postId }
        try? await ref.setData(data)
    }

    /// Live-updating feed for the signed-in user, newest first.
    /// Requires a composite index on (recipientUid ==, timestamp desc).
    static func listen(for uid: String, onChange: @escaping (Result<[AppNotification], Error>) -> Void) -> ListenerRegistration {
        collection
            .whereField("recipientUid", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let notifications = snapshot?.documents.compactMap { try? $0.data(as: AppNotification.self) } ?? []
                onChange(.success(notifications))
            }
    }

    static func markAsRead(_ ids: [String]) async {
        guard !ids.isEmpty else { return }
        let batch = Firestore.firestore().batch()
        for id in ids {
            batch.updateData(["isRead": true], forDocument: collection.document(id))
        }
        try? await batch.commit()
    }

    /// Deletes a single notification (used by the swipe-to-delete action on
    /// NotificationsView). Returns whether it actually succeeded so the
    /// caller can undo an optimistic local removal if the write fails.
    @discardableResult
    static func delete(_ id: String) async -> Bool {
        do {
            try await collection.document(id).delete()
            return true
        } catch {
            return false
        }
    }
}
