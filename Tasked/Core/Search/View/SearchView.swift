//
//  SearchView.swift
//  Tasked
//
//  Created by Blake Porteous on 21/02/2025.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @StateObject var viewModel = SearchViewModel()
    
    var filteredUsers: [User] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return viewModel.users
        }
        return viewModel.users.filter {
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView{
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
                            Task { await viewModel.fetchAllUsers() }
                        }
                        .font(.footnote)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                } else if filteredUsers.isEmpty {
                    Text(viewModel.users.isEmpty ? "No users found." : "No matches.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12){
                        ForEach(filteredUsers) { user in
                            NavigationLink(value: user) {
                                HStack{
                                    CircularProfileImageView(user: user, size: .xSmall)
                                    
                                    VStack(alignment: .leading){
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
            .searchable(text: $searchText, prompt: "Search...")
            .navigationDestination(for: User.self, destination: { user in
                ProfileView(user: user)
            })
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SearchView()
}
