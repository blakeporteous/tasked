//
//  ActivityViewModel.swift
//  Tasked
//
//  Updated: user lookups for each incoming request are now batched via a single
//  'in' query instead of one Firestore read per request (Feature 1 efficiency ask).
//  Updated (Live friend-requests pass): swapped the one-shot fetchRequests() for
//  a real-time listener (FriendService.listenToIncomingRequests). Previously a
//  request that arrived — or was accepted/declined from elsewhere, e.g.
//  NotificationsView's inline Accept/Decline — wasn't reflected here until the
//  screen was closed and reopened, since nothing ever re-fetched on its own.
//  accept(_:)/decline(_:) no longer need to manually re-fetch afterward either —
//  the listener picks up the status change itself, same pattern as
//  PostGridViewModel's live posts listener.
//

import Foundation
import FirebaseFirestore

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var incomingRequests: [FriendRequest] = []
    @Published var incomingUsers: [String: User] = [:]
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?

    init() {
        startListening()
    }

    /// Starts (or restarts) the live listener. Safe to call again at any
    /// time — e.g. from the Retry button on an error state.
    func startListening() {
        guard let uid = AuthService.shared.userSession?.uid else { return }

        listener?.remove()
        isLoading = true
        errorMessage = nil

        listener = FriendService.listenToIncomingRequests(for: uid) { [weak self] result in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let requests):
                self.incomingRequests = requests
                Task { await self.hydrateUsers(for: requests) }
            case .failure(let error):
                self.errorMessage = "Couldn't load friend requests: \(error.localizedDescription)"
            }
        }
    }

    /// Batched lookup for whichever senders don't already have a cached
    /// User, so the same person showing up across multiple requests only
    /// triggers one fetch for them.
    private func hydrateUsers(for requests: [FriendRequest]) async {
        let uidsToFetch = Array(Set(requests.map(\.fromUid))).filter { incomingUsers[$0] == nil }
        guard !uidsToFetch.isEmpty else { return }

        if let fetchedUsers = try? await UserService.fetchUsers(withUids: uidsToFetch) {
            for user in fetchedUsers {
                incomingUsers[user.id] = user
            }
        }
    }

    func accept(_ request: FriendRequest) async {
        do {
            try await FriendService.acceptFriendRequest(from: request.fromUid)
            // No manual re-fetch needed — the listener sees the status flip
            // away from "pending" and drops it from incomingRequests itself.
        } catch {
            errorMessage = "Couldn't accept that request: \(error.localizedDescription)"
        }
    }

    func decline(_ request: FriendRequest) async {
        do {
            try await FriendService.declineFriendRequest(from: request.fromUid)
        } catch {
            errorMessage = "Couldn't decline that request: \(error.localizedDescription)"
        }
    }

    deinit {
        listener?.remove()
    }
}
