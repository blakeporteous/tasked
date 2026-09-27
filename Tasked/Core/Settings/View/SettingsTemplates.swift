//
//  SettingsTemplates.swift
//  Tasked
//
//  New (Settings revamp pass): shared template every individual settings
//  screen is built from, so tapping any row in SettingsView pushes to a
//  visually-consistent detail page instead of each screen hand-rolling its
//  own ScrollView/background/card chrome. Mirrors the ScrollView + gray6
//  card + systemGroupedBackground pattern EditProfileView/ChangePasswordView
//  already used — this just factors it out so every new settings screen
//  (Appearance, Posting, Personal Information, Privacy, etc.) gets it for
//  free instead of copy-pasting it again.
//

import SwiftUI

/// The standard shell for a settings detail screen: a scrollable, left-
/// aligned stack of sections on a grouped background, with an inline nav
/// title. Drop any mix of SettingsCard blocks (and plain text) in as
/// `content`.
struct SettingsDetailView<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The standard "card" a settings screen's controls sit inside — same
/// Color(.systemGray6) rounded rect EditProfileView/ChangePasswordView
/// already use for their field groups.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// One labeled toggle row with an optional footnote underneath explaining
/// what it does — the most common control a settings screen needs.
struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: $isOn)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Generic "not built yet" detail screen — used for every settings row that
/// doesn't have real functionality behind it (Two-Factor Authentication,
/// Privacy Policy, Personalised Ads placeholders' siblings, Support links,
/// etc.). Keeps every placeholder visually consistent with the real screens
/// rather than each one being its own one-off "Coming soon" layout.
struct SettingsPlaceholderView: View {
    let title: String
    var icon: String = "gearshape"
    var message: String = "This setting isn't available yet — check back in a future update."

    var body: some View {
        SettingsDetailView(title: title) {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.appAccent)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
            .padding(.horizontal, 8)
        }
    }
}
