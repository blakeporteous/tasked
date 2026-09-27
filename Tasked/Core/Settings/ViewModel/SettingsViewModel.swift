//
//  SettingsViewModel.swift
//  Tasked
//
//  New: backs the account-management actions on SettingsView (currently just
//  account deletion — change password lives in its own small view model).
//  Updated (Delete-account fix pass): deleteAccount() now takes the
//  confirmation password typed into SettingsView's alert and passes it
//  through to AuthService.deleteAccount(password:), which reauthenticates
//  before deleting anything — see AuthService for why that ordering matters.
//  Updated (Public/private pass): added isPublicAccount, backing a toggle on
//  SettingsView's Privacy section.
//  Updated (Public/private RETROACTIVE pass): saving the privacy setting now
//  also calls PostService.updateAllPostsVisibility, rewriting isPublic on
//  every post the user has ever made to match — not just future posts.
//  Updated (Privacy confirmation pass): flipping the toggle no longer saves
//  immediately. requestPrivacyChange(to:) stages the proposed value in
//  pendingIsPublicAccount and shows a confirmation alert (SettingsView),
//  mirroring the "Delete your account?" flow already on this screen —
//  isPublicAccount (and the toggle's actual visual position) only changes
//  once confirmPrivacyChange() runs after the person confirms. Cancelling
//  (cancelPrivacyChange()) leaves everything exactly as it was.
//  Updated (Deactivate account pass): added deactivateAccount(), calling
//  AuthService.shared.deactivateAccount(). Deliberately much lighter-weight
//  than deleteAccount() — no password confirmation, since nothing
//  irreversible happens (see AuthService/User.swift: it's just a flag,
//  cleared automatically the next time this account signs in).
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isDeletingAccount = false
    @Published var isDeactivatingAccount = false
    @Published var errorMessage: String?

    /// Bound to the password field on SettingsView's delete-confirmation
    /// alert. Cleared after every attempt (success or failure) so a stray
    /// password never lingers in memory longer than it needs to.
    @Published var deleteConfirmPassword = ""

    /// The CONFIRMED privacy value — mirrors
    /// AuthService.shared.currentUser?.isPublicAccount, and is what the
    /// toggle's on-screen position actually reflects. Only ever changes
    /// inside confirmPrivacyChange(), after the person has explicitly
    /// confirmed via the alert.
    @Published var isPublicAccount: Bool = true

    /// The value proposed by tapping the toggle, held here only while the
    /// confirmation alert is up. nil the rest of the time.
    @Published var pendingIsPublicAccount: Bool?
    @Published var showPrivacyConfirmation = false

    /// True while the account doc's isPublicAccount field itself is being
    /// written — brief.
    @Published var isSavingPrivacy = false
    /// True while EVERY existing post is being rewritten to match — can take
    /// a few seconds for someone with a long post history. Kept separate
    /// from isSavingPrivacy so the view can show a more specific label.
    @Published var isApplyingToExistingPosts = false

    init() {
        isPublicAccount = AuthService.shared.currentUser?.isPublicAccount ?? true
    }

    /// Called when the toggle is tapped. Deliberately does NOT touch
    /// isPublicAccount — that's what keeps the toggle from visually moving
    /// until the person actually confirms in the alert.
    func requestPrivacyChange(to newValue: Bool) {
        guard newValue != isPublicAccount else { return }
        pendingIsPublicAccount = newValue
        showPrivacyConfirmation = true
    }

    /// Called when the alert's Cancel button is tapped. Leaves
    /// isPublicAccount untouched, so the toggle just sits back at its
    /// original position as if nothing happened.
    func cancelPrivacyChange() {
        pendingIsPublicAccount = nil
        showPrivacyConfirmation = false
    }

    /// Called when the alert's "Switch to Public/Private" button is tapped.
    /// Saves the new value on the user's document, flips isPublicAccount
    /// (which is what actually moves the toggle), then retroactively
    /// rewrites every existing post to match.
    func confirmPrivacyChange() async {
        guard let newValue = pendingIsPublicAccount, let uid = AuthService.shared.currentUser?.id else {
            cancelPrivacyChange()
            return
        }

        errorMessage = nil
        isSavingPrivacy = true
        defer {
            isSavingPrivacy = false
            isApplyingToExistingPosts = false
            pendingIsPublicAccount = nil
        }

        do {
            try await Firestore.firestore().collection("users").document(uid)
                .updateData(["isPublicAccount": newValue])

            if var user = AuthService.shared.currentUser {
                user.isPublicAccount = newValue
                AuthService.shared.currentUser = user
            }
            isPublicAccount = newValue

            isApplyingToExistingPosts = true
            try await PostService.updateAllPostsVisibility(ownerUid: uid, isPublic: newValue)
        } catch {
            errorMessage = "Couldn't update your privacy setting: \(error.localizedDescription)"
        }
    }

    /// Returns true on success. AuthService clears the session on success, which
    /// ContentView is already subscribed to, so the app returns to LoginView on
    /// its own — no explicit navigation needed here.
    func deleteAccount() async -> Bool {
        errorMessage = nil

        let password = deleteConfirmPassword
        guard !password.isEmpty else {
            errorMessage = "Enter your password to confirm."
            return false
        }

        isDeletingAccount = true
        defer {
            isDeletingAccount = false
            deleteConfirmPassword = ""
        }

        do {
            try await AuthService.shared.deleteAccount(password: password)
            return true
        } catch {
            errorMessage = "Couldn't delete your account: \(error.localizedDescription)"
            return false
        }
    }

    /// Deactivates the signed-in user's account. Nothing irreversible
    /// happens — see AuthService.deactivateAccount — so this deliberately
    /// skips the password-confirmation step deleteAccount() requires.
    /// AuthService signs the account out on success, which ContentView is
    /// already subscribed to, so the app returns to LoginView on its own.
    func deactivateAccount() async -> Bool {
        errorMessage = nil
        isDeactivatingAccount = true
        defer { isDeactivatingAccount = false }

        do {
            try await AuthService.shared.deactivateAccount()
            return true
        } catch {
            errorMessage = "Couldn't deactivate your account: \(error.localizedDescription)"
            return false
        }
    }
}
