//
//  BlockService.swift
//  Tasked
//
//  New (Block user pass): mirrors FriendService's shape. Blocking adds the
//  target to the signed-in user's own blockedUids (self-owned field, no
//  rules change needed — same rule that already lets you update any other
//  field on your own user doc), unfriends in both directions (same
//  friendUids-symmetric rule FriendService.removeFriend already uses), and
//  clears any pending friendRequests doc between the two (existing delete
//  rule already allows either party to delete a request they're part of).
//  Updated (Blocked-list pass): added fetchBlockedUsers(for:), the batched
//  lookup backing BlockedUsersView — same "hydrate a uid array into full
//  Users" pattern FriendService.fetchFriends(for:) already uses. Renamed
//  unblock(_:) to unblockUser(_:) to match BlockedUsersViewModel's call site.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct BlockService {

    private static let usersCollection = Firestore.firestore().collection("users")
    private static let requestsCollection = Firestore.firestore().collection("friendRequests")

    private static func requestId(from: String, to: String) -> String {
        "\(from)_\(to)"
    }

    /// Blocks `blockedUid`. One batch write covers both docs (both changes
    /// are field-level updates the existing rules already permit), then the
    /// two possible pending friend-request docs are cleaned up.
    static func block(_ blockedUid: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid, currentUid != blockedUid else { return }

        let batch = Firestore.firestore().batch()
        batch.updateData([
            "blockedUids": FieldValue.arrayUnion([blockedUid]),
            "friendUids": FieldValue.arrayRemove([blockedUid])
        ], forDocument: usersCollection.document(currentUid))
        batch.updateData(["friendUids": FieldValue.arrayRemove([currentUid])], forDocument: usersCollection.document(blockedUid))
        try await batch.commit()

        try? await requestsCollection.document(requestId(from: currentUid, to: blockedUid)).delete()
        try? await requestsCollection.document(requestId(from: blockedUid, to: currentUid)).delete()
    }

    /// Reverses a block. Doesn't restore the friendship or re-create any
    /// deleted friend request — that's a fresh "Add Friend" from either
    /// side afterward, same as any other unfriend.
    static func unblockUser(_ blockedUid: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        try await usersCollection.document(currentUid).updateData(["blockedUids": FieldValue.arrayRemove([blockedUid])])
    }

    /// Batched lookup of full User profiles for everyone `currentUser` has
    /// blocked — backs BlockedUsersView. Mirrors
    /// FriendService.fetchFriends(for:)'s shape exactly (chunk into 30s,
    /// since that's Firestore's `in`-query cap).
    static func fetchBlockedUsers(for currentUser: User) async throws -> [User] {
        guard !currentUser.blockedUids.isEmpty else { return [] }

        var result: [User] = []
        for chunk in currentUser.blockedUids.chunked(into: 30) {
            let snapshot = try await usersCollection
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            result += try snapshot.documents.compactMap { try $0.data(as: User.self) }
        }
        return result
    }
}
