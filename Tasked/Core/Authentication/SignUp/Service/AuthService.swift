//
//  AuthService.swift
//  Tasked
//
//  Created by Blake Porteous on 27/03/2025.
//  Updated: added password reset, password change, and account deletion.
//  Updated (Live-currentUser pass): currentUser is now kept live via a
//  Firestore snapshot listener on the signed-in user's own document.
//  Updated (Push notifications): loadUserData now calls
//  PushNotificationManager.saveTokenIfNeeded() once currentUser is set.
//  Updated (Delete-account fix pass): loadUserData() now only sets
//  userSession on a successful profile fetch.
//  Updated (Email verification pass): new accounts get a verification email
//  automatically. Added `isEmailVerified`, refreshed via
//  refreshEmailVerificationStatus().
//  Updated (Flicker-fix pass): createUser() and loadUserData() resolve
//  isEmailVerified (and currentUser) BEFORE flipping userSession, so
//  ContentView makes one clean transition instead of a flash.
//  Updated (Case-insensitive email pass): login(withEmail:), createUser(),
//  and resetPassword() all normalize the email (trim whitespace, lowercase)
//  before ever calling Firebase.
//  Updated (Single-lowercase-username pass): uploadUserData() lowercases
//  username itself before it's written; no separate usernameLower field.
//  Updated (Drop fullname pass): createUser()/uploadUserData() no longer
//  take or write a fullname at all — it wasn't collected at sign-up and
//  wasn't used anywhere (see User.swift).
//  Updated (Public/private pass): createUser()/uploadUserData() now also
//  take isPublicAccount, sourced from PublicPrivateView via
//  RegistrationViewModel, and write it onto the new user's document.
//  Updated (Deactivate account pass): added deactivateAccount(), which sets
//  isDeactivated on the signed-in user's document and signs them out (same
//  "hide, don't touch the data" idea as blocking, just applied to yourself).
//  loadUserData() now also checks the freshly-fetched profile for
//  isDeactivated and, if set, clears it automatically right there — so
//  simply signing back in is what "reactivates" a deactivated account, no
//  separate button/screen needed. This runs BEFORE userSession is set, same
//  ordering rationale as the email-verification flicker fix above.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Firebase

class AuthService {

    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    /// Mirrors Auth.auth().currentUser?.isEmailVerified, refreshed via
    /// refreshEmailVerificationStatus() since Firebase Auth's own cached
    /// value doesn't update on its own once the person taps the link in
    /// their verification email.
    @Published var isEmailVerified: Bool = false

    static let shared = AuthService()

    private var currentUserListener: ListenerRegistration?

    init() {
        Task { try? await loadUserData() }
    }

    /// Trims whitespace and lowercases an email address. Used before every
    /// Firebase Auth call in this file.
    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @MainActor
    func login(withEmail email: String, password: String) async throws {
        // Deliberately doesn't set userSession here — loadUserData() is now
        // the only place that does, and only once it's confirmed a Firestore
        // profile actually exists to go with this Auth account.
        _ = try await Auth.auth().signIn(withEmail: normalized(email), password: password)
        try await loadUserData()
    }

    @MainActor
    func createUser(email: String, password: String, username: String, isPublicAccount: Bool = true) async throws {
        let normalizedEmail = normalized(email)
        let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)

        // Deliberately NOT setting userSession yet — userSession is what
        // flips ContentView away from the sign-up flow's own screens (like
        // CompleteSignUpView's "Welcome to Tasked" message), so the
        // Firestore profile (uploadUserData sets currentUser) and the
        // verification status both need to be ready FIRST. That way the
        // transition goes straight from "Welcome" to VerifyEmailView in one
        // clean step, instead of flashing through ContentView's "Loading
        // your profile…" screen in between.
        try await uploadUserData(uid: result.user.uid, username: username, email: normalizedEmail, isPublicAccount: isPublicAccount)
        self.isEmailVerified = result.user.isEmailVerified // false for a brand-new account
        self.userSession = result.user

        // Fire-and-forget — a failed verification email shouldn't fail
        // account creation itself. The person can always hit "Resend" on
        // VerifyEmailView if this doesn't land.
        try? await result.user.sendEmailVerification()
    }

    /// Loads the signed-in user's profile, then keeps it live from then on.
    /// Only marks the session as "signed in" (userSession) once BOTH the
    /// Firestore profile fetch and the verification-status check have
    /// resolved.
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

        // A deactivated account that's successfully signing back in is
        // exactly what "reactivate" means — flip it live right here, before
        // userSession is set, so the rest of the app (feed/search/friends
        // filters) never sees this account as deactivated once it's
        // actually signed in. Best-effort: a failed write here shouldn't
        // block sign-in itself; it'll just retry next launch/login.
        if self.currentUser?.isDeactivated == true {
            try? await reactivateAccount(uid: currentUid)
        }

        // Resolve verification status against Firebase's servers BEFORE
        // flipping userSession — without this ordering, isEmailVerified
        // still held its stale default (false) for the instant between
        // userSession updating and this reload actually finishing, which
        // caused VerifyEmailView to flash on-screen for every sign-in, even
        // an already-verified one.
        try? await Auth.auth().currentUser?.reload()
        self.isEmailVerified = Auth.auth().currentUser?.isEmailVerified ?? false

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
        try await Auth.auth().sendPasswordReset(withEmail: normalized(email))
    }

    /// Changes the signed-in user's password. Used by ChangePasswordView.
    @MainActor
    func updatePassword(newPassword: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You're not signed in."])
        }
        try await user.updatePassword(to: newPassword)
    }

    /// Re-sends the verification email to the signed-in user's address.
    /// Used by VerifyEmailView's "Resend" button.
    @MainActor
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You're not signed in."])
        }
        try await user.sendEmailVerification()
    }

    /// Re-checks email verification status against Firebase's servers.
    /// Returns the freshly-checked value.
    @MainActor
    @discardableResult
    func refreshEmailVerificationStatus() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            isEmailVerified = false
            return false
        }
        try? await user.reload()
        isEmailVerified = user.isEmailVerified
        return isEmailVerified
    }

    /// Marks the signed-in user's account as deactivated (hidden from
    /// search/feed/friends lists — see UserService.searchUsers,
    /// PostService's feed listeners, FriendsViewModel) and signs them out.
    /// Nothing is deleted — every post, friendship, etc. is untouched, and
    /// simply signing back in flips isDeactivated back off automatically
    /// (see loadUserData above).
    @MainActor
    func deactivateAccount() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "You're not signed in."])
        }

        try await Firestore.firestore().collection("users").document(uid)
            .updateData(["isDeactivated": true])

        signOut()
    }

    /// Clears isDeactivated on `uid`'s document and, if that's the currently
    /// loaded profile, updates the local copy too so nothing downstream
    /// briefly sees a stale "deactivated" value. Called automatically from
    /// loadUserData() whenever a deactivated account successfully signs in
    /// — there's no separate user-facing "Reactivate" action, this IS it.
    @MainActor
    private func reactivateAccount(uid: String) async throws {
        try await Firestore.firestore().collection("users").document(uid)
            .updateData(["isDeactivated": false])

        if var user = self.currentUser, user.id == uid {
            user.isDeactivated = false
            self.currentUser = user
        }
    }

    /// Deletes the signed-in user's account and Firestore profile. Requires
    /// their current password to reauthenticate FIRST.
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

        try await Firestore.firestore().collection("users").document(user.uid).delete()
        try await user.delete()

        clearLocalSession()
    }

    /// Writes the signed-in user's initial Firestore profile at sign-up.
    /// `username` is always lowercased here.
    @MainActor
    private func uploadUserData(uid: String, username: String = "", email: String = "", isPublicAccount: Bool = true) async throws {
        let lowercasedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
        let user = User(id: uid, username: lowercasedUsername, isPublicAccount: isPublicAccount, email: email)
        self.currentUser = user

        let encodedUser = try Firestore.Encoder().encode(user)
        try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
        startListeningToCurrentUser(uid: user.id)
        PushNotificationManager.shared.saveTokenIfNeeded()
    }

    /// Fully clears local session/state.
    private func clearLocalSession() {
        stopListeningToCurrentUser()
        self.userSession = nil
        self.currentUser = nil
        self.isEmailVerified = false
    }
}
