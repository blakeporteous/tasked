//
//  ActivityViewModel.swift
//  Tasked
//
//  Updated: user lookups for each incoming request are now batched via a single
//  'in' query instead of one Firestore read per request (Feature 1 efficiency ask).
//

import Foundation

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var incomingRequests: [FriendRequest] = []
    @Published var incomingUsers: [String: User] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        Task { await fetchRequests() }
    }

    func fetchRequests() async {
        guard let uid = AuthService.shared.userSession?.uid else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            incomingRequests = try await FriendService.fetchIncomingRequests(for: uid)

            let uidsToFetch = Array(Set(incomingRequests.map(\.fromUid))).filter { incomingUsers[$0] == nil }
            if !uidsToFetch.isEmpty {
                let fetchedUsers = try await UserService.fetchUsers(withUids: uidsToFetch)
                for user in fetchedUsers {
                    incomingUsers[user.id] = user
                }
            }
        } catch {
            errorMessage = "Couldn't load friend requests: \(error.localizedDescription)"
        }
    }

    func accept(_ request: FriendRequest) async {
        do {
            try await FriendService.acceptFriendRequest(from: request.fromUid)
            await fetchRequests()
        } catch {
            errorMessage = "Couldn't accept that request: \(error.localizedDescription)"
        }
    }

    func decline(_ request: FriendRequest) async {
        do {
            try await FriendService.declineFriendRequest(from: request.fromUid)
            await fetchRequests()
        } catch {
            errorMessage = "Couldn't decline that request: \(error.localizedDescription)"
        }
    }
}
