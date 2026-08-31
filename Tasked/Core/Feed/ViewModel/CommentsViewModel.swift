//
//  CommentsViewModel.swift
//  Tasked
//
//  New (Feed engagement pass): backs CommentsView.
//

import Foundation

@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var newCommentText = ""
    @Published var isLoading = false
    @Published var isPosting = false
    @Published var errorMessage: String?

    let post: Post

    init(post: Post) {
        self.post = post
    }

    func fetchComments() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            comments = try await PostService.fetchComments(postId: post.id)
        } catch {
            errorMessage = "Couldn't load comments: \(error.localizedDescription)"
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
            newCommentText = ""
        } catch {
            errorMessage = "Couldn't post your comment: \(error.localizedDescription)"
        }
    }
}
