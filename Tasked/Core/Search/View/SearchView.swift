//
//  SearchView.swift
//  Tasked
//
//  Created by Blake Porteous on 21/02/2025.
//  Updated (Feature 2): explicit idle state ("search to get started") instead of
//  showing every user by default; clearer no-results and error states.
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
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Search for people by username")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
        } else if viewModel.hasSearched && viewModel.users.isEmpty {
            Text("No users found matching \"\(viewModel.searchText)\".")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                .padding(.horizontal, 24)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.users) { user in
                    NavigationLink(value: user) {
                        HStack {
                            CircularProfileImageView(user: user, size: .xSmall)

                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .fontWeight(.semibold)

                                if let fullname = user.fullname {
                                    Text(fullname)
                                        .font(.footnote)
                                }
                            }

                            Spacer()
                        }
                        .foregroundStyle(Color(.black))
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

#Preview {
    SearchView()
}
