//
//  NotificationSettingsView.swift
//  Tasked
//
//  New: reachable from Settings > Notification Settings (previously a
//  "Coming soon" row). Three per-type toggles control both the in-app
//  bell/badge and push delivery for that type — see
//  NotificationPreferences.isEnabled(for:). A separate section handles the
//  OS-level push permission itself, since that's a device setting rather
//  than a per-type preference.
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        List {
            Section {
                Toggle("Likes", isOn: $viewModel.preferences.likesEnabled)
                Toggle("Comments", isOn: $viewModel.preferences.commentsEnabled)
                Toggle("Friend requests", isOn: $viewModel.preferences.friendRequestsEnabled)
            } header: {
                Text("Notify me about")
            } footer: {
                Text("Controls both the bell on Home and push alerts on your phone.")
            }
            .onChange(of: viewModel.preferences) { _, _ in
                Task { await viewModel.save() }
            }

            Section("Push Notifications") {
                pushRow
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refreshPushStatus()
        }
    }

    @ViewBuilder
    private var pushRow: some View {
        switch viewModel.pushAuthorizationStatus {
        case .authorized, .provisional:
            Label("Push notifications are on", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .denied:
            VStack(alignment: .leading, spacing: 4) {
                Label("Push notifications are off", systemImage: "bell.slash")
                Text("Turn them on in iOS Settings > Tasked > Notifications.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        default:
            Button {
                viewModel.requestPushPermission()
            } label: {
                Label("Enable push notifications", systemImage: "bell.badge")
            }
        }
    }
}

#Preview {
    NavigationStack { NotificationSettingsView() }
}
