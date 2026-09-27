//
//  VerifyEmailViewModel.swift
//  Tasked
//
//  New (Email verification pass): backs VerifyEmailView, shown by
//  ContentView whenever a signed-in user's profile has loaded but
//  AuthService.shared.isEmailVerified is still false.
//

import Foundation

@MainActor
class VerifyEmailViewModel: ObservableObject {
    @Published var isRefreshing = false
    @Published var isResending = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    /// Seconds remaining before "Resend" can be tapped again — a lightweight
    /// guard against hammering Firebase's email-sending quota.
    @Published var resendCooldown = 0

    private var cooldownTimer: Timer?

    var email: String {
        AuthService.shared.userSession?.email ?? "your email address"
    }

    /// Called on appear and from the "I've verified — refresh" button.
    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        let verified = await AuthService.shared.refreshEmailVerificationStatus()
        if !verified {
            infoMessage = "Still not verified — check your inbox (and spam folder)."
        }
    }

    func resend() async {
        guard resendCooldown == 0, !isResending else { return }
        isResending = true
        errorMessage = nil
        infoMessage = nil
        defer { isResending = false }

        do {
            try await AuthService.shared.sendEmailVerification()
            infoMessage = "Verification email sent to \(email)."
            startCooldown()
        } catch {
            errorMessage = "Couldn't send that: \(error.localizedDescription)"
        }
    }

    private func startCooldown() {
        resendCooldown = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                if self.resendCooldown > 0 {
                    self.resendCooldown -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }

    deinit {
        cooldownTimer?.invalidate()
    }
}
