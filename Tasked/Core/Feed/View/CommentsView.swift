//
//  CommentsView.swift
//  Tasked
//
//  New (Feed engagement pass): sheet presented from FeedCell's comment button
//  and "View all comments" link.
//

import SwiftUI

struct CommentsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: CommentsViewModel

    init(post: Post) {
        self._viewModel = StateObject(wrappedValue: CommentsViewModel(post: post))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage, viewModel.comments.isEmpty {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await viewModel.fetchComments() }
                        }
                        .font(.footnote)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                    Spacer()
                } else if viewModel.comments.isEmpty {
                    Text("No comments yet. Be the first!")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                    Spacer()
                } else {
                    List(viewModel.comments) { comment in
                        HStack(alignment: .top, spacing: 10) {
                            if let url = comment.profileImageUrl {
                                CircularProfileImageView(
                                    user: User(id: comment.ownerUid, username: comment.username, profileImageUrl: url, email: ""),
                                    size: .xSmall
                                )
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(comment.username)
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                Text(comment.text)
                                    .font(.footnote)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.plain)
                }

                Divider()

                HStack {
                    TextField("Add a comment...", text: $viewModel.newCommentText)
                        .modifier(IGTextFieldModifier())

                    Button {
                        Task { await viewModel.postComment() }
                    } label: {
                        if viewModel.isPosting {
                            ProgressView()
                        } else {
                            Text("Post")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.newCommentText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isPosting)
                    .padding(.trailing, 16)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await viewModel.fetchComments()
            }
        }
    }
}

#Preview {
    CommentsView(post: Post.MOCK_POSTS[0])
}
