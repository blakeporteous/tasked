//
//  FeedCell.swift
//  Tasked
//
//  Updated (Card revamp pass 11 — tighter spacing):
//  - cardHorizontalMargin (screen edge -> card) tightened 24 -> 16.
//  - leadingInset/imageSideInset (card edge -> avatar/image/icons) tightened
//    12 -> 8, trailingInset 4 -> 2, nudgeRight 6 -> 4.
//  - Vertical gap between the image and the icon row underneath it
//    tightened 14 -> 10.
//  Updated (Trailing breathing-room pass): trailingInset bumped 2 -> 14.
//  Updated (Icon swap pass): share icon switched to "arrowshape.turn.up.right",
//  comment icon to "ellipsis.bubble". Like/comment counts hidden when 0.
//  Updated (Comment-count sync pass): onCommentCountChange keeps the count
//  shown on this card in sync with the comments sheet.
//  Updated (Footer removal pass): dropped the "View all N comments" link.
//  Updated (Share fix pass): share now hands ShareLink the actual photo
//  (viewModel.shareableImage, from Kingfisher's cache) instead of a bare
//  Firebase Storage URL, falling back to the URL if the image isn't cached
//  yet.
//  Updated (Block user pass): added onBlock, fired (with the blocked User)
//  once PostOptionsMenu's new "Block User" action is confirmed and the
//  block actually succeeds — lets whichever screen is holding this cell
//  (FeedView/PostFeedView/MonthPostsView) drop that user's posts from its
//  own local array immediately.
//

import SwiftUI
import Kingfisher

struct FeedCell: View {
    @StateObject private var viewModel: FeedCellViewModel
    @State private var showComments = false
    @State private var showDeleteConfirmation = false
    @State private var showBlockConfirmation = false
    private let onDelete: ((Post) -> Void)?
    private let onBlock: ((User) -> Void)?

    init(post: Post, onDelete: ((Post) -> Void)? = nil, onBlock: ((User) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: FeedCellViewModel(post: post))
        self.onDelete = onDelete
        self.onBlock = onBlock
    }

    private var post: Post { viewModel.post }

    private let cardCornerRadius: CGFloat = 32
    private let imageCornerRadius: CGFloat = 28
    private let iconSize: CGFloat = 20

    /// Width : height. 5:4 (1.25) is wider than it is tall.
    private let imageAspectRatio: CGFloat = 5.0 / 4.0

    /// Width of the light edge band drawn around the image, in points.
    private let edgeBandWidth: CGFloat = 2

    /// Space between the screen edge and the card itself.
    private let cardHorizontalMargin: CGFloat = 16
    /// Space between the card's own edge and its LEADING content (avatar,
    /// image's left side).
    private let leadingInset: CGFloat = 8
    /// Space between the card's own edge and its TRAILING content ("..."
    /// menu, share icon).
    private let trailingInset: CGFloat = 14
    /// The image itself still gets a symmetric inset on both sides — only
    /// the icon ROWS use the asymmetric leading/trailing insets above.
    private let imageSideInset: CGFloat = 8
    /// Vertical gap between the image and the icon row directly beneath it.
    private let imageToIconsGap: CGFloat = 10
    /// Extra nudge-right applied to just the avatar and the heart button.
    private let nudgeRight: CGFloat = 4

    /// Explicit width for the image, computed the same way PostGridView
    /// already sizes its own tiles.
    private var imageWidth: CGFloat {
        UIScreen.main.bounds.width - (cardHorizontalMargin * 2) - (imageSideInset * 2)
    }

    private var imageHeight: CGFloat {
        imageWidth / imageAspectRatio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            if let user = post.user {
                HStack(alignment: .center, spacing: 0) {
                    NavigationLink(value: user) {
                        CircularProfileImageView(user: user, size: .xSmall)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, nudgeRight)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    NavigationLink(value: user) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.username)
                                .font(.title2)
                                .fontWeight(.heavy)
                                .foregroundStyle(.primary)

                            if let location = post.location, !location.isEmpty {
                                Text(location)
                                    .font(.caption)
                                    .foregroundStyle(Color(.systemGray))
                            }
                        }
                        .padding(.leading, 10)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    PostOptionsMenu(
                        isOwnPost: viewModel.isOwnPost,
                        onDelete: { showDeleteConfirmation = true },
                        onReport: { reason in
                            Task { await viewModel.reportPost(reason: reason) }
                        },
                        onBlock: { showBlockConfirmation = true }
                    )
                }
                .padding(.leading, leadingInset)
                .padding(.trailing, trailingInset)
                .padding(.top, leadingInset)
                .padding(.bottom, imageToIconsGap)
            }

            KFImage(URL(string: post.imageUrl))
                .resizable()
                .scaledToFill()
                .frame(width: imageWidth, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
                .overlay(
                    // strokeBorder draws the whole band INSET from the
                    // shape's own edge, so all of it sits on top of the
                    // image rather than bleeding outside the rounded
                    // corners.
                    RoundedRectangle(cornerRadius: imageCornerRadius)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: edgeBandWidth)
                        .allowsHitTesting(false)
                )
                .clipped()
                .padding(.horizontal, imageSideInset)

            HStack(spacing: 0) {
                HStack(spacing: 18) {
                    Button {
                        viewModel.toggleLike()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                                .font(.system(size: iconSize))
                                .foregroundStyle(viewModel.isLiked ? .red : Color(.systemGray))
                            if post.likes > 0 {
                                Text("\(post.likes)")
                                    .font(.footnote)
                                    .foregroundStyle(Color(.systemGray))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, nudgeRight)

                    Button {
                        showComments = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "ellipsis.bubble")
                                .font(.system(size: iconSize))
                                .foregroundStyle(Color(.systemGray))
                            if post.commentsCount > 0 {
                                Text("\(post.commentsCount)")
                                    .font(.footnote)
                                    .foregroundStyle(Color(.systemGray))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let shareable = viewModel.shareableImage {
                    ShareLink(
                        item: shareable,
                        preview: SharePreview(shareable.caption, image: Image(uiImage: shareable.image))
                    ) {
                        Image(systemName: "arrowshape.turn.up.right")
                            .font(.system(size: iconSize))
                            .foregroundStyle(Color(.systemGray))
                    }
                } else if let shareURL = URL(string: post.imageUrl) {
                    // Fallback for the rare case the image hasn't finished
                    // loading into Kingfisher's cache yet — shares the link
                    // rather than blocking on a fresh download.
                    ShareLink(item: shareURL) {
                        Image(systemName: "arrowshape.turn.up.right")
                            .font(.system(size: iconSize))
                            .foregroundStyle(Color(.systemGray))
                    }
                }
            }
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .padding(.top, imageToIconsGap)

            Spacer().frame(height: leadingInset)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .padding(.horizontal, cardHorizontalMargin)
        .opacity(viewModel.isDeleting ? 0.4 : 1)
        .sheet(isPresented: $showComments) {
            CommentsView(post: post, onCommentCountChange: { newCount in
                viewModel.updateCommentsCount(newCount)
            })
        }
        .confirmationDialog(
            "Delete this post?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    let success = await viewModel.deletePost()
                    if success {
                        onDelete?(post)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .confirmationDialog(
            "Block \(post.user?.username ?? "this user")?",
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                Task {
                    if let blockedUser = await viewModel.blockUser() {
                        onBlock?(blockedUser)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see their posts anymore and you'll no longer be friends. They won't be notified.")
        }
        .alert(
            "Post Reported",
            isPresented: Binding(
                get: { viewModel.reportConfirmationMessage != nil },
                set: { if !$0 { viewModel.reportConfirmationMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.reportConfirmationMessage = nil }
        } message: {
            Text(viewModel.reportConfirmationMessage ?? "")
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}


#Preview {
    NavigationStack {
        FeedCell(post: Post.MOCK_POSTS[0])
    }
}
