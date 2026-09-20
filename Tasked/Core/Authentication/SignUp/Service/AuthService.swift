//
//  AuthService.swift
//  Tasked
//
//  Created by Blake Porteous on 27/03/2025.
//  Updated: User no longer has followersCount/followingCount; new accounts also get a
//  usernameLower field written so UserService.searchUsers can query it.
//  Updated: added password reset, password change, and account deletion, backing
//  the new "Forgot Password" flow and Settings > Account screens.
//  Updated (Live-currentUser pass): currentUser is now kept live via a
//  Firestore snapshot listener on the signed-in user's own document.
//  Updated (Push notifications): loadUserData now calls
//  PushNotificationManager.saveTokenIfNeeded() once currentUser is set, so a
//  token generated before login (or a stale one from a previous account on
//  this device) gets attached to the right user right away. signOut clears
//  the token first, so a push never gets sent to a device that's no longer
//  signed in as that user.
//  Updated (Delete-account fix pass): two bugs, one root cause. (1)
//  deleteAccount() used to delete the Firestore profile FIRST and the Auth
//  account LAST — but deleting the Auth account requires a fresh sign-in
//  ("requiresRecentLogin"), and if the session wasn't fresh enough, that
//  step threw, leaving the account half-deleted: Firestore profile gone,
//  Auth account still alive. deleteAccount(password:) now reauthenticates
//  with the person's password FIRST, so that failure mode can't happen —
//  Firestore delete then Auth delete both run only once we know they'll
//  succeed. (2) login()/loadUserData() used to set `userSession` before
//  confirming a Firestore profile actually existed for it; if it didn't
//  (e.g. exactly the half-deleted state above), the fetch threw but nothing
//  ever reset userSession back to nil — ContentView was left showing
//  "signed in, but no profile", i.e. stuck forever on its "Loading your
//  profile…" screen instead of an error. loadUserData() now only sets
//  userSession on a SUCCESSFUL profile fetch, and signs out + throws a
//  clear, specific error otherwise, so a deleted/missing account routes
//  straight back to LoginView with an explanation instead of hanging.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Firebase

class AuthService {

    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?

    static let shared = AuthService()

    private var currentUserListener: ListenerRegistration?

    init() {
        Task { try? await loadUserData() }
    }

    @MainActor
    func login(withEmail email: String, password: String) async throws {
        // Deliberately doesn't set userSession here — loadUserData() is now
        // the only place that does, and only once it's confirmed a Firestore
        // profile actually exists to go with this Auth account.
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
        try await loadUserData()
    }

    @MainActor
    func createUser(email: String, password: String, username: String, fullname: String = "") async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.userSession = result.user
        try await uploadUserData(uid: result.user.uid, username: username, email: email, fullname: fullname)
    }

    /// Loads the signed-in user's profile, then keeps it live from then on —
    /// see the Live-currentUser pass note above. Only marks the session as
    /// "signed in" (userSession) once the Firestore profile fetch actually
    /// succeeds — see the Delete-account fix pass note above for why.
    @MainActor
    func loadUserData() async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            clearLocalSession()
            return
        }

        do {
            self.currentUser = try await UserService.fetchUser(withUid: currentUid)
        } catch {
            // Signed in with Firebase Auth, but no matching Firestore
            // profile — most commonly an account that was deleted (or
            // half-deleted). Don't leave the app stuck on "signed in, no
            // profile" — treat it as "this account no longer exists."
            clearLocalSession()
            throw NSError(domain: "AuthService", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "This account could not be found. It may have been deleted."
            ])
        }

        self.userSession = Auth.auth().currentUser
        startListeningToCurrentUser(uid: currentUid)
        PushNotificationManager.shared.saveTokenIfNeeded()
    }

    @MainActor
    private func startListeningToCurrentUser(uid: String) {
        currentUserListener?.remove()
        currentUserListener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot, let user = try? snapshot.data(as: User.self) else { return }
                Task { @MainActor in
                    self?.currentUser = user
                }
            }
    }

    private func stopListeningToCurrentUser() {
        currentUserListener?.remove()
        currentUserListener = nil
    }

    func signOut() {
        if let uid = userSession?.uid {
            PushNotificationManager.shared.clearToken(uid: uid)
        }
        try? Auth.auth().signOut()
        clearLocalSession()
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

    /// Deletes the signed-in user's account and Firestore profile. Requires
    /// their current password to reauthenticate FIRST — see the
    /// Delete-account fix pass note above for why this order matters.
    /// NOTE: doesn't clean up the user's posts, friend requests, or
    /// notifications — fine for now, but worth a Cloud Function pass
    /// (functions.auth.user().onDelete()) before this ships widely, so
    /// orphaned data gets swept up server-side regardless of how the
    /// account was deleted.
    @MainActor
    func deleteAccount(password: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You're not signed in."])
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            try await user.reauthenticate(with: credential)
        } catch {
            throw NSError(domain: "AuthService", code: -4, userInfo: [NSLocalizedDescriptionKey: "That password wasn't correct."])
        }

        stopListeningToCurrentUser()

        // Firestore first — while we're freshly, genuinely authenticated as
        // this user, which the delete rule requires — then the Auth account
        // itself last.
        try await Firestore.firestore().collection("users").document(user.uid).delete()
        try await user.delete()

        clearLocalSession()
    }

    @MainActor
    private func uploadUserData(uid: String, username: String = "", email: String = "", fullname: String = "") async throws {
        let trimmedFullname = fullname.trimmingCharacters(in: .whitespaces)
        let user = User(id: uid, username: username, fullname: trimmedFullname.isEmpty ? nil : trimmedFullname, email: email)
        self.currentUser = user

        var encodedUser = try Firestore.Encoder().encode(user)
        // Not part of the Codable model — write-only field that powers case-insensitive search.
        encodedUser["usernameLower"] = username.lowercased()

        try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
        startListeningToCurrentUser(uid: user.id)
        PushNotificationManager.shared.saveTokenIfNeeded()
    }

    /// Fully clears local session/state — used by signOut(), by a failed
    /// profile load (missing/deleted account), and after a successful
    /// deleteAccount(), so ContentView routes back to LoginView immediately
    /// rather than needing an app relaunch to notice. Deliberately NOT
    /// @MainActor: signOut() (which calls this) isn't either, and is called
    /// synchronously from plain, non-async button actions elsewhere in the
    /// app (e.g. ContentView's fallback "Sign Out" button) — matches the
    /// existing, pre-this-pass pattern of stopListeningToCurrentUser() right
    /// below, which was never actor-isolated either.
    private func clearLocalSession() {
        stopListeningToCurrentUser()
        self.userSession = nil
        self.currentUser = nil
    }
}
