//
//  ProfileHeaderView.swift
//  Tasked
//
//  Updated profile layout:
//  - Centered profile picture
//  - Username underneath
//  - Simple Friends: number display
//  Updated (Streaks): a streak indicator sits directly to the right of the
//  Friends button, reading from User.displayStreak.
//  Updated (Status callback fix): added an optional onStatusChange closure.
//  Updated (Public streaks pass): streak now reads "Streak: N" (plain text).
//  Updated (Ink block pass): the primary friend-action button and "Decline"
//  now use the shared inkButton() chrome.
//  Updated (Side-by-side layout pass): the profile picture now sits on the
//  left (with the shared ink chrome) instead of centered above everything,
//  with the username and the Friends/Streak stacked to its right.
//  Updated (Stacked stats pass): Friends and Streak stacked vertically
//  (Friends on top, Streak below), both left-aligned under the username.
//  Updated (Lowercase labels pass): "Friends:"/"Streak:" -> "friends:"/
//  "streak:", matching the private profile view.
//  Updated (Card revamp pass): rebuilt to match a reference design — avatar
//  top-left next to a name/@username pair, bio full-width below, a small
//  gray pin+location row under that, then a row of THREE stat cards
//  (posts w/ 3 recent captions, friends, streak) replacing the old plain
//  "friends:"/"streak:" text lines. Friends card keeps the tap-through to
//  FriendsView; streak card is just informational, matching before.
//  Updated (Posts-card layout pass): the 3 recent captions in the posts
//  card sit to the RIGHT of the count+label, instead of stacking underneath.
//  Updated (Card sizing pass): stat numbers are now bold and noticeably
//  bigger, every card centers its content, and the row is sized so the
//  posts card takes HALF the row's width while friends/streak each take a
//  QUARTER — computed off UIScreen.main.bounds.width.
//  Updated (Shorter-card, bigger-text pass): card height brought down and
//  every card's text bumped up a size. The posts card's count/label and its
//  recent-captions list each center within their own half of the card.
//  Updated (Black-text pass): every label uses an explicit `.black`
//  foreground. Location always shows a pin + text, falling back to a
//  placeholder when unset.
//  Updated (Avatar + alignment pass): name/@username block vertically
//  centered next to the avatar; location icon switched to plain "mappin",
//  colored gray along with its text.
//  Updated (Screen-fraction sizing pass): rebuilt the whole header's
//  vertical layout around fixed fractions of UIScreen.main.bounds.height,
//  so it takes up a consistent proportion of the screen regardless of
//  device size, leaving the rest for PostGridView below in the scroll view:
//  - avatarSection (avatar + name/@username): 1/5 of screen height. The
//    avatar itself now fills that section's height via
//    CircularProfileImageView's new overrideDimension, well past the old
//    fixed .large (80pt) size.
//  - bioLocationSection (bio, now explicitly ABOVE location): 1/10.
//  - statsSection (posts/friends/streak cards): 1/10.
//  The outer VStack's own spacing is 0 so these fractions aren't padded out
//  by extra inter-section gaps — spacing lives inside each section instead.
//  Updated (Profile-picture viewer pass): tapping the avatar now opens
//  ProfileImageViewerView full-screen instead of doing nothing.
//

import SwiftUI

struct ProfileHeaderView: View {
    @StateObject private var viewModel: ProfileHeaderViewModel
    @State private var showFriends = false
    @State private var showFullImage = false

    var onStatusChange: ((FriendshipStatus) -> Void)? = nil

    init(user: User, onStatusChange: ((FriendshipStatus) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ProfileHeaderViewModel(user: user))
        self.onStatusChange = onStatusChange
    }

    private var user: User {
        viewModel.user
    }

    private let statsHorizontalPadding: CGFloat = 16
    private let statCardSpacing: CGFloat = 10

    /// Shown in place of a real location until the user sets one via Edit
    /// Profile.
    private let placeholderLocation = "New York City"

    private var screenHeight: CGFloat { UIScreen.main.bounds.height }
    /// Avatar + name/@username row. Shrunk from 1/5 to 1/8 of screen height
    /// per request — a smaller avatar with more breathing room below it.
    private var avatarSectionHeight: CGFloat { screenHeight / 8 }
    /// Posts/friends/streak stat card row — its own (small) fraction now,
    /// plus smaller fonts/padding inside each card (see
    /// postsStatCard/statCardContent below).
    private var statsSectionHeight: CGFloat { screenHeight / 17 }

    /// Single spacing value used between EVERY section in this header —
    /// avatar -> bio, bio -> location, and location -> stat boxes — so all
    /// three gaps read as the same size instead of each being driven by a
    /// different fixed-height frame.
    private let sectionSpacing: CGFloat = 14

    /// One "quarter unit" of the stat row's width. Posts gets 2 units
    /// (half), friends and streak get 1 unit each (a quarter).
    private var statUnitWidth: CGFloat {
        let rowWidth = UIScreen.main.bounds.width - (statsHorizontalPadding * 2)
        return (rowWidth - statCardSpacing * 2) / 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            avatarSection
                .padding(.bottom, sectionSpacing)

            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .padding(.bottom, sectionSpacing)
            }

            locationRow
                .padding(.bottom, sectionSpacing)

            statsSection

            if !user.isCurrentUser {

                if viewModel.isLoadingStatus {

                    ProgressView()
                        .padding(.vertical, 8)

                } else {

                    HStack(spacing: 10) {

                        Button {
                            viewModel.primaryAction()
                        } label: {
                            Text(primaryButtonTitle)
                                .inkButton(isDisabled: viewModel.status == .friends || viewModel.status == .requestSent)
                        }


                        if viewModel.status == .requestReceived {

                            Button {
                                viewModel.decline()
                            } label: {
                                Text("Decline")
                                    .inkButton(.secondary)
                            }
                        }
                    }
                    .padding(.top, 12)
                }
            }


            if let errorMessage = viewModel.errorMessage {

                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }


            Divider()
                .padding(.top, 12)
        }
        .padding(.horizontal, statsHorizontalPadding)
        .padding(.top, 16)
        .navigationDestination(isPresented: $showFriends) {
            FriendsView(user: user)
        }
        .fullScreenCover(isPresented: $showFullImage) {
            ProfileImageViewerView(user: user)
        }
        .onChange(of: viewModel.status) { _, newStatus in
            onStatusChange?(newStatus)
        }
    }

    /// Avatar (sized to fill this section's height) + name/@username
    /// vertically centered beside it. Fixed at 1/5 of screen height.
    /// Tapping the avatar opens it full-screen via ProfileImageViewerView.
    private var avatarSection: some View {
        HStack(alignment: .center, spacing: 14) {
            CircularProfileImageView(user: user, size: .large, overrideDimension: avatarSectionHeight)
                .contentShape(Circle())
                .onTapGesture { showFullImage = true }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .frame(height: avatarSectionHeight)
    }

    /// Location line — falls back to a placeholder until the user sets a
    /// real one via Edit Profile. Gray — the one row on this screen that
    /// isn't black.
    private var locationRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin")
                .font(.subheadline)
            Text(user.location?.isEmpty == false ? user.location! : placeholderLocation)
                .font(.subheadline)
        }
        .foregroundStyle(.secondary)
    }

    /// Posts/friends/streak card row, fixed at 1/10 of screen height.
    private var statsSection: some View {
        HStack(spacing: statCardSpacing) {
            postsStatCard
                .frame(width: statUnitWidth * 2, height: statsSectionHeight)

            Button {
                showFriends = true
            } label: {
                statCardContent(value: "\(user.friendsCount)", label: "friends")
            }
            .buttonStyle(.plain)
            .frame(width: statUnitWidth, height: statsSectionHeight)

            statCardContent(value: "\(user.displayStreak)", label: "streak")
                .frame(width: statUnitWidth, height: statsSectionHeight)
        }
    }

    /// The "posts" stat card — split into two EQUAL-WIDTH halves via
    /// `.frame(maxWidth: .infinity)` on each side of the HStack, so the
    /// count+label centers within its own left half and the recent-captions
    /// list centers within its own right half.
    private var postsStatCard: some View {
        HStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("\(viewModel.postsCount)")
                    .font(.system(size: 22, weight: .black))

                Text("posts")
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)

            if !viewModel.recentPostCaptions.isEmpty {
                VStack(spacing: 2) {
                    ForEach(Array(viewModel.recentPostCaptions.enumerated()), id: \.offset) { _, caption in
                        Text(caption)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Shared look for the "friends" and "streak" cards.
    private func statCardContent(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black))

            Text(label)
                .font(.caption2)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }


    private var primaryButtonTitle: String {

        switch viewModel.status {

        case .notFriends:
            return "Add Friend"

        case .requestSent:
            return "Request Sent"

        case .requestReceived:
            return "Accept"

        case .friends:
            return "Friends"

        case .isCurrentUser:
            return ""
        }
    }
}


#Preview {
    ProfileHeaderView(user: User.MOCK_USERS[0])
}
