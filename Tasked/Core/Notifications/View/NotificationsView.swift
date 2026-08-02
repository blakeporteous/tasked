//
//  NotificationsView.swift
//  Tasked
//
//  New in this pass (Feature 4). Reachable from the bell icon on the Home feed.
//  Marks everything as read as soon as the screen is shown, mirroring how most
//  social apps clear the badge on open rather than requiring a manual action.
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

    var body: some View {
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
        .padding(.vertical, 4)
        .task {
            actor = try? await UserService.fetchUser(withUid: notification.actorUid)
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
