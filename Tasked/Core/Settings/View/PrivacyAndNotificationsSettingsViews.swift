//
//  PrivacyAndNotificationsSettingsViews.swift
//  Tasked
//
//  New (Settings revamp pass).
//  AccountPrivacyView wires up SettingsViewModel's existing public/private
//  plumbing (requestPrivacyChange/confirmPrivacyChange/
//  pendingIsPublicAccount) — that logic already existed on SettingsViewModel
//  but SettingsView never actually surfaced a toggle for it. Flipping the
//  toggle doesn't change anything until the confirmation is accepted, at
//  which point every existing post is retroactively rewritten to match
//  (PostService.updateAllPostsVisibility) — same behavior as before, just
//  finally reachable.
//  EmailNotificationsSettingsView and PersonalizedAdsSettingsView have no
//  backend behind them yet — local placeholder state, same pattern as
//  PostingSettingsViews.
//

import SwiftUI

struct AccountPrivacyView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        SettingsDetailView(title: "Account Privacy") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(
                        "Public account",
                        isOn: Binding(
                            get: { viewModel.isPublicAccount },
                            set: { viewModel.requestPrivacyChange(to: $0) }
                        )
                    )
                    Text(viewModel.isPublicAccount
                         ? "Anyone can see your posts."
                         : "Only friends you accept can see your posts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isSavingPrivacy || viewModel.isApplyingToExistingPosts {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(viewModel.isApplyingToExistingPosts ? "Updating your existing posts…" : "Saving…")
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
            viewModel.pendingIsPublicAccount == true ? "Switch to a public account?" : "Switch to a private account?",
            isPresented: $viewModel.showPrivacyConfirmation,
            titleVisibility: .visible
        ) {
            Button(viewModel.pendingIsPublicAccount == true ? "Switch to Public" : "Switch to Private") {
                Task { await viewModel.confirmPrivacyChange() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelPrivacyChange()
            }
        } message: {
            Text("This also updates every post you've already shared to match.")
        }
    }
}

struct EmailNotificationsSettingsView: View {
    @State private var weeklyDigest = true
    @State private var productUpdates = false
    @State private var securityAlerts = true

    var body: some View {
        SettingsDetailView(title: "Email Notifications") {
            SettingsCard {
                SettingsToggleRow(title: "Weekly digest", subtitle: "A summary of your week's activity.", isOn: $weeklyDigest)
                Divider()
                SettingsToggleRow(title: "Product updates", subtitle: "New features and announcements.", isOn: $productUpdates)
                Divider()
                SettingsToggleRow(title: "Security alerts", subtitle: "Sign-ins from a new device.", isOn: $securityAlerts)
            }
        }
    }
}

struct PersonalizedAdsSettingsView: View {
    @State private var personalizedAdsEnabled = true

    var body: some View {
        SettingsDetailView(title: "Personalised Ads") {
            SettingsCard {
                SettingsToggleRow(
                    title: "Personalised ads",
                    subtitle: "Use your activity in the app to show more relevant ads.",
                    isOn: $personalizedAdsEnabled
                )
            }
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false

    var body: some View {
        SettingsDetailView(title: "Appearance") {
            SettingsCard {
                Toggle(isOn: $isDarkModeEnabled) {
                    Label("Dark Mode", systemImage: "moon.fill")
                }
            }
        }
    }
}
