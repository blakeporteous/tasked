//
//  FeedCellViewModel.swift
//  Tasked
//
//  New (Feed engagement pass): backs the like button on FeedCell. Owns just
//  enough per-cell state (liked state + optimistic count) so tapping like feels
//  instant while the Firestore transaction runs in the background.
//

import Foundation

@MainActor
class FeedCellViewModel: ObservableObject {
    @Published var post: Post
    @Published var isLiking = false

    private let currentUserId: String?

    init(post: Post) {
        self.post = post
        self.currentUserId = AuthService.shared.currentUser?.id
    }

    var isLiked: Bool {
        post.isLiked(by: currentUserId)
    }

    /// Optimistically flips the like state locally, then reconciles with the
    /// server. If the write fails, the local state is rolled back.
    func toggleLike() {
        guard let currentUser = AuthService.shared.currentUser, !isLiking else { return }

        let originalPost = post
        let wasLiked = isLiked

        if wasLiked {
            post.likedBy.removeAll { $0 == currentUser.id }
            post.likes = max(0, post.likes - 1)
        } else {
            post.likedBy.append(currentUser.id)
            post.likes += 1
        }

        Task {
            isLiking = true
            defer { isLiking = false }
            do {
                _ = try await PostService.toggleLike(post: originalPost, currentUser: currentUser)
            } catch {
                // Roll back on failure — the optimistic flip didn't stick.
                post = originalPost
            }
        }
    }
}
