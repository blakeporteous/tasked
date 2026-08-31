//
//  EditProfilePictureView.swift
//  Tasked
//
//  New in Feature 5B: picture selection + upload only, no text fields.
//  Updated (Crop pass): picking a photo now opens ImageCropperView full-screen
//  (with a circular preview, matching CircularProfileImageView) before it
//  becomes the profile picture, so every profile picture ends up as a
//  consistent, size-capped square instead of the raw picked photo.
//

import SwiftUI
import PhotosUI

struct EditProfilePictureView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: EditProfilePictureViewModel

    init(user: User) {
        self._viewModel = StateObject(wrappedValue: EditProfilePictureViewModel(user: user))
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Profile Picture")
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
                .disabled(viewModel.isSaving || viewModel.previewImage == nil)
            }
            .padding()

            Divider()

            PhotosPicker(selection: $viewModel.selectedImage, matching: .images) {
                VStack(spacing: 12) {
                    if let image = viewModel.previewImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    } else {
                        CircularProfileImageView(user: viewModel.user, size: .large)
                    }

                    Text(viewModel.previewImage == nil ? "Choose a new photo" : "Choose a different photo")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .fullScreenCover(isPresented: $viewModel.showCropper) {
            if let raw = viewModel.rawPickedImage {
                ImageCropperView(image: raw, cropShape: .circle) { cropped in
                    viewModel.handleCropped(cropped)
                }
            }
        }
    }
}

#Preview {
    EditProfilePictureView(user: User.MOCK_USERS[0])
}
