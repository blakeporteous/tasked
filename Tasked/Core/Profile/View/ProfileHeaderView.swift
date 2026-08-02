//
//  ProfileHeaderView.swift
//  Tasked
//
//  Updated profile layout:
//  - Centered profile picture
//  - Username underneath
//  - Simple Friends: number display
//

import SwiftUI

struct ProfileHeaderView: View {
    @StateObject private var viewModel: ProfileHeaderViewModel
    @State private var showFriends = false

    init(user: User) {
        _viewModel = StateObject(wrappedValue: ProfileHeaderViewModel(user: user))
    }

    private var user: User {
        viewModel.user
    }

    var body: some View {
        VStack(spacing: 14) {

            // Profile picture
            CircularProfileImageView(user: user, size: .large)
                .padding(.top, 20)

            // Username
            Text(user.username)
                .font(.title2)
                .fontWeight(.bold)

            // Friends count
            Button {
                showFriends = true
            } label: {
                Text("Friends: \(user.friendsCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)


            // Bio
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }


            // Friend actions
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
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(primaryButtonColor)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }


                        if viewModel.status == .requestReceived {

                            Button {
                                viewModel.decline()
                            } label: {
                                Text("Decline")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(Color(.systemGray5))
                                    .foregroundStyle(.primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }


            if let errorMessage = viewModel.errorMessage {

                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }


            Divider()
                .padding(.top, 8)
        }
        .navigationDestination(isPresented: $showFriends) {
            FriendsView(user: user)
        }
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


    private var primaryButtonColor: Color {

        switch viewModel.status {

        case .notFriends:
            return .blue

        case .requestReceived:
            return .blue

        case .requestSent:
            return Color(.systemGray3)

        case .friends:
            return Color(.systemGray3)

        case .isCurrentUser:
            return .clear
        }
    }
}


#Preview {
    ProfileHeaderView(user: User.MOCK_USERS[0])
}
