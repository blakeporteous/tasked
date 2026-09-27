//
//  DeleteAccountView.swift
//  Tasked
//
//  New (Settings revamp pass): standalone page for deleting the account,
//  built on the shared SettingsDetailView/SettingsCard template. Replaces
//  the old direct "Delete Account" button + password alert that lived on
//  SettingsView — the toggle here plays the same role, just as its own
//  page: flipping it on prompts the password-confirmation alert
//  (SettingsViewModel.deleteConfirmPassword / deleteAccount() unchanged),
//  and the toggle snaps back off on cancel or failure.
//

import SwiftUI

struct DeleteAccountView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var isOn = false
    @State private var showConfirmation = false

    var body: some View {
        SettingsDetailView(title: "Delete Account") {
            SettingsCard {
                Toggle(
                    "Delete account",
                    isOn: Binding(
                        get: { isOn },
                        set: { newValue in
                            if newValue {
                                showConfirmation = true
                            } else {
                                isOn = false
                            }
                        }
                    )
                )
                .tint(.red)
                Text("This permanently deletes your profile, posts, and account data. This can't be undone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isDeletingAccount {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Deleting…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .alert("Delete your account?", isPresented: $showConfirmation) {
            SecureField("Current password", text: $viewModel.deleteConfirmPassword)
                .textInputAutocapitalization(.never)

            Button("Delete Account", role: .destructive) {
                Task {
                    let success = await viewModel.deleteAccount()
                    isOn = success
                }
            }
            Button("Cancel", role: .cancel) {
                isOn = false
                viewModel.deleteConfirmPassword = ""
            }
        } message: {
            Text("Enter your password to confirm. This permanently deletes your profile and can't be undone.")
        }
    }
}

#Preview {
    NavigationStack { DeleteAccountView(viewModel: SettingsViewModel()) }
}
