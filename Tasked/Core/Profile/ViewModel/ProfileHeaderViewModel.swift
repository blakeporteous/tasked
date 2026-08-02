//
//  ProfileHeaderViewModel.swift
//  Tasked
//
//  Drives the friend-request button on ProfileHeaderView (Feature 5).
//

import Foundation

@MainActor
class ProfileHeaderViewModel: ObservableObject {
    @Published var user: User
    @Published var status: FriendshipStatus = .notFriends
    @Published var isLoadingStatus = false
    @Published var errorMessage: String?

    init(user: User) {
        self.user = user
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        guard let currentUser = AuthService.shared.currentUser else { return }
        isLoadingStatus = true
        defer { isLoadingStatus = false }

        do {
            status = try await FriendService.fetchStatus(with: user.id, currentUser: currentUser)
        } catch {
            errorMessage = "Couldn't load friend status."
        }
    }

    /// Handles the single primary button — its meaning changes with `status`.
    func primaryAction() {
        Task {
            do {
                switch status {
                case .notFriends:
                    try await FriendService.sendFriendRequest(to: user.id)
                    status = .requestSent
                case .requestSent:
                    try await FriendService.cancelFriendRequest(to: user.id)
                    status = .notFriends
                case .requestReceived:
                    try await FriendService.acceptFriendRequest(from: user.id)
                    status = .friends
                case .friends:
                    try await FriendService.removeFriend(user.id)
                    status = .notFriends
                case .isCurrentUser:
                    break
                }
            } catch {
                errorMessage = "That didn't work: \(error.localizedDescription)"
            }
        }
    }

    func decline() {
        Task {
            try? await FriendService.declineFriendRequest(from: user.id)
            await refreshStatus()
        }
    }
}
