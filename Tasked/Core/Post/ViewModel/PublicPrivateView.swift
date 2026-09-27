//
//  PublicPrivateView.swift
//  Tasked
//
//  New (Public/private pass): sign-up step between CreatePasswordView and
//  CompleteSignUpView. Sets RegistrationViewModel.isPublicAccount, which
//  AuthService.createUser writes onto the new user's document as
//  isPublicAccount. Every post this account uploads afterward gets stamped
//  with that same value as its own isPublic field (UploadPostViewModel) —
//  the Firestore rules key off the post's own field, not a live lookup on
//  the user, so a post's visibility doesn't silently change if the account
//  setting is changed later.
//

import SwiftUI

struct PublicPrivateView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: RegistrationViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Public or private?")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)

            Text("You can change this later in Settings")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                optionCard(
                    title: "Public",
                    description: "Anyone can see your posts.",
                    icon: "globe",
                    isSelected: viewModel.isPublicAccount
                ) {
                    viewModel.isPublicAccount = true
                }

                optionCard(
                    title: "Private",
                    description: "Only friends you accept can see your posts.",
                    icon: "lock.fill",
                    isSelected: !viewModel.isPublicAccount
                ) {
                    viewModel.isPublicAccount = false
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)

            NavigationLink {
                CompleteSignUpView()
                    .navigationBarBackButtonHidden()
            } label: {
                Text("Next")
                    .inkButton()
            }
            .padding(.horizontal, 24)
            .padding(.vertical)

            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Image(systemName: "chevron.left")
                    .imageScale(.large)
                    .onTapGesture {
                        dismiss()
                    }
            }
        }
    }

    private func optionCard(
        title: String,
        description: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(description)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            }
            .foregroundStyle(isSelected ? Color(.systemBackground) : Color.primary)
            .padding(14)
            .background(isSelected ? Color.primary : Color(.systemBackground))
            .overlay(
                Rectangle().stroke(Color.primary, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PublicPrivateView()
        .environmentObject(RegistrationViewModel())
}
