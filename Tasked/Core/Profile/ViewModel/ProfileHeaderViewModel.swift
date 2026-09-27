//
//  ProfileHeaderViewModel.swift
//  Tasked
//
//  Drives the friend-request button on ProfileHeaderView (Feature 5).
//  Updated (Streaks): subscribes to AuthService.shared.$currentUser (same
//  pattern as PostGridViewModel) so that when this is the signed-in user's
//  own profile, a fresh streak (or any other profile edit made elsewhere,
//  e.g. EditProfileView) is reflected immediately without a relaunch.
//  Updated (Public streaks pass): that AuthService subscription only ever
//  fired for the SIGNED-IN user's own profile — viewing anyone else's
//  profile just showed whatever `User` snapshot was passed in at
//  navigation time (e.g. denormalized onto a post, or from search results),
//  which could be stale. Replaced with a direct Firestore snapshot listener
//  on whichever profile is actually being viewed, so streak/bio/username all
//  live-update the same way regardless of whose profile it is.
//  Updated (Profile revamp pass): added a second live listener
//  (PostService.listenToUserPosts) so the new stat-box row on
//  ProfileHeaderView can show a live post count plus the 3 most recent
//  captions, without ProfileHeaderView needing its own copy of
//  PostGridViewModel. Cheap to keep live — this app caps posts at one per
//  week, so even a long-time user's full post list is small (see
//  PostFeedView's note: "at most ~52/year").
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class ProfileHeaderViewModel: ObservableObject {
    @Published var user: User
    @Published var status: FriendshipStatus = .notFriends
    @Published var isLoadingStatus = false
    @Published var errorMessage: String?

    /// Total number of posts this user has made — backs the "posts" stat box.
    @Published var postsCount: Int = 0
    /// Captions of the 3 most recent posts (newest first) — shown as small
    /// text lines inside the "posts" stat box, mirroring the reference
    /// design's "New York / Los Angeles / Paris" recent-items list.
    @Published var recentPostCaptions: [String] = []

    private var cancellables = Set<AnyCancellable>()
    private var userListener: ListenerRegistration?
    private var postsListener: ListenerRegistration?

    init(user: User) {
        self.user = user
        Task { await refreshStatus() }
        startListeningToUser(uid: user.id)
        startListeningToPosts(uid: user.id)
    }

    /// Live-updates `user` from Firestore for whichever profile is being
    /// viewed — works the same whether it's the signed-in user's own profile
    /// or someone else's, so a streak/bio/location/username change is
    /// visible to anyone currently viewing that profile without a relaunch
    /// or re-fetch.
    private func startListeningToUser(uid: String) {
        userListener?.remove()
        userListener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot, let updatedUser = try? snapshot.data(as: User.self) else { return }
                Task { @MainActor in
                    self?.user = updatedUser
                }
            }
    }

    /// Live-updates postsCount/recentPostCaptions for the stat box row.
    private func startListeningToPosts(uid: String) {
        postsListener?.remove()
        postsListener = PostService.listenToUserPosts(uid: uid) { [weak self] result in
            guard let self else { return }
            if case .success(let posts) = result {
                self.postsCount = posts.count
                self.recentPostCaptions = Array(posts.prefix(3).map { $0.caption })
            }
        }
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

    deinit {
        userListener?.remove()
        postsListener?.remove()
    }
}
