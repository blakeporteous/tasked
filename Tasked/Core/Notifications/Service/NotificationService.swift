//
//  NotificationService.swift
//  Tasked
//
//  New in this pass (Feature 4). Backs the notifications feed. Writes are fire-and-forget
//  from the caller's point of view (a failed notification write should never block the
//  action that triggered it, e.g. accepting a friend request).
//

import Foundation
import Firebase
import FirebaseFirestore

enum NotificationType {
    static let friendRequestReceived = "friendRequestReceived"
    static let friendRequestAccepted = "friendRequestAccepted"
    static let like = "like"
}

struct NotificationService {

    private static let collection = Firestore.firestore().collection("notifications")

    static func create(recipientUid: String, actorUid: String, type: String, postId: String? = nil) async {
        guard recipientUid != actorUid else { return } // don't notify yourself
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
}
