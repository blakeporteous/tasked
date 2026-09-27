//
//  CommentsViewModel.swift
//  Tasked
//
//  New (Feed engagement pass): backs CommentsView.
//  Updated (Edit comment pass): added editingCommentId/editText to drive an
//  inline edit row, and saveEdit(), which calls PostService.editComment and
//  updates the local comments array in place on success.
//  Updated (Delete comment pass): added commentPendingDeletion and
//  deleteComment(_:), which calls PostService.deleteComment and removes the
//  row locally on success.
//  Updated (Live commenter-profile pass): added commenterProfiles, a
//  batched uid -> current User lookup so a username change shows up on
//  past comments too, not just new ones.
//  Updated (Comment likes + replies pass): comments is now a flat array
//  containing BOTH top-level comments and replies (replies are flagged via
//  parentCommentId) — topLevelComments/replies(for:) split them for the
//  view. Added toggleLike(_:) (optimistic, same rollback pattern as
//  FeedCellViewModel.toggleLike), and reply state
//  (replyingToCommentId/replyText/isPostingReply) + postReply()/
//  startReplying(to:)/cancelReplying(). Replying to a REPLY still threads
//  under its top-level ancestor (one level of nesting, matching most social
//  apps) rather than creating reply-of-a-reply chains.
//

import Foundation

@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var newCommentText = ""
    @Published var isLoading = false
    @Published var isPosting = false
    @Published var errorMessage: String?

    @Published var editingCommentId: String?
    @Published var editText: String = ""
    @Published var isSavingEdit = false

    @Published var commentPendingDeletion: Comment?
    @Published var deletingCommentId: String?

    /// The top-level comment currently being replied to (nil = no reply
    /// composer showing anywhere). Always a TOP-LEVEL comment's id, even
    /// when the person tapped "Reply" on a reply — see startReplying(to:).
    @Published var replyingToCommentId: String?
    @Published var replyText: String = ""
    @Published var isPostingReply = false

    @Published var commenterProfiles: [String: User] = [:]

    let post: Post

    init(post: Post) {
        self.post = post
    }

    /// Just the top-level comments, newest first (comments is already
    /// sorted that way by fetchComments' query) — replies are excluded here
    /// and rendered separately via replies(for:).
    var topLevelComments: [Comment] {
        comments.filter { $0.parentCommentId == nil }
    }

    /// Replies to `comment`, oldest first (reads more naturally as a
    /// conversation than newest-first would).
    func replies(for comment: Comment) -> [Comment] {
        comments
            .filter { $0.parentCommentId == comment.id }
            .sorted { $0.timestamp.dateValue() < $1.timestamp.dateValue() }
    }

    func fetchComments() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            comments = try await PostService.fetchComments(postId: post.id)
            await hydrateCommenterProfiles(for: comments)
        } catch {
            errorMessage = "Couldn't load comments: \(error.localizedDescription)"
        }
    }

    private func hydrateCommenterProfiles(for comments: [Comment]) async {
        let uidsToFetch = Array(Set(comments.map(\.ownerUid))).filter { commenterProfiles[$0] == nil }
        guard !uidsToFetch.isEmpty else { return }

        if let fetchedUsers = try? await UserService.fetchUsers(withUids: uidsToFetch) {
            for user in fetchedUsers {
                commenterProfiles[user.id] = user
            }
        }
    }

    func postComment() async {
        guard let currentUser = AuthService.shared.currentUser else { return }
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            let comment = try await PostService.addComment(to: post, text: trimmed, currentUser: currentUser)
            comments.insert(comment, at: 0)
            commenterProfiles[currentUser.id] = currentUser
            newCommentText = ""
        } catch {
            errorMessage = "Couldn't post your comment: \(error.localizedDescription)"
        }
    }

    func startEditing(_ comment: Comment) {
        editingCommentId = comment.id
        editText = comment.text
    }

    func cancelEditing() {
        editingCommentId = nil
        editText = ""
    }

    func saveEdit() async {
        guard let commentId = editingCommentId else { return }
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSavingEdit = true
        errorMessage = nil
        defer { isSavingEdit = false }

        do {
            try await PostService.editComment(postId: post.id, commentId: commentId, newText: trimmed)
            if let index = comments.firstIndex(where: { $0.id == commentId }) {
                comments[index].text = trimmed
                comments[index].isEdited = true
            }
            editingCommentId = nil
            editText = ""
        } catch {
            errorMessage = "Couldn't save your edit: \(error.localizedDescription)"
        }
    }

    func deleteComment(_ comment: Comment) async {
        deletingCommentId = comment.id
        errorMessage = nil
        defer { deletingCommentId = nil }

        do {
            try await PostService.deleteComment(postId: post.id, commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
        } catch {
            errorMessage = "Couldn't delete comment: \(error.localizedDescription)"
        }
    }

    // MARK: - Likes

    /// Optimistically flips the like state on `comment` (or a reply) and
    /// reconciles with the server, rolling back on failure — same pattern
    /// as FeedCellViewModel.toggleLike.
    func toggleLike(_ comment: Comment) {
        guard let currentUser = AuthService.shared.currentUser else { return }
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }

        let original = comments[index]
        let wasLiked = original.isLiked(by: currentUser.id)

        if wasLiked {
            comments[index].likedBy.removeAll { $0 == currentUser.id }
            comments[index].likes = max(0, comments[index].likes - 1)
        } else {
            comments[index].likedBy.append(currentUser.id)
            comments[index].likes += 1
        }

        Task {
            do {
                _ = try await PostService.toggleCommentLike(postId: post.id, commentId: comment.id, currentUser: currentUser)
            } catch {
                if let rollbackIndex = comments.firstIndex(where: { $0.id == comment.id }) {
                    comments[rollbackIndex] = original
                }
            }
        }
    }

    // MARK: - Replies

    /// Opens the reply composer for `comment`'s thread. If `comment` is
    /// itself a reply, threads under its TOP-LEVEL parent instead — keeps
    /// the UI to one level of nesting rather than reply-of-a-reply chains.
    func startReplying(to comment: Comment) {
        replyingToCommentId = comment.parentCommentId ?? comment.id
        replyText = ""
    }

    func cancelReplying() {
        replyingToCommentId = nil
        replyText = ""
    }

    func postReply() async {
        guard let parentId = replyingToCommentId, let currentUser = AuthService.shared.currentUser else { return }
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isPostingReply = true
        errorMessage = nil
        defer { isPostingReply = false }

        do {
            let reply = try await PostService.addComment(to: post, text: trimmed, currentUser: currentUser, parentCommentId: parentId)
            comments.append(reply)
            commenterProfiles[currentUser.id] = currentUser
            replyingToCommentId = nil
            replyText = ""
        } catch {
            errorMessage = "Couldn't post your reply: \(error.localizedDescription)"
        }
    }
}
