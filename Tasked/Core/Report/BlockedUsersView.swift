//
//  BlockedUsersView.swift
//  Tasked
//
//  New (Block feature pass): reachable from Settings > Blocked Accounts.
//  Lists everyone the signed-in user has blocked, with an inline "Unblock"
//  button per row — mirrors FriendsView's list layout and empty/error/
//  loading states.
//

import SwiftUI

struct BlockedUsersView: View {
    @StateObject private var viewModel = BlockedUsersViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.blockedUsers.isEmpty {
                ProgressView()
                    .padding(.top, 40)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.fetchBlockedUsers() }
                    }
                    .font(.footnote)
                }
                .padding(.top, 40)
                .padding(.horizontal, 24)
            } else if viewModel.blockedUsers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "hand.raised.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("You haven't blocked anyone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
            } else {
                List(viewModel.blockedUsers) { user in
                    HStack(spacing: 12) {
                        CircularProfileImageView(user: user, size: .small)

                        Text(user.username)
                            .fontWeight(.semibold)

                        Spacer()

                        if viewModel.unblockingUserId == user.id {
                            ProgressView()
                        } else {
                            Button("Unblock") {
                                Task { await viewModel.unblock(user) }
                            }
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .buttonStyle(.bordered)
                            .disabled(viewModel.unblockingUserId != nil)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Blocked Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchBlockedUsers()
        }
    }
}

#Preview {
    NavigationStack { BlockedUsersView() }
}
