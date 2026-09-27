//
//  NotificationsView.swift
//  Tasked
//
//  New in this pass (Feature 4). Reachable from the bell icon on the Home feed.
//  Marks everything as read as soon as the screen is shown, mirroring how most
//  social apps clear the badge on open rather than requiring a manual action.
//  Updated (Feed engagement pass): renders the new "comment" notification type
//  fired by PostService.addComment.
//  Updated (Notifications-Accept pass): a "friendRequestReceived" row now
//  offers Accept/Decline right there, instead of requiring a trip to
//  ActivityView.
//  Updated (Grouped redesign pass): the flat list is now split into time
//  sections via NotificationsViewModel.groupedNotifications ("Last 24
//  Hours", "Last 2 Days", "This Week", "This Month", "Older"). Rows were
//  restyled as soft rounded cards, with a type-specific colored icon badge
//  (red heart for likes, blue bubble for comments, green person for friend
//  activity) overlaid on the actor's avatar instead of a plain unread dot —
//  the unread state itself now shows as a small dot next to the timestamp
//  plus a faint accent tint on the whole card.
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var viewModel: NotificationsViewModel

    var body: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.horizontal, 24)
            } else if viewModel.notifications.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No notifications yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
            } else {
                List {
                    ForEach(viewModel.groupedNotifications) { section in
                        Section {
                            ForEach(section.notifications) { notification in
                                NotificationRow(notification: notification)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await viewModel.delete(notification) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text(section.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                                .padding(.leading, 4)
                                .padding(.bottom, 2)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.markAllRead()
        }
    }
}

private struct NotificationRow: View {
    let notification: AppNotification
    @State private var actor: User?

    /// Local outcome of responding to a friend request inline, if this row
    /// is one. Kept as view-local state (not written back to the
    /// notification itself) — the row just needs to reflect what YOU did
    /// with it during this session; the underlying friendRequests document
    /// is the real source of truth everywhere else (ActivityView, profile
    /// headers, etc.).
    private enum FriendRequestOutcome {
        case accepted
        case declined
    }
    @State private var outcome: FriendRequestOutcome?
    @State private var isResponding = false
    @State private var actionError: String?

    private var isFriendRequest: Bool {
        notification.type == NotificationType.friendRequestReceived
    }

    /// Small SF Symbol shown in a colored circle overlaying the actor's
    /// avatar — a quick visual "what kind of thing happened" cue, matching
    /// the icon already used for that action elsewhere (heart on FeedCell,
    /// ellipsis.bubble for comments, person for friend activity).
    private var badgeIcon: String {
        switch notification.type {
        case NotificationType.like:
            return "heart.fill"
        case NotificationType.comment:
            return "ellipsis.bubble.fill"
        case NotificationType.friendRequestReceived, NotificationType.friendRequestAccepted:
            return "person.fill"
        default:
            return "bell.fill"
        }
    }

    private var badgeColor: Color {
        switch notification.type {
        case NotificationType.like:
            return .red
        case NotificationType.comment:
            return Color.appAccent
        case NotificationType.friendRequestReceived, NotificationType.friendRequestAccepted:
            return .green
        default:
            return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let actor {
                    CircularProfileImageView(user: actor, size: .small)
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)
                }

                Image(systemName: badgeIcon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(badgeColor)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: 3, y: 3)
            }

            // Flexible: takes whatever space is left after the avatar and
            // the (fixed-size) trailing controls, and wraps/truncates
            // within that instead of pushing the buttons out of the row.
            VStack(alignment: .leading, spacing: 3) {
                Text(message)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(notification.timeAgo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if !notification.isRead {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 6, height: 6)
                    }
                }

                if let actionError {
                    Text(actionError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isFriendRequest {
                friendRequestControls
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .task {
            actor = try? await UserService.fetchUser(withUid: notification.actorUid)
        }
    }

    /// Custom capsule buttons rather than .buttonStyle(.borderedProminent) —
    /// the system style has no minimum width, so under any horizontal
    /// pressure (a long username, a small screen) it'll shrink "Accept"
    /// until the label wraps. .fixedSize() here pins each button to its
    /// natural size regardless of how little room the row has left.
    @ViewBuilder
    private var friendRequestControls: some View {
        switch outcome {
        case .accepted:
            Text("Accepted")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .fixedSize()

        case .declined:
            Text("Declined")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .fixedSize()

        case nil:
            if isResponding {
                ProgressView()
            } else {
                HStack(spacing: 8) {
                    Button {
                        Task { await respond(accept: true) }
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

                    Button {
                        Task { await respond(accept: false) }
                    } label: {
                        Text("Decline")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .fixedSize()
            }
        }
    }

    /// Accepts or declines straight from the notification, same calls
    /// ActivityView makes. Guarded by isResponding so a double-tap can't
    /// fire the request twice.
    private func respond(accept: Bool) async {
        guard !isResponding else { return }
        isResponding = true
        actionError = nil
        defer { isResponding = false }

        do {
            if accept {
                try await FriendService.acceptFriendRequest(from: notification.actorUid)
                outcome = .accepted
            } else {
                try await FriendService.declineFriendRequest(from: notification.actorUid)
                outcome = .declined
            }
        } catch {
            actionError = "That didn't work — try again."
        }
    }

    private var message: String {
        let name = actor?.username ?? "Someone"
        switch notification.type {
        case NotificationType.friendRequestReceived:
            return "\(name) sent you a friend request."
        case NotificationType.friendRequestAccepted:
            return "\(name) accepted your friend request."
        case NotificationType.like:
            return "\(name) liked your post."
        case NotificationType.comment:
            return "\(name) commented on your post."
        default:
            return "\(name) did something."
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(NotificationsViewModel())
    }
}
