//
//  PrivateProfileView.swift
//  Tasked
//
//  Private profile layout:
//  - Centered profile picture
//  - Username
//  - Friends: number
//  - Add friend button
//

import SwiftUI

struct PrivateProfileView: View {

    let user: User
    let status: FriendshipStatus

    @State private var currentStatus: FriendshipStatus
    @State private var isSending = false
    @State private var errorMessage: String?


    init(user: User, status: FriendshipStatus) {
        self.user = user
        self.status = status
        self._currentStatus = State(initialValue: status)
    }


    var body: some View {

        VStack(spacing: 16) {

            Spacer()
                .frame(height: 30)


            CircularProfileImageView(user: user, size: .large)


            Text(user.username)
                .font(.title2)
                .fontWeight(.bold)


            Button {

            } label: {

                Text("Friends: \(user.friendsCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

            }
            .buttonStyle(.plain)



            VStack(spacing: 8) {

                Image(systemName: "lock.fill")
                    .font(.title)

                Text("This profile is private")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)


                Text("Add \(user.username) as a friend to see their posts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

            }
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
                        .frame(width: 200, height: 40)

                } else {

                    Text(buttonTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 40)
                        .background(buttonColor)
                        .cornerRadius(8)
                }
            }
            .disabled(currentStatus == .requestSent)



            if let errorMessage {

                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }


            Spacer()
        }
        .padding(.top)
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



    private var buttonColor: Color {

        switch currentStatus {

        case .requestSent:
            return Color(.systemGray3)

        default:
            return .blue
        }
    }
}


#Preview {

    PrivateProfileView(
        user: User.MOCK_USERS[0],
        status: .notFriends
    )
}
