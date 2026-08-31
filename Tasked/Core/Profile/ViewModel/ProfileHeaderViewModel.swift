//
//  ProfileHeaderViewModel.swift
//  Tasked
//
//  Drives the friend-request button on ProfileHeaderView (Feature 5).
//  Updated (live-refresh pass): `user` used to be captured once at init and
//  never touched again, so editing your bio/name/profile picture (which
//  writes the change into AuthService.shared.currentUser on save) didn't show
//  up here until the app was relaunched — this view model was never told
//  about it. Now it subscribes to AuthService.shared.$currentUser and syncs
//  itself whenever an update comes in for the profile it's currently showing.
//

import Foundation
import Combine

@MainActor
class ProfileHeaderViewModel: ObservableObject {
    @Published var user: User
    @Published var status: FriendshipStatus = .notFriends
    @Published var isLoadingStatus = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init(user: User) {
        self.user = user
        Task { await refreshStatus() }
        observeCurrentUserUpdates()
    }

    /// Keeps this header's `user` in sync with AuthService.shared.currentUser
    /// whenever it's showing the signed-in user's own profile. Without this,
    /// EditProfileView/EditProfilePictureView could update the source of
    /// truth all they wanted — this @StateObject-owned copy would never hear
    /// about it.
    private func observeCurrentUserUpdates() {
        AuthService.shared.$currentUser
            .compactMap { $0 }
            .sink { [weak self] updatedUser in
                guard let self, updatedUser.id == self.user.id else { return }
                self.user = updatedUser
            }
            .store(in: &cancellables)
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
