//
//  PostGridViewModel.swift
//  Tasked
//
//  Created by Blake Porteous on 13/08/2025.
//  Updated (Post deletion): added deletePost(_:), which calls
//  PostService.deletePost and removes the post from the grid locally on
//  success. deletingPostId lets the view dim the specific cell being deleted;
//  errorMessage surfaces a failure without crashing the flow.
//  Updated (Reporting): added reportPost(_:reason:) for grids that aren't the
//  signed-in user's own (i.e. viewing a friend's profile).
//  Updated: subscribes to AuthService.shared.$currentUser (mirrors
//  ProfileHeaderViewModel's fix) so that if this grid belongs to the signed-in
//  user and they edit their profile picture/username elsewhere, every post's
//  denormalized `user` stamp updates in place. Without this, a post tapped
//  into PostFeedView could show a stale avatar/username until relaunch.
//  Updated (Live posts pass): swapped the one-shot fetchUserPosts() for
//  PostService.listenToUserPosts, a real-time listener. Previously, a post
//  created via UploadPostView, or deleted from FeedCell/PostFeedView
//  elsewhere in the app, never appeared/disappeared on the profile grid
//  until the app relaunched — MainTabView keeps CurrentUserProfileView alive
//  across tab switches, so this screen was never naturally recreated to pick
//  up a fresh fetch. deletePost(_:) no longer removes the post locally on
//  success; the listener now does that automatically (and does so almost
//  instantly thanks to Firestore's local-write latency compensation).
//  Updated (Empty-state pass): added isLoading, starting true and flipping
//  false on the listener's first snapshot (success OR failure) — lets
//  PostGridView show a spinner while the very first fetch is in flight,
//  rather than briefly flashing "No posts yet" before real data arrives.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class PostGridViewModel: ObservableObject {
    private let user: User
    @Published var posts = [Post]()
    @Published var isLoading = true
    @Published var deletingPostId: String?
    @Published var errorMessage: String?
    
    /// `posts` grouped into one MonthGroup per calendar month that actually
    /// has a post — a month with nothing posted just never appears, rather
    /// than showing an empty card. Newest month first; posts within each
    /// month are also newest first.
    var monthGroups: [MonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: posts) { post in
            calendar.dateComponents([.year, .month], from: post.timestamp.dateValue())
        }

        return grouped.compactMap { key, posts -> MonthGroup? in
            guard let year = key.year, let month = key.month else { return nil }
            let sorted = posts.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
            return MonthGroup(year: year, month: month, posts: sorted)
        }
        .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
    }

    private var cancellables = Set<AnyCancellable>()
    private var postsListener: ListenerRegistration?

    init(user: User){
        self.user = user

        startListeningToPosts()

        AuthService.shared.$currentUser
            .compactMap { $0 }
            .filter { [user] updatedUser in updatedUser.id == user.id }
            .sink { [weak self] updatedUser in
                guard let self else { return }
                for i in self.posts.indices {
                    self.posts[i].user = updatedUser
                }
            }
            .store(in: &cancellables)
    }

    /// Live-updates `posts` from Firestore. Creates and deletes made
    /// anywhere else in the app (upload, FeedCell, PostFeedView, another of
    /// this same user's own posts elsewhere) are reflected here automatically.
    private func startListeningToPosts() {
        postsListener?.remove()
        postsListener = PostService.listenToUserPosts(uid: user.id) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(var posts):
                for i in posts.indices {
                    posts[i].user = self.user
                }
                self.posts = posts
            case .failure(let error):
                self.errorMessage = "Couldn't load posts: \(error.localizedDescription)"
            }
        }
    }

    /// Deletes `post`. No local array mutation needed on success — the live
    /// listener started above removes it from `posts` on its own as soon as
    /// the delete commits.
    func deletePost(_ post: Post) async {
        deletingPostId = post.id
        errorMessage = nil
        defer { deletingPostId = nil }

        do {
            try await PostService.deletePost(post)
        } catch {
            errorMessage = "Couldn't delete post: \(error.localizedDescription)"
        }
    }

    /// Files a report against `post`. No-op if this is the signed-in user's
    /// own grid — the view never actually offers Report there, but this guard
    /// keeps the view model safe to call regardless.
    func reportPost(_ post: Post, reason: ReportReason) async {
        guard !user.isCurrentUser, let currentUser = AuthService.shared.currentUser else { return }
        errorMessage = nil

        do {
            try await ReportService.report(post: post, reason: reason, currentUser: currentUser)
        } catch {
            errorMessage = "Couldn't submit report: \(error.localizedDescription)"
        }
    }

    deinit {
        postsListener?.remove()
    }
    
    
}
