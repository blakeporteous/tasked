//
//  EditProfileView.swift
//  Tasked
//
//  Rewritten for Feature 5A: text fields only (username, name, bio). Picture
//  editing lives in EditProfilePictureView now. Reachable only from Settings.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: EditProfileViewModel

    init(user: User) {
        self._viewModel = StateObject(wrappedValue: EditProfileViewModel(user: user))
    }

    var body: some View {
        VStack {
            VStack {
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }

                    Spacer()

                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Done")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
                .padding()

                Divider()
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            VStack {
                EditProfileRowView(title: "Username", placeholder: "Enter your username...", text: $viewModel.username)
                EditProfileRowView(title: "Name", placeholder: "Enter your name...", text: $viewModel.fullname)
                EditProfileRowView(title: "Bio", placeholder: "Enter your bio...", text: $viewModel.bio)
            }
            .padding(.top, 8)

            Spacer()
        }
    }
}

struct EditProfileRowView: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(title)
                .padding(.leading, 8)
                .frame(width: 100, alignment: .leading)
            VStack {
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled(title == "Username")
                    .textInputAutocapitalization(title == "Username" ? .never : .sentences)
                Divider()
            }
            .font(.subheadline)
            .frame(height: 36)
        }
    }
}

#Preview {
    EditProfileView(user: User.MOCK_USERS[0])
}
