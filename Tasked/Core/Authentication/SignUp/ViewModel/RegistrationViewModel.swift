//
//  RegistrationViewModel.swift
//  InstagramTutorial
//
//  Created by Blake Porteous on 22/04/2025.
//  Updated: username availability check while typing (debounced, mirrors
//  SearchViewModel's pattern) and friendlier error messages for sign-up failures,
//  including Firebase's "email already in use" error.
//

import Foundation
import FirebaseAuth

@MainActor
class RegistrationViewModel: ObservableObject {
    @Published var username = "" {
        didSet { checkUsernameAvailability() }
    }
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String = ""

    @Published var isCheckingUsername = false
    @Published var usernameError: String?
    @Published var isCreatingAccount = false

    private var usernameCheckTask: Task<Void, Never>?

    var isUsernameValid: Bool {
        !username.isEmpty && usernameError == nil && !isCheckingUsername
    }

    func createUser() async {
        errorMessage = ""
        isCreatingAccount = true
        defer { isCreatingAccount = false }

        do {
            try await AuthService.shared.createUser(email: email, password: password, username: username)
            username = ""
            email = ""
            password = ""
        } catch {
            let nsError = error as NSError
            if nsError.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                errorMessage = "That email is already registered. Try logging in instead."
            } else {
                errorMessage = "Couldn't create your account: \(error.localizedDescription)"
            }
        }
    }

    func validate() -> Bool {
        errorMessage = ""

        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a name"
            return false
        }

        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter an email address"
            return false
        }

        guard !password.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a password"
            return false
        }

        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email"
            return false
        }

        guard password.count >= 6 else {
            errorMessage = "Please enter a password of 6 or more characters"
            return false
        }

        return true
    }

    /// Debounced check against Firestore so we don't fire a read on every keystroke.
    private func checkUsernameAvailability() {
        usernameCheckTask?.cancel()
        let candidate = username.trimmingCharacters(in: .whitespaces)

        guard !candidate.isEmpty else {
            usernameError = nil
            isCheckingUsername = false
            return
        }

        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            isCheckingUsername = true
            defer { isCheckingUsername = false }

            do {
                if try await UserService.isUsernameTaken(candidate) {
                    usernameError = "That username is already taken."
                } else {
                    usernameError = nil
                }
            } catch {
                // Fail open — the account-creation write is still the source of truth.
                usernameError = nil
            }
        }
    }
}
