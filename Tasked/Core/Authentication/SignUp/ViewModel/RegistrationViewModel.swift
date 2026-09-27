//
//  RegistrationViewModel.swift
//  InstagramTutorial
//
//  Created by Blake Porteous on 22/04/2025.
//  Updated: username availability check while typing (debounced).
//  Updated (Password policy pass): validate() checks PasswordPolicy;
//  friendlier weakPassword message.
//  Updated (Confirm password pass): added confirmPassword, matching
//  ChangePasswordViewModel's "type it twice" pattern.
//  Updated (Single-lowercase-username pass): username now force-lowercases
//  itself as it's typed (mirrors the didSet trick already used here to
//  trigger checkUsernameAvailability) — by the time createUser() sends it to
//  AuthService, it's already lowercase, matching how Firestore stores it
//  (see User.swift/UserService.swift for the rest of this change).
//  Updated (Stricter email pass): `email.contains("@") && email.contains(".")`
//  was passing obviously-incomplete addresses like "test@gmail." — any "."
//  anywhere satisfied it, even a trailing one with nothing after it.
//  Replaced with isValidEmail, a proper regex check requiring a real-looking
//  domain and a TLD of at least 2 letters (so "test@gmail." and
//  "test@gmail" both correctly fail, while "test@gmail.com", "test@a.co",
//  etc. pass). AddEmailView's "Next" gate and validate() both use this now.
//  Updated (Public/private pass): added isPublicAccount, set by the new
//  PublicPrivateView step between CreatePasswordView and CompleteSignUpView.
//  Defaults to true (public) so the segment stays pre-selected until
//  someone actively picks Private.
//

import Foundation
import FirebaseAuth

@MainActor
class RegistrationViewModel: ObservableObject {
    @Published var username = "" {
        didSet {
            let lowered = username.lowercased()
            if username != lowered {
                // Re-assigning triggers this didSet again; the recursive
                // call sees username already lowercase and falls through to
                // checkUsernameAvailability() below instead.
                username = lowered
                return
            }
            checkUsernameAvailability()
        }
    }
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isPublicAccount: Bool = true
    @Published var errorMessage: String = ""

    @Published var isCheckingUsername = false
    @Published var usernameError: String?
    @Published var isCreatingAccount = false

    private var usernameCheckTask: Task<Void, Never>?

    /// Requires a real-looking domain and a TLD of at least 2 letters —
    /// catches obviously-incomplete addresses like "test@gmail." or
    /// "test@gmail" that a loose contains("@")/contains(".") check would
    /// wrongly accept.
    private static let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}$"

    var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return NSPredicate(format: "SELF MATCHES %@", Self.emailRegex).evaluate(with: trimmed)
    }

    var isUsernameValid: Bool {
        !username.isEmpty && usernameError == nil && !isCheckingUsername
    }

    func createUser() async {
        errorMessage = ""
        isCreatingAccount = true
        defer { isCreatingAccount = false }

        do {
            try await AuthService.shared.createUser(email: email, password: password, username: username, isPublicAccount: isPublicAccount)
            username = ""
            email = ""
            password = ""
            confirmPassword = ""
            isPublicAccount = true
        } catch {
            let nsError = error as NSError
            if nsError.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                errorMessage = "That email is already registered. Try logging in instead."
            } else if nsError.code == AuthErrorCode.weakPassword.rawValue {
                errorMessage = "That password doesn't meet our security requirements."
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

        guard isValidEmail else {
            errorMessage = "Please enter a valid email"
            return false
        }

        guard PasswordPolicy.validate(password).isValid else {
            errorMessage = "Your password doesn't meet the requirements yet."
            return false
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords don't match."
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
