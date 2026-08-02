//
//  FriendsViewModel.swift
//  Tasked
//
//  New: backs FriendsView. Deliberately reuses UserService.fetchUsers(withUids:)
//  rather than FriendService.fetchFriends(for:) to avoid having two code paths
//  that do the same batched lookup.
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
            friends = try await UserService.fetchUsers(withUids: user.friendUids)
        } catch {
            errorMessage = "Couldn't load friends: \(error.localizedDescription)"
        }
    }
}
