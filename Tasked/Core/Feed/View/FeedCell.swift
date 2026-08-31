//
//  FeedCell.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//  Updated (Feed engagement pass): tapping the profile row now navigates to that
//  user's profile (requires a `.navigationDestination(for: User.self)` somewhere
//  up the enclosing NavigationStack — already added to FeedView and PostFeedView).
//  Added a like button (optimistic toggling via FeedCellViewModel) and a comment
//  button/link that opens CommentsView.
//

import SwiftUI
import Kingfisher

struct FeedCell: View {
    @StateObject private var viewModel: FeedCellViewModel
    @State private var showComments = false

    init(post: Post) {
        self._viewModel = StateObject(wrappedValue: FeedCellViewModel(post: post))
    }

    private var post: Post { viewModel.post }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            if let user = post.user {
                NavigationLink(value: user) {
                    HStack {
                        CircularProfileImageView(user: user, size: .xSmall)

                        Text(user.username)
                            .font(.footnote)
                            .fontWeight(.semibold)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .padding(.leading, 8)
                .padding(.bottom, 4)
            }

            KFImage(URL(string: post.imageUrl))
                .resizable()
                .scaledToFill()
                .frame(height: 400)
                .clipShape(Rectangle())

            HStack(spacing: 16) {
                Button {
                    viewModel.toggleLike()
                } label: {
                    Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(viewModel.isLiked ? .red : .primary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)

                Button {
                    showComments = true
                } label: {
                    Image(systemName: "bubble.right")
                        .foregroundStyle(.primary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            if post.likes > 0 {
                Text("\(post.likes) like\(post.likes == 1 ? "" : "s")")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
            }

            HStack {
                Text("\(post.user?.username ?? "") ").fontWeight(.semibold) +
                Text(post.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.footnote)
            .padding(.leading, 10)
            .padding(.top, 4)

            if post.commentsCount > 0 {
                Button {
                    showComments = true
                } label: {
                    Text("View all \(post.commentsCount) comment\(post.commentsCount == 1 ? "" : "s")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
                .padding(.top, 2)
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
        }
    }
}


#Preview {
    NavigationStack {
        FeedCell(post: Post.MOCK_POSTS[0])
    }
}
