//
//  FriendsView.swift
//  Tasked
//
//  New: reachable by tapping the Friends count on a profile. Lists every user
//  in `user.friendUids` with picture and username.
//  Updated (Navigation-fix pass): FriendsDestination lets opening this
//  screen ALSO be a value-based push, avoiding a known SwiftUI ghost-push
//  bug from mixing boolean-flag and value-based NavigationLink styles on the
//  same NavigationStack.
//  Updated (Drop fullname pass): removed the fullname line under each
//  friend's username — User no longer has a fullname field.
//

import SwiftUI

/// Value-based navigation target for opening someone's Friends list.
/// Deliberately its own type (not reusing User) so it can't collide with the
/// existing `.navigationDestination(for: User.self)` used for profiles.
struct FriendsDestination: Hashable {
    let user: User
}

struct FriendsView: View {
    let user: User
    @StateObject private var viewModel = FriendsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.fetchFriends(for: user) }
                    }
                    .font(.footnote)
                }
                .padding(.top, 40)
                .padding(.horizontal, 24)
            } else if viewModel.friends.isEmpty {
                Text("No friends yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
            } else {
                List(viewModel.friends) { friend in
                    NavigationLink(value: friend) {
                        HStack(spacing: 12) {
                            CircularProfileImageView(user: friend, size: .small)

                            Text(friend.username)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 2)
                    }
                    .foregroundStyle(.primary)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Friends (\(user.friendsCount))")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchFriends(for: user)
        }
    }
}

#Preview {
    NavigationStack { FriendsView(user: User.MOCK_USERS[0]) }
}
