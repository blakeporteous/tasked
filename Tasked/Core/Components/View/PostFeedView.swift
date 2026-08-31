//
//  PostFeedView.swift
//  Tasked
//
//  New in Feature 2. Full-screen, vertically-paged feed of one user's posts,
//  opened from PostGridView at whichever post was tapped. Scrolling forwards and
//  backwards moves through all of that user's posts, matching Instagram's behaviour.
//
//  NOTE: uses scrollPosition/scrollTargetBehavior(.paging), which require iOS 17+.
//  If the project's deployment target is earlier than iOS 17, this will need to be
//  reworked (e.g. a rotated TabView(.page) as a fallback) — see summary notes.
//  Updated (Feed engagement pass): FeedCell's profile row can navigate to a
//  profile now, so this stack needs its own destination for User too (it has its
//  own NavigationStack, separate from FeedView's).
//

import SwiftUI

struct PostFeedView: View {
    @Environment(\.dismiss) var dismiss
    let posts: [Post]
    @State private var currentIndex: Int?

    init(posts: [Post], startIndex: Int) {
        self.posts = posts
        self._currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                        FeedCell(post: post)
                            .containerRelativeFrame(.vertical)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $currentIndex)
            .scrollTargetBehavior(.paging)
            .ignoresSafeArea(edges: .bottom)
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: User.self) { user in
                ProfileView(user: user)
            }
        }
    }
}

#Preview {
    PostFeedView(posts: Post.MOCK_POSTS, startIndex: 1)
}
