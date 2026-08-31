//
//  FeedView.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//  Updated: weekly task banner pinned above the feed (kept from the previous pass).
//  The old paperplane icon is now a bell with an unread-count badge that opens
//  NotificationsView (Feature 4).
//  Updated (Feed engagement pass): tapping a post's profile row now navigates to
//  that user's profile.
//  Updated (Feed week-scoping pass): empty state now matches the two-line
//  "No posts yet / Check back later!" copy; Retry now restarts the listener
//  rather than calling a one-shot fetch that no longer exists; added a
//  scenePhase hook so returning from the background re-scopes the feed if the
//  calendar week changed while the app was backgrounded.
//

import SwiftUI

struct FeedView: View {
    @StateObject var viewModel = FeedViewModel()
    @EnvironmentObject var notificationsViewModel: NotificationsViewModel
    @State private var showNotifications = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                // Explicit VStack(spacing: 0) rather than leaving these as bare
                // ScrollView children — SwiftUI implicitly stacks multiple
                // top-level children with default (non-zero) spacing, which is
                // both a visual gap bug and, combined with a LazyVStack right
                // below it, a plausible source of the first post's tap target
                // being miscalculated right at the seam between the two.
                VStack(spacing: 0) {
                    if let task = viewModel.weeklyTask {
                        WeeklyTaskBannerView(task: task)
                    }

                    // isLoading && posts.isEmpty (not just isLoading) so a
                    // week-rollover restart doesn't blank out already-visible
                    // posts with a full-screen spinner while the new week's
                    // first snapshot is still loading.
                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let errorMessage = viewModel.errorMessage {
                        VStack(spacing: 8) {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                viewModel.startListeningToFeed()
                            }
                            .font(.footnote)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                    } else if viewModel.posts.isEmpty {
                        VStack(spacing: 6) {
                            Text("No posts yet")
                                .font(.headline)
                            Text("Check back later!")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 32) {
                            ForEach(viewModel.posts) { post in
                                FeedCell(post: post)
                            }
                        }
                        .padding(.top, 16)
                    }
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
            .navigationDestination(for: User.self) { user in
                ProfileView(user: user)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshWeekIfNeeded()
            }
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(NotificationsViewModel())
}
