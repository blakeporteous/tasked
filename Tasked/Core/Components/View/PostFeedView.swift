//
//  PostFeedView.swift
//  Tasked
//
//  New in Feature 2. Full-screen, vertically-paged feed of one user's posts.
//  Updated (Feed engagement pass): FeedCell's profile row can navigate to a
//  profile now, so this stack needs its own destination for User too.
//  Updated (Post deletion): posts is now @State — FeedCell's onDelete
//  callback removes a deleted post from this local array directly.
//  Updated (Scroll-to-post fix, take 2): eager VStack + ScrollViewReader so
//  proxy.scrollTo(startIndex) has real geometry to jump to.
//  Updated (Block user pass): FeedCell's onBlock callback removes every
//  post by the blocked user from this local array — same "local array +
//  eventual listener catch-up" pattern as onDelete.
//

import SwiftUI

struct PostFeedView: View {
    @Environment(\.dismiss) var dismiss
    @State private var posts: [Post]
    private let startIndex: Int

    init(posts: [Post], startIndex: Int) {
        self._posts = State(initialValue: posts)
        self.startIndex = startIndex
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            FeedCell(post: post, onDelete: { deletedPost in
                                posts.removeAll { $0.id == deletedPost.id }
                            }, onBlock: { blockedUser in
                                posts.removeAll { $0.ownerUid == blockedUser.id }
                            })
                            .containerRelativeFrame(.vertical)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
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
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo(startIndex, anchor: .top)
                    }
                }
            }
        }
        .onChange(of: posts.isEmpty) { _, isEmpty in
            if isEmpty {
                dismiss()
            }
        }
    }
}

#Preview {
    PostFeedView(posts: Post.MOCK_POSTS, startIndex: 1)
}
