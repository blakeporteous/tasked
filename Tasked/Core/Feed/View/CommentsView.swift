//
//  CommentsView.swift
//  Tasked
//
//  New (Feed engagement pass): sheet presented from FeedCell's comment button.
//  Updated (Edit comment pass): a comment you own can be swiped to reveal an
//  Edit action.
//  Updated (Delete comment pass): a Delete action sits alongside Edit.
//  Updated (Row polish pass): hid List's default row separator.
//  Updated (Comment-count sync pass): onCommentCountChange fires whenever
//  viewModel.comments.count changes.
//  Updated (Comment likes + replies pass): CommentRow now shows a heart +
//  like count (tap to toggle) and a "Reply" action under the text, plus the
//  comment's timeAgo next to the username. Replies render indented directly
//  under their top-level comment; tapping Reply on ANY row (top-level or
//  reply) opens one inline composer under that thread, matching
//  viewModel.startReplying(to:)'s "always threads to the top-level parent"
//  behavior.
//

import SwiftUI

struct CommentsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: CommentsViewModel

    var onCommentCountChange: ((Int) -> Void)? = nil

    init(post: Post, onCommentCountChange: ((Int) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: CommentsViewModel(post: post))
        self.onCommentCountChange = onCommentCountChange
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
                } else if viewModel.topLevelComments.isEmpty {
                    Text("No comments yet. Be the first!")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.topLevelComments) { comment in
                            Group {
                                CommentRow(comment: comment, post: viewModel.post, viewModel: viewModel)
                                    .opacity(viewModel.deletingCommentId == comment.id ? 0.4 : 1)

                                ForEach(viewModel.replies(for: comment)) { reply in
                                    CommentRow(comment: reply, post: viewModel.post, viewModel: viewModel)
                                        .padding(.leading, 32)
                                        .opacity(viewModel.deletingCommentId == reply.id ? 0.4 : 1)
                                }

                                if viewModel.replyingToCommentId == comment.id {
                                    replyComposer
                                        .padding(.leading, 32)
                                }
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }

                if let errorMessage = viewModel.errorMessage, !viewModel.comments.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                Divider()

                HStack {
                    // Deliberately NOT IGTextFieldModifier — that's the heavy
                    // square "ink block" chrome built for full-screen auth
                    // fields (3pt black outline + hard offset shadow), which
                    // reads as an oversized square block crammed into a
                    // one-line comment bar. A plain rounded capsule field
                    // fits the context instead, and Color(.systemGray6)
                    // adapts automatically in dark mode.
                    TextField("Add a comment...", text: $viewModel.newCommentText)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())

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
            .confirmationDialog(
                "Delete this comment?",
                isPresented: Binding(
                    get: { viewModel.commentPendingDeletion != nil },
                    set: { if !$0 { viewModel.commentPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let comment = viewModel.commentPendingDeletion {
                        Task { await viewModel.deleteComment(comment) }
                    }
                    viewModel.commentPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    viewModel.commentPendingDeletion = nil
                }
            } message: {
                Text("This can't be undone.")
            }
            .task {
                await viewModel.fetchComments()
            }
            .onChange(of: viewModel.comments.count) { _, newCount in
                onCommentCountChange?(newCount)
            }
        }
    }

    /// Inline "write a reply" row shown under whichever comment thread is
    /// currently being replied to.
    private var replyComposer: some View {
        HStack {
            TextField("Write a reply...", text: $viewModel.replyText)
                .font(.footnote)

            Button {
                Task { await viewModel.postReply() }
            } label: {
                if viewModel.isPostingReply {
                    ProgressView()
                } else {
                    Text("Post")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
            }
            .disabled(viewModel.replyText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isPostingReply)

            Button {
                viewModel.cancelReplying()
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
            .disabled(viewModel.isPostingReply)
        }
        .padding(.vertical, 4)
    }
}

/// One comment (or reply) row.
private struct CommentRow: View {
    let comment: Comment
    let post: Post
    @ObservedObject var viewModel: CommentsViewModel

    private var liveProfile: User? {
        viewModel.commenterProfiles[comment.ownerUid]
    }

    private var displayUsername: String {
        liveProfile?.username ?? comment.username
    }

    private var displayImageUrl: String? {
        liveProfile?.profileImageUrl ?? comment.profileImageUrl
    }

    private var isOwnComment: Bool {
        comment.ownerUid == AuthService.shared.currentUser?.id
    }

    private var canDelete: Bool {
        isOwnComment || post.ownerUid == AuthService.shared.currentUser?.id
    }

    private var isEditing: Bool {
        viewModel.editingCommentId == comment.id
    }

    private var isLiked: Bool {
        comment.isLiked(by: AuthService.shared.currentUser?.id)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let url = comment.profileImageUrl {
                CircularProfileImageView(
                    user: User(id: comment.ownerUid, username: comment.username, profileImageUrl: url, email: ""),
                    size: .xSmall
                )
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .clipShape(Rectangle())
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayUsername)
                        .font(.footnote)
                        .fontWeight(.semibold)

                    Text(comment.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if isEditing {
                    HStack(spacing: 8) {
                        TextField("Edit comment", text: $viewModel.editText)
                            .font(.footnote)

                        Button {
                            Task { await viewModel.saveEdit() }
                        } label: {
                            if viewModel.isSavingEdit {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        .disabled(viewModel.editText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSavingEdit)

                        Button {
                            viewModel.cancelEditing()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .disabled(viewModel.isSavingEdit)
                    }
                } else {
                    HStack(spacing: 4) {
                        Text(comment.text)
                            .font(.footnote)
                        if comment.isEdited {
                            Text("(edited)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 14) {
                        Button {
                            viewModel.toggleLike(comment)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.caption)
                                    .foregroundStyle(isLiked ? .red : Color(.systemGray))
                                if comment.likes > 0 {
                                    Text("\(comment.likes)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.startReplying(to: comment)
                        } label: {
                            Text("Reply")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            if !isEditing {
                if canDelete {
                    Button(role: .destructive) {
                        viewModel.commentPendingDeletion = comment
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                if isOwnComment {
                    Button {
                        viewModel.startEditing(comment)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(Color.appAccent)
                }
            }
        }
    }
}

#Preview {
    CommentsView(post: Post.MOCK_POSTS[0])
}
