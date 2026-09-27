//
//  PostOptionsMenu.swift
//  Tasked
//
//  Shared "..." menu shown on every post. Shows "Delete Post" when the
//  signed-in user owns the post, or "Report Post" + "Block User" otherwise.
//  Updated (Size-match pass): ellipsis glyph brought down to 20pt to match
//  FeedCell's heart/comment/share icon size exactly.
//  Updated (Block user pass): added onBlock, offered alongside Report on
//  anyone else's post.
//

import SwiftUI

struct PostOptionsMenu: View {
    let isOwnPost: Bool
    let onDelete: () -> Void
    let onReport: (ReportReason) -> Void
    let onBlock: () -> Void

    var body: some View {
        Menu {
            if isOwnPost {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Post", systemImage: "trash")
                }
            } else {
                Menu {
                    ForEach(ReportReason.allCases) { reason in
                        Button {
                            onReport(reason)
                        } label: {
                            Text(reason.title)
                        }
                    }
                } label: {
                    Label("Report Post", systemImage: "flag")
                }

                Button(role: .destructive) {
                    onBlock()
                } label: {
                    Label("Block User", systemImage: "hand.raised")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(.systemGray))
                .contentShape(Rectangle())
                .padding(8) // enlarges the tap target without shifting the glyph itself
        }
        // Pulls the enlarged tap target's own padding back in, so the glyph
        // (not the invisible tap area) is what actually sits flush on the edge.
        .padding(-8)
    }
}

#Preview {
    VStack(spacing: 20) {
        PostOptionsMenu(isOwnPost: true, onDelete: {}, onReport: { _ in }, onBlock: {})
        PostOptionsMenu(isOwnPost: false, onDelete: {}, onReport: { _ in }, onBlock: {})
    }
}
