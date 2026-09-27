//
//  FeedViewModel.swift
//  Tasked
//
//  (header comments unchanged from before — trimmed here for brevity)
//  Updated (Block user pass): added removePosts(from:), called by FeedView
//  the instant a block succeeds — drops that user's posts from `posts`
//  immediately rather than waiting for observeFriendListChanges to notice
//  the friendUids change and rebuild the (friends-scoped) feed listener,
//  which would otherwise still briefly show their posts.
//  Updated (Refresh-hold pass): added refreshAsync(), backing FeedView's
//  `.refreshable`. Restarts the feed listener (startListeningToFeed) and
//  suspends until that listener's NEXT snapshot — success or failure — has
//  actually landed, via a stashed continuation resumed from
//  startListeningToFeed's onChange callback. Previously nothing awaited
//  anything, so the pull-to-refresh spinner sprang back up immediately
//  while the feed was still loading underneath it.
//

import Foundation
import Combine
import Firebase
import FirebaseFirestore

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts = [Post]()
    @Published var weeklyTask: WeeklyTask?
    @Published var errorMessage: String?
    @Published var isLoading = false

    @Published var seenPostIds: Set<String> = []

    private var postListeners: [ListenerRegistration] = []
    private var weekRolloverTimer: Timer?
    private var currentWeekStart: Date?
    private var cancellables = Set<AnyCancellable>()

    /// Resumed once from startListeningToFeed's onChange callback, the
    /// first time a snapshot (success OR failure) lands after a restart —
    /// this is what lets refreshAsync() actually wait for real data instead
    /// of returning instantly.
    private var refreshContinuation: CheckedContinuation<Void, Never>?

    init() {
        startListeningToFeed()
        Task { await fetchWeeklyTask() }
        observeFriendListChanges()
    }

    func startListeningToFeed() {
        guard let currentUser = AuthService.shared.currentUser else {
            // No signed-in user to restart against — don't leave a pull-to-
            // refresh spinner hanging forever waiting for a snapshot that
            // will never come.
            resumeRefreshIfNeeded()
            return
        }

        stopListeningToFeed()

        let (start, end) = DateWeek.currentWeekRange()
        currentWeekStart = start
        isLoading = true
        errorMessage = nil

        seenPostIds = SeenPostsService.fetchSeenIds(for: currentUser.id)

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
            self.resumeRefreshIfNeeded()
        }

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

    /// Restarts the feed listener and suspends until its next snapshot
    /// (success or failure) has landed — backs FeedView's `.refreshable`,
    /// so the pull-to-refresh spinner stays up for the actual duration of
    /// the refresh instead of dismissing itself immediately.
    func refreshAsync() async {
        await withCheckedContinuation { continuation in
            refreshContinuation = continuation
            startListeningToFeed()
        }
    }

    /// Resumes (and clears) whatever refreshAsync() call is currently
    /// waiting, if any. Safe to call even when nothing's waiting.
    private func resumeRefreshIfNeeded() {
        refreshContinuation?.resume()
        refreshContinuation = nil
    }

    func stopListeningToFeed() {
        postListeners.forEach { $0.remove() }
        postListeners = []
        weekRolloverTimer?.invalidate()
        weekRolloverTimer = nil
    }

    func refreshWeekIfNeeded() {
        let (start, _) = DateWeek.currentWeekRange()
        if start != currentWeekStart {
            startListeningToFeed()
        }
    }

    private func observeFriendListChanges() {
        AuthService.shared.$currentUser
            .compactMap { $0 }
            .map { Set($0.friendUids) }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.startListeningToFeed()
            }
            .store(in: &cancellables)
    }

    func fetchWeeklyTask() async {
        self.weeklyTask = try? await WeeklyTaskService.fetchCurrentTask()
    }

    // MARK: - Story bar

    var storyBarPosts: [Post] {
        let unseen = posts.filter { !seenPostIds.contains($0.id) }
        let seen = posts.filter { seenPostIds.contains($0.id) }
        return unseen + seen
    }

    func markSeen(_ post: Post) {
        guard !seenPostIds.contains(post.id) else { return }
        guard let uid = AuthService.shared.currentUser?.id else { return }

        seenPostIds.insert(post.id)
        SeenPostsService.markSeen(post.id, for: uid)
    }

    // MARK: - Blocking

    /// Drops every post by `blockedUser` from the currently-loaded feed
    /// right away. The friends-scoped listener will also rebuild itself
    /// shortly (observeFriendListChanges picks up the friendUids change
    /// BlockService.block made), but that round-trip isn't instant — this
    /// keeps the UI responsive in the meantime.
    func removePosts(from blockedUser: User) {
        posts.removeAll { $0.ownerUid == blockedUser.id }
    }

    deinit {
        postListeners.forEach { $0.remove() }
        weekRolloverTimer?.invalidate()
    }
}
