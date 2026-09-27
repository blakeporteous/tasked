//
//  FriendsViewModel.swift
//  Tasked
//
//  New: backs FriendsView. Deliberately reuses UserService.fetchUsers(withUids:)
//  rather than FriendService.fetchFriends(for:) to avoid having two code paths
//  that do the same batched lookup.
//  Updated (Deactivate account pass): filters out any friend who's currently
//  deactivated — same "hidden while deactivated, reappears automatically on
//  reactivation" behavior as search results and the feed.
//

import Foundation

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchFriends(for user: User) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await UserService.fetchUsers(withUids: user.friendUids)
            friends = fetched.filter { !$0.isDeactivated }
        } catch {
            errorMessage = "Couldn't load friends: \(error.localizedDescription)"
        }
    }
}
