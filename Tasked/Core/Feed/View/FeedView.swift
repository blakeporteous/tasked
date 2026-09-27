//
//  FeedView.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//  (earlier header comments unchanged — trimmed here for brevity)
//  Updated (Icon chip pass): the menu and bell icons sit on a fixed
//  circular chip with a thin ring around the outside — same idea as
//  StoryCard's seen/unseen ring. The center seal icon is left plain (not a
//  button, no chip). The bell's unread-count dot still overlays on top of
//  the chip, same position as before.
//  Updated (Light-gray chip pass): chip fill switched from a near-white
//  to an actual light gray, with a darker gray glyph on top and a subtle
//  lighter ring around the outside — matches the reference screenshot
//  (light gray circle, darker gray bell) rather than the previous
//  near-white-on-white look.
//  Updated (Bigger-icons pass): iconChipDiameter bumped 44 -> 52 and the
//  glyph size inside each chip 18 -> 22 (menu + bell both grow together
//  since they share iconChip(_:)). The center seal glyph bumped to match.
//  Updated (Scrolls-away pass): topBar is no longer pinned via
//  safeAreaInset or a fixed overlay — both of those kept it on screen
//  permanently, which wasn't the goal. It's now just the first item inside
//  the ScrollView's own content stack, exactly like WeeklyTaskBannerView
//  and StoryBarView below it: it sits at the top when the feed is scrolled
//  to the top, and scrolls up and out of view like everything else the
//  moment you scroll down. The navigation bar stays hidden since nothing
//  lives in a toolbar.
//

import SwiftUI

struct FeedView: View {
    @StateObject var viewModel = FeedViewModel()
    @EnvironmentObject var notificationsViewModel: NotificationsViewModel
    @State private var showNotifications = false
    @State private var showActivity = false
    @Environment(\.scenePhase) private var scenePhase
    @Binding var tabIndex: Int

    /// Size of the chip behind the menu and bell icons.
    private let iconChipDiameter: CGFloat = 52
    private let iconChipRingWidth: CGFloat = 1.5
    private let iconChipFillColor = Color(red: 233.0 / 255.0, green: 233.0 / 255.0, blue: 235.0 / 255.0)
    private let iconChipRingColor = Color(red: 245.0 / 255.0, green: 245.0 / 255.0, blue: 247.0 / 255.0)
    private let iconChipGlyphColor = Color(red: 100.0 / 255.0, green: 100.0 / 255.0, blue: 103.0 / 255.0)

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                ScrollView {
                    // Explicit VStack(spacing: 0) rather than leaving these as bare
                    // ScrollView children — SwiftUI implicitly stacks multiple
                    // top-level children with default (non-zero) spacing, which is
                    // both a visual gap bug and, combined with a LazyVStack right
                    // below it, a plausible source of the first post's tap target
                    // being miscalculated right at the seam between the two.
                    VStack(spacing: 0) {
                        // Plain content now — scrolls away with everything else
                        // below it, same as WeeklyTaskBannerView/StoryBarView.
                        topBar
                            .padding(.bottom, 8)

                        if let task = viewModel.weeklyTask {
                            WeeklyTaskBannerView(task: task)
                                .padding(.bottom, 16) // more room before the story bar
                        }

                        if !viewModel.storyBarPosts.isEmpty {
                            StoryBarView(
                                posts: viewModel.storyBarPosts,
                                seenPostIds: viewModel.seenPostIds,
                                onAddTapped: { tabIndex = 2 } // jumps to the Upload tab
                            )
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
                            LazyVStack(spacing: 14) {
                                ForEach(viewModel.posts) { post in
                                    FeedCell(post: post, onBlock: { blockedUser in
                                        viewModel.removePosts(from: blockedUser)
                                    })
                                        // This is what actually marks a story
                                        // "seen" — the moment this cell renders
                                        // on screen while scrolling.
                                        .onAppear { viewModel.markSeen(post) }
                                }                            }
                            .padding(.top, 4) // tighter gap right under the story bar

                            // Deliberate stopping point at the end of the
                            // week's feed, rather than the list just running
                            // out with no signal that's everything.
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("You're all caught up")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                            .padding(.bottom, 24) // clears the bottom blur overlay
                        }
                    }
                }
                .refreshable {
                    await viewModel.refreshAsync()
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showNotifications) {
                    NotificationsView()
                }
                .navigationDestination(isPresented: $showActivity) {
                    ActivityView()
                }
                .navigationDestination(for: User.self) { user in
                    ProfileView(user: user)
                }
                .navigationDestination(for: FriendsDestination.self) { destination in
                    FriendsView(user: destination.user)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.refreshWeekIfNeeded()
                }
            }

            // Soft blur that fades in well above the tab bar and dissolves
            // to full blur right at the literal bottom edge of the screen.
            GeometryReader { proxy in
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black.opacity(0.25), location: 0.55),
                                .init(color: .black, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: proxy.size.width, height: 160)
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 80)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    /// The menu / seal / bell row — now just plain content at the top of
    /// the ScrollView, so it scrolls away with the rest of the feed instead
    /// of staying pinned on screen.
    private var topBar: some View {
        HStack {
            Menu {
                Button {
                    showActivity = true
                } label: {
                    Label("Friend Requests", systemImage: "person.badge.plus")
                }
            } label: {
                iconChip(systemName: "line.3.horizontal")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "seal.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.primary)

            Button {
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    iconChip(systemName: "bell")

                    if notificationsViewModel.unreadCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 9, height: 9)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// Circular chip behind the menu and bell icons — a light gray fill
    /// with a thin, subtly lighter ring around the outside, and a darker
    /// gray glyph on top.
    private func iconChip(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(iconChipGlyphColor)
            .frame(width: iconChipDiameter, height: iconChipDiameter)
            .background(
                Circle()
                    .fill(iconChipFillColor)
            )
            .overlay(
                Circle()
                    .stroke(iconChipRingColor, lineWidth: iconChipRingWidth)
            )
    }
}

#Preview {
    FeedView(tabIndex: .constant(0))
        .environmentObject(NotificationsViewModel())
}
