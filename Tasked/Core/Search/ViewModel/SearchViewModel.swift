//
//  SearchViewModel.swift
//  Tasked
//
//  Rewritten (Feature 2 bugfix): previously called fetchAllUsers() on init and again
//  whenever the search text was cleared, so search always showed the entire user base
//  instead of filtering. Now it never loads all users — results only appear once a
//  query is typed, matching normal social-app search behaviour.
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

    private var searchTask: Task<Void, Never>?

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
}
