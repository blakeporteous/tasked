//
//  PasswordRequirementsView.swift
//  Tasked
//
//  New (Password policy pass): live checklist shown under a password field
//  wherever PasswordPolicy applies (sign-up's CreatePasswordView, Settings'
//  ChangePasswordView). Each requirement ticks green as soon as the
//  currently-typed password satisfies it. Deliberately unpadded — call sites
//  add their own horizontal padding to match their surrounding layout (a
//  plain VStack screen vs. a Form section already has its own insets).
//  Updated (Blue dot pass): satisfied indicator switched from a green
//  checkmark to a plain blue circle.
//  Updated (Blue checkmark pass): back to a checkmark, just colored blue
//  now instead of green — a filled blue circle with a white check inside,
//  matching the app's blue accent color.
//

import SwiftUI

struct PasswordRequirementsView: View {
    let password: String

    private var satisfied: Set<PasswordPolicy.Requirement> {
        PasswordPolicy.validate(password).satisfied
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PasswordPolicy.Requirement.allCases) { requirement in
                HStack(spacing: 6) {
                    Image(systemName: satisfied.contains(requirement) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(satisfied.contains(requirement) ? Color.appAccent : .secondary)
                        .imageScale(.small)
                    Text(requirement.description)
                        .font(.caption)
                        .foregroundStyle(satisfied.contains(requirement) ? .primary : .secondary)
                }
            }
        }
    }
}

#Preview {
    PasswordRequirementsView(password: "Abc123!")
}
