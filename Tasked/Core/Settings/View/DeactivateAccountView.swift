//
//  DeactivateAccountView.swift
//  Tasked
//
//  New (Settings revamp pass): standalone page for deactivating the account,
//  built on the shared SettingsDetailView/SettingsCard template. Replaces
//  the old direct "Deactivate Account" button + confirmationDialog that
//  lived on SettingsView — the toggle here plays the same "flip it on ->
//  confirm -> it happens" role, just as its own page. Reuses
//  SettingsViewModel.deactivateAccount() unchanged; the toggle snaps back
//  off if the confirmation is cancelled or the deactivation itself fails,
//  so it never shows "on" without the account actually being deactivated
//  (a moot point in practice — success signs the account out and this
//  screen disappears with it, same as before).
//

import SwiftUI

struct DeactivateAccountView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var isOn = false
    @State private var showConfirmation = false

    var body: some View {
        SettingsDetailView(title: "Deactivate Account") {
            SettingsCard {
                Toggle(
                    "Deactivate account",
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
                Text("Your profile and posts will be hidden from everyone until you log back in — signing back in reactivates your account automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isDeactivatingAccount {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Deactivating…")
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
        .confirmationDialog(
            "Deactivate your account?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Deactivate", role: .destructive) {
                Task {
                    let success = await viewModel.deactivateAccount()
                    isOn = success
                }
            }
            Button("Cancel", role: .cancel) {
                isOn = false
            }
        } message: {
            Text("Your profile and posts will be hidden from everyone until you log back in.")
        }
    }
}

#Preview {
    NavigationStack { DeactivateAccountView(viewModel: SettingsViewModel()) }
}
