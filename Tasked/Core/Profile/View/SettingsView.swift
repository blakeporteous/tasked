//
//  SettingsView.swift
//  Tasked
//
//  Updated (Feature 5): "Edit Profile" and "Change Profile Picture" used to both
//  push the same combined screen. They're now two distinct destinations backed
//  by two distinct view models, and this is the only place either is reachable
//  from (the profile page no longer has its own Edit Profile button).
//

import SwiftUI

struct SettingsView: View {
    let user: User

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
    }
}

#Preview {
    NavigationStack { SettingsView(user: User.MOCK_USERS[0]) }
}
