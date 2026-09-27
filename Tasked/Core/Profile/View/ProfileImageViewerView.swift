//
//  ProfileImageViewerView.swift
//  Tasked
//
//  New (Profile-picture viewer pass): full-screen viewer opened by tapping
//  a profile picture — shows it large, centered, on a black background.
//  Tapping anywhere (or the close button) dismisses. Used by
//  ProfileHeaderView and PrivateProfileView.
//

import SwiftUI
import Kingfisher

struct ProfileImageViewerView: View {
    @Environment(\.dismiss) var dismiss
    let user: User

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let imageURL = user.profileImageUrl {
                KFImage(URL(string: imageURL))
                    .resizable()
                    .scaledToFit()
                    .clipShape(Circle())
                    .padding(40)
            } else {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color(.systemGray))
                            .padding(60)
                    )
                    .padding(40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .padding()
        }
    }
}

#Preview {
    ProfileImageViewerView(user: User.MOCK_USERS[0])
}
