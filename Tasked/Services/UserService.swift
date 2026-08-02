//
//  UserService.swift
//  Tasked
//
//  Created by Blake Porteous on 18/07/2025.
//  Updated: added fetchUsers(withUids:) for batched lookups (used by the friend
//  requests screen instead of one read per request).
//

import Foundation
import Firebase

struct UserService {

    static func fetchUser(withUid uid: String) async throws -> User {
        let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
        return try snapshot.data(as: User.self)
    }

    /// Batched lookup for multiple uids at once. Firestore's `in` query caps at
    /// 30 values, so this chunks automatically for larger lists.
    static func fetchUsers(withUids uids: [String]) async throws -> [User] {
        guard !uids.isEmpty else { return [] }

        var result: [User] = []
        for chunk in uids.chunked(into: 30) {
            let snapshot = try await Firestore.firestore().collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            result += snapshot.documents.compactMap { try? $0.data(as: User.self) }
        }
        return result
    }

    static func fetchAllUsers() async throws -> [User] {
        let snapshot = try await Firestore.firestore().collection("users").getDocuments()
        return snapshot.documents.compactMap({ try? $0.data(as: User.self) })
    }

    /// Prefix search on username, case-insensitive.
    ///
    /// Requires every user document to also store a lowercased `usernameLower` field
    /// (written by AuthService at sign-up and on profile edits) since Firestore range
    /// queries are case-sensitive and can only operate on a field stored that way.
    static func searchUsers(matching query: String) async throws -> [User] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        let end = trimmed + "\u{f8ff}"

        let snapshot = try await Firestore.firestore()
            .collection("users")
            .order(by: "usernameLower")
            .start(at: [trimmed])
            .end(at: [end])
            .limit(to: 25)
            .getDocuments()

        print("SEARCH QUERY:", trimmed)
        print("FOUND DOCUMENTS:", snapshot.documents.count)

        for document in snapshot.documents {
            print(document.data())
        }

        return snapshot.documents.compactMap {
            try? $0.data(as: User.self)
        }
    }
}
