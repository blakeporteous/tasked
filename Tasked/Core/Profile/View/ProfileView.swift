//
//  ProfileView.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//  Updated: gates the full profile behind friendship status (Feature 5). Non-friends
//  see PrivateProfileView instead of the header/post grid.
//

import SwiftUI

struct ProfileView: View {
    let user: User
    @State private var status: FriendshipStatus?

    var body: some View {
        Group {
            if let status {
                switch status {
                case .friends, .isCurrentUser:
                    ScrollView {
                        ProfileHeaderView(user: user)
                        PostGridView(user: user)
                    }
                case .notFriends, .requestSent, .requestReceived:
                    PrivateProfileView(user: user, status: status)
                }
            } else {
                ProgressView()
                    .padding(.top, 40)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadStatus()
        }
    }

    private func loadStatus() async {
        guard let currentUser = AuthService.shared.currentUser else { return }
        status = (try? await FriendService.fetchStatus(with: user.id, currentUser: currentUser)) ?? .notFriends
    }
}

#Preview {
    ProfileView(user: User.MOCK_USERS[0])
}
