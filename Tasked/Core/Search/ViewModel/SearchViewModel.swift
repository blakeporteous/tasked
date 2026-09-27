//
//  SearchViewModel.swift
//  Tasked
//
//  Rewritten (Feature 2 bugfix): search only shows results once a query is
//  typed, matching normal social-app search behaviour.
//  Updated (Recent searches pass): added recentSearches, backed by
//  RecentSearchService.
//  Updated (Search friend-status pass): both live results and recent
//  searches now also carry each person's FriendshipStatus. Previously the
//  list gave no hint of the relationship until you tapped into their full
//  profile — someone who'd already sent YOU a friend request looked
//  identical to a total stranger. SearchView now shows an inline "Accept"
//  button (mirrors NotificationsView's pattern) for anyone with a pending
//  incoming request, and a "Requested" label for anyone you've already sent
//  one to, right in the list.
//

import Foundation

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = "" {
        didSet {
            searchTask?.cancel()
            searchTask = Task { await debouncedSearch() }
        }
    }
    @Published var users = [User]()
    @Published var errorMessage: String?
    @Published var isLoading = false
    /// True once a search has actually run, so the UI can tell "haven't searched yet"
    /// apart from "searched and found nothing".
    @Published var hasSearched = false

    /// Previously-searched people, newest first. Shown on the idle (empty
    /// search text) state instead of the generic "search to get started"
    /// prompt once there's at least one entry.
    @Published var recentSearches: [User] = []

    /// The signed-in user's relationship to each person currently shown,
    /// keyed by uid — covers both `users` (live results) and
    /// `recentSearches`. Populated alongside whichever list changes.
    @Published var friendStatuses: [String: FriendshipStatus] = [:]

    private var searchTask: Task<Void, Never>?

    init() {
        Task { await loadRecentSearches() }
    }

    /// Waits briefly after the last keystroke before querying, so we don't
    /// fire a Firestore read on every character typed.
    private func debouncedSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            users = []
            hasSearched = false
            errorMessage = nil
            return
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        await search(query: query)
    }

    func search(query: String) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasSearched = true
        }

        do {
            self.users = try await UserService.searchUsers(matching: query)
            await loadFriendStatuses(for: users)
        } catch {
            self.errorMessage = "Search failed: \(error.localizedDescription)"
            print("DEBUG: searchUsers failed — \(error)")
        }
    }

    /// Retry hook for the error state's Retry button.
    func retry() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        await search(query: searchText)
    }

    // MARK: - Friendship status

    /// Looks up each person's FriendshipStatus, skipping anyone already
    /// cached — a fresh search and the recent-searches load both call this,
    /// and a person can appear in both lists.
    private func loadFriendStatuses(for people: [User]) async {
        guard let currentUser = AuthService.shared.currentUser else { return }

        for person in people where friendStatuses[person.id] == nil {
            if let status = try? await FriendService.fetchStatus(with: person.id, currentUser: currentUser) {
                friendStatuses[person.id] = status
            }
        }
    }

    /// Accepts an incoming request straight from the search list — same
    /// call ActivityView and NotificationsView make. Updates the local
    /// status immediately rather than waiting on a re-search.
    func acceptFriendRequest(from user: User) async {
        do {
            try await FriendService.acceptFriendRequest(from: user.id)
            friendStatuses[user.id] = .friends
        } catch {
            errorMessage = "Couldn't accept that request: \(error.localizedDescription)"
        }
    }

    // MARK: - Recent searches

    func loadRecentSearches() async {
        guard let uid = AuthService.shared.currentUser?.id else { return }
        let ids = RecentSearchService.fetch(for: uid)
        guard !ids.isEmpty else {
            recentSearches = []
            return
        }
        guard let fetched = try? await UserService.fetchUsers(withUids: ids) else { return }

        // fetchUsers doesn't preserve order (a Firestore `in` query makes no
        // ordering guarantee), so re-sort to match the stored
        // most-recent-first order.
        let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        recentSearches = fetched.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
        await loadFriendStatuses(for: recentSearches)
    }

    /// Called whenever the person taps through to a profile from live search
    /// results OR from the recent list itself (which just re-promotes that
    /// entry back to the top, matching Instagram's behaviour).
    func recordSearch(_ user: User) {
        guard let uid = AuthService.shared.currentUser?.id else { return }
        RecentSearchService.record(user.id, for: uid)

        recentSearches.removeAll { $0.id == user.id }
        recentSearches.insert(user, at: 0)
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
    }

    func removeRecentSearch(_ user: User) {
        guard let uid = AuthService.shared.currentUser?.id else { return }
        RecentSearchService.remove(user.id, for: uid)
        recentSearches.removeAll { $0.id == user.id }
    }

    func clearRecentSearches() {
        guard let uid = AuthService.shared.currentUser?.id else { return }
        RecentSearchService.clear(for: uid)
        recentSearches = []
    }
}
