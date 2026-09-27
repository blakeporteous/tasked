//
//  EditProfilePictureView.swift
//  Tasked
//
//  New in Feature 5B: picture selection + upload only, no text fields.
//  Updated (Crop pass): picking a photo opens ImageCropperView full-screen
//  first, so every profile picture ends up a consistent, size-capped
//  square.
//  Updated (Recrop pass): an explicit "Recrop" button overlays the preview.
//  Updated (Reposition-existing pass): tapping the CURRENT profile picture
//  opens it directly in the cropper via viewModel.editExistingPhoto().
//  Updated (Settings template pass): rebuilt on the shared
//  SettingsDetailView template (SettingsTemplates.swift) instead of its own
//  hand-rolled header/ScrollView. The Cancel/Done actions that used to sit
//  in a manual top HStack now live in a proper navigation toolbar (matching
//  every other pushed settings screen), with the same save/dismiss logic
//  underneath.
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
        SettingsDetailView(title: "Profile Picture") {
            VStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let image = viewModel.previewImage {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 140, height: 140)
                                .clipShape(Rectangle())
                        } else if viewModel.user.profileImageUrl != nil {
                            // Existing photo — tapping it repositions/re-crops
                            // the CURRENT picture rather than opening the
                            // system photo picker.
                            CircularProfileImageView(user: viewModel.user, size: .large)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task { await viewModel.editExistingPhoto() }
                                }
                                .opacity(viewModel.isLoadingExistingPhoto ? 0.5 : 1)
                        } else {
                            CircularProfileImageView(user: viewModel.user, size: .large)
                        }
                    }

                    if viewModel.isLoadingExistingPhoto {
                        ProgressView()
                            .tint(.white)
                            .padding(8)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                    } else if viewModel.previewImage != nil {
                        Button {
                            viewModel.recrop()
                        } label: {
                            Image(systemName: "crop")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .offset(x: -4, y: -28)
                    }
                }

                if viewModel.previewImage == nil && viewModel.user.profileImageUrl != nil {
                    Text("Tap your photo to reposition it")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                PhotosPicker(selection: $viewModel.selectedImage, matching: .images) {
                    Text(viewModel.previewImage == nil && viewModel.user.profileImageUrl == nil
                         ? "Choose a new photo"
                         : "Choose a different photo")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
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
                            .fontWeight(.bold)
                    }
                }
                .disabled(viewModel.isSaving || viewModel.previewImage == nil)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showCropper) {
            if let raw = viewModel.rawPickedImage {
                ImageCropperView(image: raw, cropShape: .square) { cropped, _ in
                    viewModel.handleCropped(cropped)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { EditProfilePictureView(user: User.MOCK_USERS[0]) }
}
