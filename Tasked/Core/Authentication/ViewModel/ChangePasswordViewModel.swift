//
//  ChangePasswordViewModel.swift
//  Tasked
//
//  New: backs ChangePasswordView, reachable from Settings > Account.
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

        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
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
