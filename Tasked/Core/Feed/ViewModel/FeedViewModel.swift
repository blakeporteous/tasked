//
//  FeedViewModel.swift
//  Tasked
//
//  Created by Blake Porteous on 11/08/2025.
//  Updated: also fetches the active weekly task (Feature 4) and scopes posts to
//  friends via PostService.fetchFeedPosts(for:) (Feature 5).
//

import Foundation
import Firebase

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts = [Post]()
    @Published var weeklyTask: WeeklyTask?
    @Published var errorMessage: String?
    @Published var isLoading = false

    init() {
        Task { await fetchPosts() }
        Task { await fetchWeeklyTask() }
    }

    func fetchPosts() async {
        guard let currentUser = AuthService.shared.currentUser else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            self.posts = try await PostService.fetchFeedPosts(for: currentUser)
        } catch {
            self.errorMessage = "Couldn't load feed: \(error.localizedDescription)"
            print("DEBUG: fetchFeedPosts failed — \(error)")
        }
    }

    func fetchWeeklyTask() async {
        self.weeklyTask = try? await WeeklyTaskService.fetchCurrentTask()
    }
}
