//
//  FeedView.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//  Updated: weekly task banner pinned above the feed (kept from the previous pass).
//  The old paperplane icon is now a bell with an unread-count badge that opens
//  NotificationsView (Feature 4).
//

import SwiftUI

struct FeedView: View {
    @StateObject var viewModel = FeedViewModel()
    @EnvironmentObject var notificationsViewModel: NotificationsViewModel
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let task = viewModel.weeklyTask {
                    WeeklyTaskBannerView(task: task)
                }

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
                            Task { await viewModel.fetchPosts() }
                        }
                        .font(.footnote)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                } else if viewModel.posts.isEmpty {
                    Text("No posts yet. Add some friends or share your first post!")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)
                        .padding(.horizontal, 32)
                } else {
                    LazyVStack(spacing: 32) {
                        ForEach(viewModel.posts) { post in
                            FeedCell(post: post)
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNotifications = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .imageScale(.large)
                                .foregroundStyle(.black)

                            if notificationsViewModel.unreadCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 9, height: 9)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsView()
            }
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(NotificationsViewModel())
}
