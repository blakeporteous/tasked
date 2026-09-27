//
//  SettingsView.swift
//  Tasked
//
//  Updated (Settings revamp pass): fully re-organized into grouped sections
//  — Profile, Appearance, Posting, Account, Personal Information, Privacy,
//  Notifications, Support. Every row is a NavigationLink to its own detail
//  screen built from the shared SettingsDetailView/SettingsCard template.
//  Updated (Deactivate/Delete as pages pass): both now push to their own
//  toggle-based pages (DeactivateAccountView/DeleteAccountView) instead of
//  being direct buttons with an inline confirmationDialog/alert here — the
//  confirmation UI moved with them, so SettingsView no longer owns
//  showDeleteConfirmation/showDeactivateConfirmation at all.
//

import SwiftUI

struct SettingsView: View {
    let user: User
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        List {
            Section("Profile") {
                NavigationLink {
                    EditProfileView(user: user)
                } label: {
                    Label("Edit Profile", systemImage: "person.crop.circle")
                }
                NavigationLink {
                    EditProfilePictureView(user: user)
                } label: {
                    Label("Change Profile Picture", systemImage: "camera")
                }
            }

            Section("Appearance") {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label("Dark Mode", systemImage: "moon.fill")
                }
            }

            Section("Posting") {
                NavigationLink {
                    CommentsSettingsView()
                } label: {
                    Label("Comments", systemImage: "ellipsis.bubble")
                }
                NavigationLink {
                    LikesSettingsView()
                } label: {
                    Label("Likes", systemImage: "heart")
                }
            }

            Section("Account") {
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    Label("Change Password", systemImage: "lock.rotation")
                }
                NavigationLink {
                    SettingsPlaceholderView(
                        title: "Two-Factor Authentication",
                        icon: "lock.shield",
                        message: "Two-factor authentication isn't available yet — we're working on it."
                    )
                } label: {
                    Label("Two-Factor Authentication", systemImage: "lock.shield")
                }
                NavigationLink {
                    DeactivateAccountView(viewModel: viewModel)
                } label: {
                    Label("Deactivate Account", systemImage: "pause.circle")
                }
                NavigationLink {
                    DeleteAccountView(viewModel: viewModel)
                } label: {
                    Label("Delete Account", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }

            Section("Personal Information") {
                NavigationLink {
                    DateOfBirthSettingsView()
                } label: {
                    Label("Date of Birth", systemImage: "calendar")
                }
                NavigationLink {
                    GenderSettingsView()
                } label: {
                    Label("Gender", systemImage: "person.2")
                }
                NavigationLink {
                    CountryRegionSettingsView()
                } label: {
                    Label("Country/Region", systemImage: "globe")
                }
                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    Label("Language", systemImage: "character.bubble")
                }
            }

            Section("Privacy") {
                NavigationLink {
                    AccountPrivacyView(viewModel: viewModel)
                } label: {
                    Label("Account Privacy", systemImage: "eye")
                }
                NavigationLink {
                    SettingsPlaceholderView(
                        title: "Privacy Policy",
                        icon: "doc.text",
                        message: "Our full privacy policy will be linked here."
                    )
                } label: {
                    Label("Privacy Policy", systemImage: "doc.text")
                }
                NavigationLink {
                    BlockedUsersView()
                } label: {
                    Label("Blocked Accounts", systemImage: "hand.raised.slash")
                }
                NavigationLink {
                    PersonalizedAdsSettingsView()
                } label: {
                    Label("Personalised Ads", systemImage: "megaphone")
                }
            }

            Section("Notifications") {
                NavigationLink {
                    EmailNotificationsSettingsView()
                } label: {
                    Label("Email Notifications", systemImage: "envelope")
                }
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("Push Notifications", systemImage: "bell.badge")
                }
            }

            Section {
                NavigationLink {
                    SettingsPlaceholderView(
                        title: "Report a Bug",
                        icon: "ladybug",
                        message: "Bug reporting isn't wired up yet — for now, reach out to support directly."
                    )
                } label: {
                    Label("Report a Bug", systemImage: "ladybug")
                }
                NavigationLink {
                    SettingsPlaceholderView(
                        title: "Help Center",
                        icon: "questionmark.circle",
                        message: "Our help center articles will live here."
                    )
                } label: {
                    Label("Help Center", systemImage: "questionmark.circle")
                }
                NavigationLink {
                    SettingsPlaceholderView(
                        title: "Terms of Service",
                        icon: "doc.plaintext",
                        message: "Our full terms of service will be linked here."
                    )
                } label: {
                    Label("Terms of Service", systemImage: "doc.plaintext")
                }
            } header: {
                Text("Support")
            } footer: {
                Text("© 2026 Tasked")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView(user: User.MOCK_USERS[0]) }
}
