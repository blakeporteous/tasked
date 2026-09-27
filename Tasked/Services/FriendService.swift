//
//  FriendService.swift
//  Tasked
//
//  Backs Feature 5 (Friends model). All friend-request and friendship reads/writes
//  live here so views and view models never talk to Firestore directly for this data.
//  Updated (Live friend-requests pass): added listenToIncomingRequests(for:onChange:),
//  a real-time listener backing ActivityView. Previously ActivityViewModel did a
//  one-shot fetch on init and never refreshed itself, so a request that arrived
//  (or was accepted/declined elsewhere) after the screen was last opened just
//  didn't show up until you left and came back. fetchIncomingRequests(for:) is
//  left in place, unused for now — harmless to keep around for a future
//  one-shot use case.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

enum FriendshipStatus: Equatable {
    case isCurrentUser
    case friends
    case requestSent
    case requestReceived
    case notFriends
}

struct FriendService {

    private static let usersCollection = Firestore.firestore().collection("users")
    private static let requestsCollection = Firestore.firestore().collection("friendRequests")

    private static func requestId(from: String, to: String) -> String {
        "\(from)_\(to)"
    }

    // MARK: - Sending / cancelling requests

    static func sendFriendRequest(to toUid: String) async throws {
        guard let fromUid = Auth.auth().currentUser?.uid, fromUid != toUid else { return }

        // Blocked either direction — no new request possible until one side
        // unblocks the other.
        if AuthService.shared.currentUser?.blockedUids.contains(toUid) == true {
            throw NSError(domain: "FriendService", code: -2, userInfo: [NSLocalizedDescriptionKey: "You've blocked this user."])
        }
        if let targetUser = try? await UserService.fetchUser(withUid: toUid), targetUser.blockedUids.contains(fromUid) {
            throw NSError(domain: "FriendService", code: -2, userInfo: [NSLocalizedDescriptionKey: "You can't send a friend request to this user."])
        }

        let id = requestId(from: fromUid, to: toUid)
        let data: [String: Any] = [
            "id": id,
            "fromUid": fromUid,
            "toUid": toUid,
            "status": "pending",
            "timestamp": Timestamp()
        ]
        try await requestsCollection.document(id).setData(data)
        await NotificationService.create(recipientUid: toUid, actorUid: fromUid, type: NotificationType.friendRequestReceived)
    }

    static func cancelFriendRequest(to toUid: String) async throws {
        guard let fromUid = Auth.auth().currentUser?.uid else { return }
        try await requestsCollection.document(requestId(from: fromUid, to: toUid)).delete()
    }

    // MARK: - Responding to requests

    static func acceptFriendRequest(from fromUid: String) async throws {
        guard let toUid = Auth.auth().currentUser?.uid else { return }
        let id = requestId(from: fromUid, to: toUid)

        let batch = Firestore.firestore().batch()
        batch.updateData(["status": "accepted"], forDocument: requestsCollection.document(id))
        batch.updateData(["friendUids": FieldValue.arrayUnion([toUid])], forDocument: usersCollection.document(fromUid))
        batch.updateData(["friendUids": FieldValue.arrayUnion([fromUid])], forDocument: usersCollection.document(toUid))
        try await batch.commit()

        await NotificationService.create(recipientUid: fromUid, actorUid: toUid, type: NotificationType.friendRequestAccepted)
    }

    static func declineFriendRequest(from fromUid: String) async throws {
        guard let toUid = Auth.auth().currentUser?.uid else { return }
        try await requestsCollection.document(requestId(from: fromUid, to: toUid)).delete()
    }

    // MARK: - Removing a friend

    static func removeFriend(_ otherUid: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let batch = Firestore.firestore().batch()
        batch.updateData(["friendUids": FieldValue.arrayRemove([otherUid])], forDocument: usersCollection.document(currentUid))
        batch.updateData(["friendUids": FieldValue.arrayRemove([currentUid])], forDocument: usersCollection.document(otherUid))
        try await batch.commit()

        // Clean up any leftover request docs in either direction so a fresh request can be sent later.
        try? await requestsCollection.document(requestId(from: currentUid, to: otherUid)).delete()
        try? await requestsCollection.document(requestId(from: otherUid, to: currentUid)).delete()
    }

    // MARK: - Status lookups

    /// Determines the relationship between the signed-in user and `otherUid`.
    static func fetchStatus(with otherUid: String, currentUser: User) async throws -> FriendshipStatus {
        if otherUid == currentUser.id { return .isCurrentUser }
        if currentUser.friendUids.contains(otherUid) { return .friends }

        let outgoing = try await requestsCollection.document(requestId(from: currentUser.id, to: otherUid)).getDocument()
        if outgoing.exists, let status = outgoing.get("status") as? String, status == "pending" {
            return .requestSent
        }

        let incoming = try await requestsCollection.document(requestId(from: otherUid, to: currentUser.id)).getDocument()
        if incoming.exists, let status = incoming.get("status") as? String, status == "pending" {
            return .requestReceived
        }

        return .notFriends
    }

    /// Live status for one specific incoming request (`fromUid` -> the
    /// signed-in user). Used by NotificationsView so an accept/decline/cancel
    /// made anywhere else in the app (ActivityView, a profile, etc.) is
    /// reflected immediately here too, instead of only on next load.
    @discardableResult
    static func listenToRequestStatus(
        fromUid: String,
        onChange: @escaping (FriendshipStatus) -> Void
    ) -> ListenerRegistration? {
        guard let toUid = Auth.auth().currentUser?.uid else { return nil }
        let id = requestId(from: fromUid, to: toUid)

        return requestsCollection.document(id).addSnapshotListener { snapshot, _ in
            guard let snapshot, snapshot.exists else {
                // Doc is gone — declined, cancelled, or unfriended elsewhere.
                onChange(.notFriends)
                return
            }
            let status = snapshot.get("status") as? String
            onChange(status == "accepted" ? .friends : .requestReceived)
        }
    }

    /// Live-updating list of pending incoming requests for `uid` — backs
    /// ActivityView. A request appearing, being accepted/declined here, or
    /// being responded to from elsewhere (e.g. NotificationsView's inline
    /// Accept/Decline) is all reflected instantly, with no manual refresh.
    @discardableResult
    static func listenToIncomingRequests(
        for uid: String,
        onChange: @escaping (Result<[FriendRequest], Error>) -> Void
    ) -> ListenerRegistration {
        requestsCollection
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let requests = snapshot?.documents.compactMap { try? $0.data(as: FriendRequest.self) } ?? []
                onChange(.success(requests))
            }
    }

    static func fetchIncomingRequests(for uid: String) async throws -> [FriendRequest] {
        let snapshot = try await requestsCollection
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: FriendRequest.self) }
    }

    static func fetchOutgoingRequests(for uid: String) async throws -> [FriendRequest] {
        let snapshot = try await requestsCollection
            .whereField("fromUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: FriendRequest.self) }
    }

    static func fetchFriends(for user: User) async throws -> [User] {
        guard !user.friendUids.isEmpty else { return [] }

        var result: [User] = []
        for chunk in user.friendUids.chunked(into: 30) {
            let snapshot = try await usersCollection
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            result += try snapshot.documents.compactMap { try $0.data(as: User.self) }
        }
        return result
    }
}
