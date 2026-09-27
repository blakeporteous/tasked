//
//  StoryBarView.swift
//  Tasked
//
//  Updated (Compact-row pass): cards are now sized dynamically so roughly
//  4.5 fit across the screen width (previously a fixed 104x156 showed
//  closer to 3). Avatar size dropped from .medium to .small to match the
//  smaller card footprint. The "+" add-story card now leads the row
//  (leftmost) instead of trailing it.
//  Updated (Rounder + avatar-position pass): cardCornerRadius increased
//  (18 -> 26) for a noticeably rounder card shape. The profile picture's
//  vertical position moved up slightly (75% -> 68% down the card) — still
//  off-center toward the bottom, just not as low as before.
//  Updated (Rounder-still pass): cardCornerRadius increased again
//  (26 -> 36) per request — cards now read as noticeably softer/rounder
//  still, closer to a squircle than the previous rounded-rect.

import SwiftUI
import Kingfisher

struct StoryBarView: View {
    let posts: [Post]
    let seenPostIds: Set<String>
    var onAddTapped: () -> Void = {}

    private let horizontalPadding: CGFloat = 16
    private let cardSpacing: CGFloat = 10
    /// How many cards should be visible across the screen at once — the
    /// ".5" is what makes the next one peek in as a scroll affordance.
    private let cardsVisible: CGFloat = 4.5
    private let cardCornerRadius: CGFloat = 36
    private let edgeBandWidth: CGFloat = 2

    /// Card width computed from the actual screen width so "4 and a half
    /// across" holds on any device, not just whatever this was tuned on.
    private var cardWidth: CGFloat {
        let availableWidth = UIScreen.main.bounds.width - (horizontalPadding * 2)
        let gapsVisible = cardsVisible.rounded(.down) // 4 full gaps for 4.5 cards
        return (availableWidth - cardSpacing * gapsVisible) / cardsVisible
    }

    /// Same width:height ratio the original fixed 104x156 cards used.
    private var cardHeight: CGFloat {
        cardWidth * 1.5
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: cardSpacing) {
                Button(action: onAddTapped) {
                    AddStoryCard(width: cardWidth, height: cardHeight, cornerRadius: cardCornerRadius)
                }
                .buttonStyle(.plain)

                ForEach(posts) { post in
                    if let user = post.user {
                        NavigationLink(value: user) {
                            StoryCard(
                                post: post,
                                user: user,
                                isSeen: seenPostIds.contains(post.id),
                                width: cardWidth,
                                height: cardHeight,
                                cornerRadius: cardCornerRadius,
                                edgeBandWidth: edgeBandWidth
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 10)
        }
        .animation(.easeInOut(duration: 0.35), value: seenPostIds)
    }
}

/// One story card: just the friend's post image with their profile picture
/// (sitting slightly below center, not dead-center) in a ring that signals
/// seen/unseen (blue = unseen, white = seen). No name label underneath.
private struct StoryCard: View {
    let post: Post
    let user: User
    let isSeen: Bool
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let edgeBandWidth: CGFloat

    private var ringColor: Color {
        isSeen ? Color.white.opacity(0.9) : Color.appAccent
    }

    var body: some View {
        ZStack {
            KFImage(URL(string: post.imageUrl))
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: edgeBandWidth)
                        .allowsHitTesting(false)
                )

            CircularProfileImageView(user: user, size: .small)
                .overlay(Circle().stroke(ringColor, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .position(x: width / 2, y: height * 0.68)
        }
        .frame(width: width, height: height)
    }
}

/// Leading "add a post" card — dashed border + plus glyph, same footprint
/// as a story card so it sits naturally at the front of the row.
private struct AddStoryCard: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray6))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(Color(.systemGray3))
            )
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: min(width, height) * 0.32, weight: .semibold))
                    .foregroundStyle(Color(.systemGray))
            )
    }
}

#Preview {
    NavigationStack {
        StoryBarView(posts: Post.MOCK_POSTS, seenPostIds: [Post.MOCK_POSTS[1].id])
    }
}
