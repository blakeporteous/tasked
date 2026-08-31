//
//  EditProfilePictureViewModel.swift
//  Tasked
//
//  New in Feature 5B: handles ONLY picture selection, upload to Firebase Storage,
//  and updating profileImageUrl. No text fields here — see EditProfileViewModel.
//  Updated (Crop pass): a picked photo no longer goes straight to previewImage.
//  It's held in `rawPickedImage` and routed through ImageCropperView first
//  (presented by EditProfilePictureView) so every profile picture is a
//  consistent, size-capped square instead of whatever raw resolution/aspect
//  ratio the photo came in at.
//

import Foundation
import PhotosUI
import SwiftUI
import Firebase

@MainActor
class EditProfilePictureViewModel: ObservableObject {
    @Published var user: User
    @Published var selectedImage: PhotosPickerItem? {
        didSet { Task { await loadImage(fromItem: selectedImage) } }
    }
    /// Freshly picked, not-yet-cropped photo. EditProfilePictureView watches
    /// this to know when to present the cropper.
    @Published var rawPickedImage: UIImage?
    @Published var showCropper = false

    @Published var previewImage: Image?
    @Published var isSaving = false
    @Published var errorMessage: String?

    private var uiImage: UIImage?

    init(user: User) {
        self.user = user
    }

    func loadImage(fromItem item: PhotosPickerItem?) async {
        guard let item = item else { return }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "Couldn't load that image. Try a different one."
            return
        }
        guard let picked = UIImage(data: data) else {
            errorMessage = "That file isn't a supported image."
            return
        }

        errorMessage = nil
        rawPickedImage = picked
        showCropper = true
    }

    /// Called by EditProfilePictureView once the crop sheet is dismissed,
    /// either with a finished square image or with nil if the user cancelled.
    func handleCropped(_ cropped: UIImage?) {
        rawPickedImage = nil
        showCropper = false

        guard let cropped else {
            selectedImage = nil
            return
        }

        uiImage = cropped
        previewImage = Image(uiImage: cropped)
        errorMessage = nil
    }

    /// Returns true on success so the view can dismiss.
    func save() async -> Bool {
        errorMessage = nil

        guard let uiImage = uiImage else {
            errorMessage = "Choose a photo first."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            guard let url = try await ImageUploader.uploadImage(image: uiImage) else {
                errorMessage = "Couldn't upload your photo. Check your connection and try again."
                return false
            }

            try await Firestore.firestore().collection("users").document(user.id).updateData(["profileImageUrl": url])

            var updatedUser = user
            updatedUser.profileImageUrl = url
            user = updatedUser
            AuthService.shared.currentUser = updatedUser

            return true
        } catch {
            errorMessage = "Couldn't save your photo: \(error.localizedDescription)"
            return false
        }
    }
}
