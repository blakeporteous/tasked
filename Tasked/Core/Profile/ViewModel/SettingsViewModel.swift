//
//  SettingsViewModel.swift
//  Tasked
//
//  New: backs the account-management actions on SettingsView (currently just
//  account deletion — change password lives in its own small view model).
//

import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isDeletingAccount = false
    @Published var errorMessage: String?

    /// Returns true on success. AuthService clears the session on success, which
    /// ContentView is already subscribed to, so the app returns to LoginView on
    /// its own — no explicit navigation needed here.
    func deleteAccount() async -> Bool {
        errorMessage = nil
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await AuthService.shared.deleteAccount()
            return true
        } catch {
            errorMessage = "Couldn't delete your account: \(error.localizedDescription)"
            return false
        }
    }
}
