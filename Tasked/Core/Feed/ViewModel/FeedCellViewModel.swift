//
//  FeedCellViewModel.swift
//  Tasked
//
//  New (Feed engagement pass): backs the like button on FeedCell.
//  Updated (Post deletion + reporting): backs the "..." menu.
//  Updated: deletePost() returns Bool so FeedCell can tell PostFeedView to
//  remove it locally.
//  Updated (Comment-count sync pass): added updateCommentsCount(_:).
//  Updated (Share fix pass): added shareableImage, wrapping whatever's
//  already sitting in Kingfisher's in-memory cache for this post's image so
//  FeedCell's ShareLink can hand the recipient app the actual photo instead
//  of a bare Firebase Storage URL.
//  Updated (Block user pass): added blockUser(), backing PostOptionsMenu's
//  new "Block User" action. Returns the blocked User on success so FeedCell
//  can tell its caller (FeedView/PostFeedView/MonthPostsView) to drop their
//  posts from whatever local array it's holding immediately, rather than
//  waiting for the feed's friend-list listener to notice and re-scope.
//

import Foundation
import Kingfisher

@MainActor
class FeedCellViewModel: ObservableObject {
    @Published var post: Post
    @Published var isLiking = false
    @Published var isDeleting = false
    @Published var isBlocking = false
    @Published var errorMessage: String?
    @Published var reportConfirmationMessage: String?

    private let currentUserId: String?

    init(post: Post) {
        self.post = post
        self.currentUserId = AuthService.shared.currentUser?.id
    }

    var isLiked: Bool {
        post.isLiked(by: currentUserId)
    }

    var isOwnPost: Bool {
        currentUserId == post.ownerUid
    }

    /// The image this cell is already showing, pulled straight out of
    /// Kingfisher's in-memory cache (no extra network fetch) and wrapped
    /// for ShareLink. nil if it hasn't finished loading into cache yet —
    /// FeedCell falls back to sharing the raw URL in that case.
    var shareableImage: ShareableImage? {
        guard let cached = ImageCache.default.retrieveImageInMemoryCache(forKey: post.imageUrl) else {
            return nil
        }
        return ShareableImage(image: cached, caption: post.caption)
    }

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
                post = originalPost
            }
        }
    }

    func deletePost() async -> Bool {
        guard isOwnPost, !isDeleting else { return false }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await PostService.deletePost(post)
            return true
        } catch {
            errorMessage = "Couldn't delete post: \(error.localizedDescription)"
            return false
        }
    }

    func updateCommentsCount(_ count: Int) {
        post.commentsCount = count
    }

    func reportPost(reason: ReportReason) async {
        guard !isOwnPost, let currentUser = AuthService.shared.currentUser else { return }
        errorMessage = nil

        do {
            try await ReportService.report(post: post, reason: reason, currentUser: currentUser)
            reportConfirmationMessage = "Thanks — we've received your report and will take a look."
        } catch {
            errorMessage = "Couldn't submit report: \(error.localizedDescription)"
        }
    }

    /// Blocks the post's owner: unfriends both ways, clears any pending
    /// friend request, and adds them to the signed-in user's blockedUids
    /// (BlockService). Returns the blocked User on success.
    func blockUser() async -> User? {
        guard !isOwnPost, !isBlocking, let ownerUser = post.user else { return nil }
        isBlocking = true
        errorMessage = nil
        defer { isBlocking = false }

        do {
            try await BlockService.block(ownerUser.id)
            return ownerUser
        } catch {
            errorMessage = "Couldn't block that user: \(error.localizedDescription)"
            return nil
        }
    }
}
