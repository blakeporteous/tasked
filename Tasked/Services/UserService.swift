//
//  UserService.swift
//  Tasked
//
//  (header comments unchanged from before — trimmed here for brevity)
//  Updated (Block user pass): searchUsers now filters out anyone the
//  signed-in user has blocked AND anyone who has blocked the signed-in
//  user — both directions, since we already have each candidate's full
//  User (including their blockedUids) from the query results, no extra
//  reads needed.
//

import Foundation
import Firebase
import FirebaseAuth

struct UserService {

    static func fetchUser(withUid uid: String) async throws -> User {
        let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
        return try snapshot.data(as: User.self)
    }

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

    static func searchUsers(matching query: String) async throws -> [User] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        let end = trimmed + "\u{f8ff}"

        let snapshot = try await Firestore.firestore()
            .collection("users")
            .order(by: "username")
            .start(at: [trimmed])
            .end(at: [end])
            .limit(to: 25)
            .getDocuments()

        let currentUid = Auth.auth().currentUser?.uid
        let myBlockedUids = Set(AuthService.shared.currentUser?.blockedUids ?? [])

        return snapshot.documents.compactMap {
            try? $0.data(as: User.self)
        }.filter { user in
            user.id != currentUid
            && !myBlockedUids.contains(user.id)
            && !user.blockedUids.contains(currentUid ?? "")
        }
    }

    static func isUsernameTaken(_ username: String) async throws -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return false }

        let snapshot = try await Firestore.firestore()
            .collection("users")
            .whereField("username", isEqualTo: trimmed)
            .limit(to: 1)
            .getDocuments()

        return !snapshot.documents.isEmpty
    }
}
