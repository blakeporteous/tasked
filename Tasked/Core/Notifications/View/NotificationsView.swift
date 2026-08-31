//
//  NotificationsView.swift
//  Tasked
//
//  New in this pass (Feature 4). Reachable from the bell icon on the Home feed.
//  Marks everything as read as soon as the screen is shown, mirroring how most
//  social apps clear the badge on open rather than requiring a manual action.
//  Updated (Feed engagement pass): renders the new "comment" notification type
//  fired by PostService.addComment.
//  Updated (Notification actions pass): a "friendRequestReceived" row now gets
//  inline Accept/Decline buttons (same FriendService calls ActivityView already
//  uses) so people can respond right here instead of having to separately open
//  Friend Requests.
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
                Text("No notifications yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
            } else {
                List(viewModel.notifications) { notification in
                    NotificationRow(notification: notification)
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

    // Friend-request response state, local to this row. The notification
    // document itself doesn't track whether the request was answered, so
    // this only reflects what happened during this screen's lifetime — if
    // the request was already handled elsewhere (e.g. ActivityView), the
    // buttons will still show here until tapped, matching how the rest of
    // the app treats these as independent entry points into the same data.
    @State private var isResponding = false
    @State private var outcome: RequestOutcome?
    @State private var responseError: String?

    private enum RequestOutcome {
        case accepted
        case declined
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let actor {
                    CircularProfileImageView(user: actor, size: .xSmall)
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                }

                Text(message)
                    .font(.footnote)

                Spacer()

                if !notification.isRead {
                    Circle()
                        .fill(Color(.systemBlue))
                        .frame(width: 8, height: 8)
                }
            }

            if notification.type == NotificationType.friendRequestReceived {
                friendRequestActions
            }

            if let responseError {
                Text(responseError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 52)
            }
        }
        .padding(.vertical, 4)
        .task {
            actor = try? await UserService.fetchUser(withUid: notification.actorUid)
        }
    }

    @ViewBuilder
    private var friendRequestActions: some View {
        switch outcome {
        case .accepted:
            Text("Accepted")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 52)
        case .declined:
            Text("Declined")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 52)
        case nil:
            HStack(spacing: 10) {
                if isResponding {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Accept") {
                        Task { await respond(accept: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Decline") {
                        Task { await respond(accept: false) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.leading, 52)
        }
    }

    private func respond(accept: Bool) async {
        isResponding = true
        responseError = nil
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
            responseError = "That didn't work: \(error.localizedDescription)"
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
