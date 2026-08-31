//
//  SettingsView.swift
//  Tasked
//
//  Updated (Feature 5): "Edit Profile" and "Change Profile Picture" used to both
//  push the same combined screen. They're now two distinct destinations backed
//  by two distinct view models, and this is the only place either is reachable
//  from (the profile page no longer has its own Edit Profile button).
//
//  Updated: added an "Account" section for changing password and deleting the
//  account, backed by a new SettingsViewModel.
//

import SwiftUI

struct SettingsView: View {
    let user: User
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showDeleteConfirmation = false

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

            Section("Account") {
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    Label("Change Password", systemImage: "lock.rotation")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    if viewModel.isDeletingAccount {
                        ProgressView()
                    } else {
                        Label("Delete Account", systemImage: "trash")
                    }
                }
                .disabled(viewModel.isDeletingAccount)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                HStack {
                    Label("Notification Settings", systemImage: "bell.badge")
                    Spacer()
                    Text("Coming soon").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Label("Privacy Settings", systemImage: "lock")
                    Spacer()
                    Text("Coming soon").font(.caption).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your profile. This can't be undone.")
        }
    }
}

#Preview {
    NavigationStack { SettingsView(user: User.MOCK_USERS[0]) }
}
