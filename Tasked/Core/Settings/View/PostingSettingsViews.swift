//
//  PostingSettingsViews.swift
//  Tasked
//
//  New (Settings revamp pass): backs the new "Posting" settings group.
//  Neither screen is wired to a real backend field yet (Post.swift/
//  User.swift have no matching properties) — both hold their state locally
//  as a UI placeholder, same "affordance now, wiring later" pattern already
//  used elsewhere in this app (e.g. PostGridView's calendar icon,
//  MonthCard's "..." menu).
//

import SwiftUI

struct CommentsSettingsView: View {
    @State private var showCommentCount = true
    @State private var commentsEnabled = true
    @State private var restrictedWords = ""

    var body: some View {
        SettingsDetailView(title: "Comments") {
            SettingsCard {
                SettingsToggleRow(
                    title: "Show comment count",
                    subtitle: "Hide the number next to the comment icon on your posts.",
                    isOn: $showCommentCount
                )
                Divider()
                SettingsToggleRow(
                    title: "Allow comments",
                    subtitle: "Turn this off to stop anyone from commenting on your posts.",
                    isOn: $commentsEnabled
                )
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Restricted words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Comma-separated words to hide, e.g. spam, rude", text: $restrictedWords, axis: .vertical)
                        .lineLimit(2...4)
                    Text("Comments containing these words will be hidden automatically.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct LikesSettingsView: View {
    @State private var showLikeCount = true

    var body: some View {
        SettingsDetailView(title: "Likes") {
            SettingsCard {
                SettingsToggleRow(
                    title: "Show like count",
                    subtitle: "Hide the number next to the heart icon on your posts.",
                    isOn: $showLikeCount
                )
            }
        }
    }
}
