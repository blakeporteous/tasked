//
//  PrivateProfileView.swift
//  Tasked
//
//  Private profile layout:
//  - Profile picture + username + friends count + streak (all visible)
//  - Add friend button
//  Updated (Ink block pass): the primary action button now uses the shared
//  inkButton() chrome.
//  Updated (Side-by-side layout pass): profile picture on the left (with
//  the shared ink chrome) and username + stats stacked to its right.
//  Updated (Streak-visible pass): streak is now shown here too, right under
//  friends count — both read as plain numbers (defaulting to 0) regardless
//  of privacy; only the actual FRIEND LIST stays hidden on a private
//  account, which is why "friends: N" here is still just a label, not a
//  NavigationLink into FriendsView like the public header's version.
//  Updated (Lowercase labels pass): "Friends:"/"Streak:" -> "friends:"/
//  "streak:", matching the public header.
//  Updated (Card revamp pass): rebuilt to match ProfileHeaderView's new
//  design — avatar next to name/@username, bio + gray pin/location row,
//  then the same 3-stat-card row. The "posts" card here shows COUNT ONLY,
//  deliberately with no recent captions — captions are actual post content,
//  which is exactly what a private account is meant to keep hidden from
//  non-friends. Friends card here is still just a label (not tappable into
//  FriendsView) since who those friends are stays hidden on a private
//  account, same as before.
//  Updated (Card sizing / black-text / avatar passes): matched
//  ProfileHeaderView's styling passes — bigger bold stat numbers, black
//  text throughout, gray "mappin" + location row with a placeholder.
//  Updated (Screen-fraction sizing pass): rebuilt around the same fixed
//  screen-height fractions as ProfileHeaderView — avatar+name section 1/5,
//  bio-above-location section 1/10, stat card row 1/10 — using the same
//  CircularProfileImageView overrideDimension for the bigger avatar.
//  Updated (Profile-picture viewer pass): tapping the avatar now opens
//  ProfileImageViewerView full-screen, matching ProfileHeaderView.
//

import SwiftUI

struct PrivateProfileView: View {

    let user: User
    let status: FriendshipStatus

    @State private var currentStatus: FriendshipStatus
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var postsCount = 0
    @State private var showFullImage = false

    private let statsHorizontalPadding: CGFloat = 16
    private let statCardSpacing: CGFloat = 10
    private let placeholderLocation = "New York City"

    private var screenHeight: CGFloat { UIScreen.main.bounds.height }
    /// Shrunk from 1/5 to 1/8 of screen height, matching ProfileHeaderView.
    private var avatarSectionHeight: CGFloat { screenHeight / 8 }
    /// Its own (small) fraction now, plus smaller fonts/padding inside each
    /// card (see statCard below).
    private var statsSectionHeight: CGFloat { screenHeight / 17 }

    /// Single spacing value used between EVERY section — avatar -> bio,
    /// bio -> location, and location -> stat boxes — so all three gaps read
    /// as the same size instead of each coming from a different fixed-height
    /// frame.
    private let sectionSpacing: CGFloat = 14

    private var statUnitWidth: CGFloat {
        let rowWidth = UIScreen.main.bounds.width - (statsHorizontalPadding * 2)
        return (rowWidth - statCardSpacing * 2) / 4
    }


    init(user: User, status: FriendshipStatus) {
        self.user = user
        self.status = status
        self._currentStatus = State(initialValue: status)
    }


    var body: some View {

        VStack(alignment: .leading, spacing: 0) {

            Spacer()
                .frame(height: 30)

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


            VStack(spacing: 8) {

                Image(systemName: "lock.fill")
                    .font(.title)

                Text("This profile is private")
                    .font(.subheadline)
                    .foregroundStyle(.primary)


                Text("Add \(user.username) as a friend to see their posts.")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)



            Button {

                Task {

                    isSending = true
                    errorMessage = nil

                    do {

                        if currentStatus == .requestReceived {

                            try await FriendService.acceptFriendRequest(
                                from: user.id
                            )

                            currentStatus = .friends


                        } else if currentStatus == .notFriends {

                            try await FriendService.sendFriendRequest(
                                to: user.id
                            )

                            currentStatus = .requestSent
                        }


                    } catch {

                        errorMessage =
                        "That didn't work: \(error.localizedDescription)"
                    }


                    isSending = false
                }


            } label: {

                if isSending {

                    ProgressView()
                        .inkButton()

                } else {

                    Text(buttonTitle)
                        .inkButton(isDisabled: currentStatus == .requestSent)
                }
            }
            .disabled(currentStatus == .requestSent)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)



            if let errorMessage {

                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }


            Spacer()
        }
        .padding(.horizontal, statsHorizontalPadding)
        .padding(.top)
        .task {
            postsCount = (try? await PostService.fetchUserPosts(uid: user.id))?.count ?? 0
        }
        .fullScreenCover(isPresented: $showFullImage) {
            ProfileImageViewerView(user: user)
        }
    }

    /// Avatar (filling this section's height) + name/@username vertically
    /// centered beside it. Fixed at 1/5 of screen height. Tapping the
    /// avatar opens it full-screen via ProfileImageViewerView.
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
    /// real one via Edit Profile.
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
    /// Posts card shows COUNT ONLY — see file header note.
    private var statsSection: some View {
        HStack(spacing: statCardSpacing) {
            statCard(value: "\(postsCount)", label: "posts")
                .frame(width: statUnitWidth * 2, height: statsSectionHeight)

            statCard(value: "\(user.friendsCount)", label: "friends")
                .frame(width: statUnitWidth, height: statsSectionHeight)

            statCard(value: "\(user.displayStreak)", label: "streak")
                .frame(width: statUnitWidth, height: statsSectionHeight)
        }
    }

    private func statCard(value: String, label: String) -> some View {
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

    private var buttonTitle: String {

        switch currentStatus {

        case .requestSent:
            return "Request Sent"

        case .requestReceived:
            return "Accept Request"

        default:
            return "Add Friend"
        }
    }
}


#Preview {

    PrivateProfileView(
        user: User.MOCK_USERS[0],
        status: .notFriends
    )
}
