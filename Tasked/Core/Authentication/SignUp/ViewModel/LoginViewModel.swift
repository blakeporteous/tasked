//
//  LoginViewModel.swift
//  InstagramTutorial
//
//  Created by Blake Porteous on 14/07/2025.
//  Updated: added password-reset support for the "Forgot Password?" flow.
//  Updated (Delete-account fix pass): AuthService.login now throws a
//  specific, safe-to-show error when the signed-in Firebase Auth account has
//  no matching Firestore profile (e.g. a deleted account) — that message is
//  shown verbatim here. Any other error (wrong password, unknown email,
//  etc.) still shows the original deliberately-vague message, so a
//  sign-in attempt never reveals whether an email is registered.
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
        } catch let error as NSError where error.domain == "AuthService" {
            // Our own specific errors — safe and helpful to surface as-is.
            errorMessage = error.localizedDescription
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
