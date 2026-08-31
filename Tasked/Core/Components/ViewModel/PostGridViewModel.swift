//
//  PostGridViewModel.swift
//  Tasked
//
//  Created by Blake Porteous on 13/08/2025.
//  Updated (live-refresh pass): `user` used to be captured once at init and
//  stamped onto every fetched post, so editing your bio/name/profile picture
//  didn't show up on your own post grid (or PostFeedView opened from it)
//  until the app was relaunched. Now it subscribes to
//  AuthService.shared.$currentUser and re-stamps every cached post whenever
//  an update comes in for the user this grid belongs to. Marked @MainActor
//  (the class itself, not just fetchUserPosts) so the Combine sink and the
//  posts array mutation it does are always on the main actor, matching
//  @Published's threading requirement.
//

import Foundation
import Combine

@MainActor
class PostGridViewModel: ObservableObject {
    private var user: User
    @Published var posts = [Post]()

    private var cancellables = Set<AnyCancellable>()

    init(user: User){
        self.user = user

        Task { try await fetchUserPosts() }
        observeCurrentUserUpdates()
    }

    func fetchUserPosts() async throws {
        self.posts = try await PostService.fetchUserPosts(uid: user.id)

        for i in 0..<posts.count {
            posts[i].user = self.user
        }
    }

    /// Keeps every cached post's `user` snapshot in sync with
    /// AuthService.shared.currentUser when this grid is showing the
    /// signed-in user's own posts.
    private func observeCurrentUserUpdates() {
        AuthService.shared.$currentUser
            .compactMap { $0 }
            .sink { [weak self] updatedUser in
                guard let self, updatedUser.id == self.user.id else { return }
                self.user = updatedUser
                for i in 0..<self.posts.count {
                    self.posts[i].user = updatedUser
                }
            }
            .store(in: &cancellables)
    }
}
