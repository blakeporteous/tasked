//
//  FriendsView.swift
//  Tasked
//
//  New: reachable by tapping the Friends count on a profile. Lists every user
//  in `user.friendUids` with picture, username, and full name.
//

import SwiftUI

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
                    HStack(spacing: 12) {
                        CircularProfileImageView(user: friend, size: .small)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.username)
                                .fontWeight(.semibold)

                            if let fullname = friend.fullname {
                                Text(fullname)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
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
