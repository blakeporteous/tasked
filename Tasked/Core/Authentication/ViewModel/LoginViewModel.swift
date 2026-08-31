//
//  LoginViewModel.swift
//  InstagramTutorial
//
//  Created by Blake Porteous on 14/07/2025.
//  Updated: added password-reset support for the "Forgot Password?" flow.
//

import Foundation

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    @Published var resetEmail = ""
    @Published var resetMessage: String?
    @Published var isSendingReset = false

    func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthService.shared.login(withEmail: email, password: password)
        } catch {
            errorMessage = "Couldn't sign in. Check your email and password and try again."
        }
    }

    func sendPasswordReset() async {
        resetMessage = nil

        let trimmed = resetEmail.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            resetMessage = "Enter your email first."
            return
        }

        isSendingReset = true
        defer { isSendingReset = false }

        do {
            try await AuthService.shared.resetPassword(email: trimmed)
            resetMessage = "Check your inbox for a reset link."
        } catch {
            resetMessage = "Couldn't send reset email: \(error.localizedDescription)"
        }
    }
}
