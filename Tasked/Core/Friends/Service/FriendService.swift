//
//  FriendService.swift
//  Tasked
//
//  Backs Feature 5 (Friends model). All friend-request and friendship reads/writes
//  live here so views and view models never talk to Firestore directly for this data.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

enum FriendshipStatus {
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
