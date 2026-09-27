//
//  ChangePasswordViewModel.swift
//  Tasked
//
//  New: backs ChangePasswordView, reachable from Settings > Account.
//  Updated (Password policy pass): save() now validates newPassword against
//  PasswordPolicy (mirrors the strict Firebase Auth console policy) instead
//  of a flat 6-character minimum.
//

import Foundation

@MainActor
class ChangePasswordViewModel: ObservableObject {
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    /// Returns true on success so the view can dismiss.
    func save() async -> Bool {
        errorMessage = nil

        guard PasswordPolicy.validate(newPassword).isValid else {
            errorMessage = "Your new password doesn't meet the requirements yet."
            return false
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await AuthService.shared.updatePassword(newPassword: newPassword)
            return true
        } catch {
            errorMessage = "Couldn't update password: \(error.localizedDescription)"
            return false
        }
    }
}
