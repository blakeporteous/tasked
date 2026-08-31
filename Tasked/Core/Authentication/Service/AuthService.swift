//
//  AuthService.swift
//  Tasked
//
//  Created by Blake Porteous on 27/03/2025.
//  Updated: User no longer has followersCount/followingCount; new accounts also get a
//  usernameLower field written so UserService.searchUsers can query it.
//  Updated: added password reset, password change, and account deletion, backing
//  the new "Forgot Password" flow and Settings > Account screens.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Firebase

class AuthService {

    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?

    static let shared = AuthService()

    init() {
        Task { try? await loadUserData() }
    }

    @MainActor
    func login(withEmail email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.userSession = result.user
        try await loadUserData()
    }

    @MainActor
    func createUser(email: String, password: String, username: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.userSession = result.user
        try await uploadUserData(uid: result.user.uid, username: username, email: email)
    }

    @MainActor
    func loadUserData() async throws {
        self.userSession = Auth.auth().currentUser
        guard let currentUid = userSession?.uid else { return }
        self.currentUser = try await UserService.fetchUser(withUid: currentUid)
    }

    func signOut() {
        try? Auth.auth().signOut()
        self.userSession = nil
        self.currentUser = nil
    }

    /// Sends a Firebase password-reset email. Used by the "Forgot Password?" flow on LoginView.
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    /// Changes the signed-in user's password. Used by ChangePasswordView.
    @MainActor
    func updatePassword(newPassword: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You're not signed in."])
        }
        try await user.updatePassword(to: newPassword)
    }

    /// Deletes the signed-in user's account and Firestore profile.
    /// NOTE: doesn't clean up the user's posts, friend requests, or notifications —
    /// fine for now, but worth a Cloud Function pass before this ships widely.
    @MainActor
    func deleteAccount() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You're not signed in."])
        }
        try await Firestore.firestore().collection("users").document(uid).delete()
        try await Auth.auth().currentUser?.delete()
        self.userSession = nil
        self.currentUser = nil
    }

    @MainActor
    private func uploadUserData(uid: String, username: String = "", email: String = "") async throws {
        let user = User(id: uid, username: username, email: email)
        self.currentUser = user

        var encodedUser = try Firestore.Encoder().encode(user)
        // Not part of the Codable model — write-only field that powers case-insensitive search.
        encodedUser["usernameLower"] = username.lowercased()

        try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
    }
}
