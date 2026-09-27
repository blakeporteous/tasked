//
//  ChangePasswordView.swift
//  Tasked
//
//  New: reachable from Settings > Account > Change Password.
//  Updated (Password policy pass): shows the live PasswordRequirementsView
//  checklist.
//  Updated (Nicer-form pass): added a small icon + blurb header.
//  Updated (Settings template pass): rebuilt on the shared
//  SettingsDetailView/SettingsCard template (SettingsTemplates.swift).
//  Updated (Blue save button pass): "Save Password" no longer uses
//  .inkButton() — that shared chrome defaults to the app's orange/red CTA
//  color, and this screen wants blue specifically. Self-contained styling
//  here instead (same full-width/uppercase/rounded shape as inkButton,
//  just tinted with Color.appAccent) — matches the same treatment
//  EditProfileView's "Save Changes" button already uses.
//

import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ChangePasswordViewModel()

    private var isSaveDisabled: Bool {
        viewModel.isSaving || viewModel.newPassword.isEmpty
    }

    var body: some View {
        SettingsDetailView(title: "Change Password") {
            VStack(spacing: 8) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.appAccent)
                Text("Choose a new password to protect your account")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            SettingsCard {
                SecureField("New password", text: $viewModel.newPassword)

                Divider()

                SecureField("Confirm new password", text: $viewModel.confirmPassword)

                Divider()

                PasswordRequirementsView(password: viewModel.newPassword)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    if await viewModel.save() {
                        dismiss()
                    }
                }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save Password")
                    }
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .compositingGroup()
                .opacity(isSaveDisabled ? 0.5 : 1)
            }
            .disabled(isSaveDisabled)
        }
    }
}

#Preview {
    NavigationStack { ChangePasswordView() }
}
