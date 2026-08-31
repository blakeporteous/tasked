//
//  FeedViewModel.swift
//  Tasked
//
//  Created by Blake Porteous on 11/08/2025.
//  Updated: also fetches the active weekly task (Feature 4) and scopes posts to
//  friends via PostService.fetchFeedPosts(for:) (Feature 5).
//  Updated (Feed week-scoping pass): posts are now a real-time listener
//  (PostService.listenToFeedPosts) scoped to friends+self AND to the current
//  Monday-Sunday week (DateWeek), instead of a one-shot fetch of full history.
//  A self-rearming Timer re-scopes the listener the instant the week rolls
//  over even if the app is left open right through Monday midnight; a
//  scenePhase hook in FeedView covers the (more common) case of the app
//  having been backgrounded across the boundary and just resumed.
//

import Foundation
import Firebase
import FirebaseFirestore

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts = [Post]()
    @Published var weeklyTask: WeeklyTask?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private var postListeners: [ListenerRegistration] = []
    private var weekRolloverTimer: Timer?
    private var currentWeekStart: Date?

    init() {
        startListeningToFeed()
        Task { await fetchWeeklyTask() }
    }

    /// Starts (or restarts) a real-time listener scoped to the current
    /// Monday-Sunday week. Safe to call again at any time — e.g. to retry
    /// after an error, or to re-scope once the week has rolled over.
    func startListeningToFeed() {
        guard let currentUser = AuthService.shared.currentUser else { return }

        stopListeningToFeed()

        let (start, end) = DateWeek.currentWeekRange()
        currentWeekStart = start
        isLoading = true
        errorMessage = nil

        postListeners = PostService.listenToFeedPosts(for: currentUser, weekStart: start, weekEnd: end) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let posts):
                self.posts = posts
            case .failure(let error):
                self.errorMessage = "Couldn't load feed: \(error.localizedDescription)"
                print("DEBUG: feed listener failed — \(error)")
            }
        }

        // Re-scope automatically the instant this week ends — a snapshot
        // listener's query bounds don't update on their own, so it has to be
        // torn down and recreated with the new [weekStart, weekEnd).
        weekRolloverTimer?.invalidate()
        let interval = end.timeIntervalSinceNow
        if interval > 0 {
            weekRolloverTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.startListeningToFeed()
                }
            }
        }
    }

    func stopListeningToFeed() {
        postListeners.forEach { $0.remove() }
        postListeners = []
        weekRolloverTimer?.invalidate()
        weekRolloverTimer = nil
    }

    /// Re-scopes the listener if the calendar week has changed since it was
    /// last started. Call this when the app returns to the foreground (see
    /// FeedView's scenePhase handling) — the rollover Timer above only fires
    /// while the app stays alive continuously, so this catches the more
    /// common backgrounded-across-midnight case.
    func refreshWeekIfNeeded() {
        let (start, _) = DateWeek.currentWeekRange()
        if start != currentWeekStart {
            startListeningToFeed()
        }
    }

    func fetchWeeklyTask() async {
        self.weeklyTask = try? await WeeklyTaskService.fetchCurrentTask()
    }

    deinit {
        postListeners.forEach { $0.remove() }
        weekRolloverTimer?.invalidate()
    }
}
