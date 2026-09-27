//
//  MonthPostsView.swift
//  Tasked
//
//  New (Month-detail pass): shown when a month's report card is tapped from
//  PostGridView. Plain scrollable stack of FeedCell at the same 14pt
//  spacing FeedView uses.
//  Updated (Block user pass): added onBlock, removing every post by the
//  blocked user from this local array (same shape as PostFeedView).
//

import SwiftUI

struct MonthPostsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var posts: [Post]
    private let monthTitle: String

    init(month: MonthGroup) {
        self._posts = State(initialValue: month.posts)
        self.monthTitle = month.monthName.capitalized
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(posts) { post in
                        FeedCell(post: post, onDelete: { deletedPost in
                            posts.removeAll { $0.id == deletedPost.id }
                        }, onBlock: { blockedUser in
                            posts.removeAll { $0.ownerUid == blockedUser.id }
                        })
                    }
                }
                .padding(.top, 16)
            }
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationDestination(for: User.self) { user in
                ProfileView(user: user)
            }
        }
        .onChange(of: posts.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }
}

#Preview {
    MonthPostsView(month: MonthGroup(year: 2026, month: 3, posts: Post.MOCK_POSTS))
}
