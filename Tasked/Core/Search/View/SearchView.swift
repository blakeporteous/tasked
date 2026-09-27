//
//  SearchView.swift
//  Tasked
//
//  Created by Blake Porteous on 21/02/2025.
//  Updated (Feature 2): explicit idle state ("search to get started") instead of
//  showing every user by default; clearer no-results and error states.
//  Updated (Recent searches pass): the idle state (empty search text) now
//  shows a "Recent" section of previously-searched people, if any exist.
//  Updated (Search friend-status pass): each row now shows an inline
//  "Accept" button when that person has already sent the signed-in user a
//  friend request, or a "Requested" label if a request is already pending
//  the other way. Mirrors NotificationsView's inline Accept pattern —
//  placed as a sibling of the existing remove ("x") button inside the row's
//  NavigationLink label, same .buttonStyle(.plain) trick already used there
//  to keep its tap from triggering the row's own navigation.
//  Updated (Row declutter pass): dropped the fullname line under the
//  username — rows now show just the username.
//

import SwiftUI

struct SearchView: View {
    @StateObject var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                content
            }
            .searchable(text: $viewModel.searchText, prompt: "Search for people...")
            .navigationDestination(for: User.self) { user in
                ProfileView(user: user)
            }
            .navigationDestination(for: FriendsDestination.self) { destination in
                FriendsView(user: destination.user)
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var content: some View {
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
                    Task { await viewModel.retry() }
                }
                .font(.footnote)
            }
            .padding(.top, 40)
            .padding(.horizontal, 24)
        } else if viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            idleContent
        } else if viewModel.hasSearched && viewModel.users.isEmpty {
            Text("No users found matching \"\(viewModel.searchText)\".")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                .padding(.horizontal, 24)
        } else {
            userList(viewModel.users)
                .padding(.top, 8)
        }
    }

    /// Shown when the search field is empty. If there's any recent-search
    /// history, that takes priority over the generic prompt.
    @ViewBuilder
    private var idleContent: some View {
        if viewModel.recentSearches.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Search for people by username")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Recent")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button("Clear All") {
                        viewModel.clearRecentSearches()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)

                userList(viewModel.recentSearches, showsRemoveButton: true)
            }
        }
    }

    /// Shared row layout for both live results and the recent list. Each row
    /// is a value-based NavigationLink, with a simultaneous tap gesture that
    /// records the search.
    private func userList(_ people: [User], showsRemoveButton: Bool = false) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(people) { user in
                NavigationLink(value: user) {
                    HStack {
                        CircularProfileImageView(user: user, size: .xSmall)

                        Text(user.username)
                            .fontWeight(.semibold)

                        Spacer()

                        friendActionView(for: user)

                        if showsRemoveButton {
                            Button {
                                viewModel.removeRecentSearch(user)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    viewModel.recordSearch(user)
                })
            }
        }
    }

    /// Relationship-aware trailing control for one row. Only the two states
    /// worth acting on right from the list get a control — "friends" and
    /// "not friends" still just rely on tapping through to the full profile.
    @ViewBuilder
    private func friendActionView(for user: User) -> some View {
        switch viewModel.friendStatuses[user.id] {
        case .requestReceived:
            Button {
                Task { await viewModel.acceptFriendRequest(from: user) }
            } label: {
                Text("Accept")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.systemBackground))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

        case .requestSent:
            Text("Requested")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize()

        default:
            EmptyView()
        }
    }
}

#Preview {
    SearchView()
}
