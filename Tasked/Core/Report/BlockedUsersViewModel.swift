//
//  BlockedUsersViewModel.swift
//  Tasked
//
//  New (Block feature pass): backs the "Blocked Accounts" screen reachable
//  from Settings. Mirrors FriendsViewModel's shape (fetch a list of full
//  User profiles from a uid array on the signed-in user's document) plus
//  an unblock action per row.
//

import Foundation

@MainActor
class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Which row's Unblock button is currently in flight — lets the view
    /// show a spinner on just that row rather than a full-screen one.
    @Published var unblockingUserId: String?

    func fetchBlockedUsers() async {
        guard let currentUser = AuthService.shared.currentUser else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            blockedUsers = try await BlockService.fetchBlockedUsers(for: currentUser)
        } catch {
            errorMessage = "Couldn't load blocked accounts: \(error.localizedDescription)"
        }
    }

    /// Unblocks `user` and removes them from the local list immediately on
    /// success — no need to re-fetch the whole list for one removal.
    func unblock(_ user: User) async {
        unblockingUserId = user.id
        errorMessage = nil
        defer { unblockingUserId = nil }

        do {
            try await BlockService.unblockUser(user.id)
            blockedUsers.removeAll { $0.id == user.id }

            if var updatedUser = AuthService.shared.currentUser {
                updatedUser.blockedUids.removeAll { $0 == user.id }
                AuthService.shared.currentUser = updatedUser
            }
        } catch {
            errorMessage = "Couldn't unblock \(user.username): \(error.localizedDescription)"
        }
    }
}
