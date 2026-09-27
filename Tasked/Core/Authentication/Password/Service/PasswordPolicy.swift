//
//  PasswordPolicy.swift
//  Tasked
//
//  New (Password policy pass): mirrors the "strict" Firebase Auth password
//  policy (Authentication > Settings > Password policy in the Firebase
//  console: require lowercase, uppercase, numeric, and non-alphanumeric
//  characters, minimum length 8, enforcement mode "Require").
//
//  IMPORTANT: this is only the CLIENT-side mirror, used for live validation
//  and the checklist UI (PasswordRequirementsView) so people find out about
//  a weak password before submitting, not after a rejected write. The real
//  enforcement happens server-side once the matching policy is turned on in
//  the Firebase console — a modified/jailbroken client could otherwise skip
//  this file entirely. If the console policy is ever changed, update this
//  file (specifically `minimumLength`) to match, or the two will disagree.
//

import Foundation

enum PasswordPolicy {

    /// Must match the "Minimum length" set in the Firebase console's
    /// password policy. Firebase's own default is 6; this project's console
    /// policy is configured for 8.
    static let minimumLength = 8

    /// Exactly the character set Firebase's own docs list as satisfying the
    /// "non-alphanumeric character" requirement.
    private static let specialCharacters = "^$*.[]{}()?\"!@#%&/\\,><':;|_~`"

    enum Requirement: CaseIterable, Identifiable {
        case length
        case lowercase
        case uppercase
        case number
        case specialCharacter

        var id: Self { self }

        var description: String {
            switch self {
            case .length: return "At least \(PasswordPolicy.minimumLength) characters"
            case .lowercase: return "A lowercase letter"
            case .uppercase: return "An uppercase letter"
            case .number: return "A number"
            case .specialCharacter: return "A special character (! @ # $ % etc.)"
            }
        }

        func isSatisfied(by password: String) -> Bool {
            switch self {
            case .length:
                return password.count >= PasswordPolicy.minimumLength
            case .lowercase:
                return password.contains { $0.isLowercase }
            case .uppercase:
                return password.contains { $0.isUppercase }
            case .number:
                return password.contains { $0.isNumber }
            case .specialCharacter:
                return password.contains { PasswordPolicy.specialCharacters.contains($0) }
            }
        }
    }

    struct ValidationResult {
        let satisfied: Set<Requirement>
        var isValid: Bool { satisfied.count == Requirement.allCases.count }
    }

    static func validate(_ password: String) -> ValidationResult {
        ValidationResult(satisfied: Set(Requirement.allCases.filter { $0.isSatisfied(by: password) }))
    }
}
