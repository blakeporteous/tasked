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
//  Updated (Recrop pass): rawPickedImage is now kept around as long as a
//  photo is picked, so recrop() can reopen ImageCropperView on the same
//  original image at any time.
//  Updated (Reposition-existing pass): added editExistingPhoto(), called
//  when someone taps their CURRENT profile picture (rather than "Choose a
//  new photo"). Downloads the already-uploaded image and opens it straight
//  in the cropper so it can be dragged/pinched into a new position/zoom
//  without picking a new file from the library — this is what actually
//  saves as `uiImage` if "Done" is tapped afterward, same as any other
//  cropped selection.
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
    /// The original, uncropped photo currently picked (or, if the person
    /// tapped their existing picture to reposition it, that downloaded
    /// photo). Kept around for the lifetime of the current selection so
    /// recrop() can reopen the cropper on it at any time.
    @Published var rawPickedImage: UIImage?
    @Published var showCropper = false

    @Published var previewImage: Image?
    @Published var isSaving = false
    /// True while the existing profile picture is being downloaded so it can
    /// be reopened in the cropper — drives a small spinner over the picture.
    @Published var isLoadingExistingPhoto = false
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

    /// Downloads the CURRENT profile picture (whatever's already uploaded)
    /// and opens it directly in the cropper, so it can be dragged/pinched
    /// into a new crop without picking a new photo from the library. No-op
    /// if there's no existing picture, or if a new one has already been
    /// picked/cropped this session (avoids clobbering that in-progress edit).
    func editExistingPhoto() async {
        guard rawPickedImage == nil, previewImage == nil else { return }
        guard let urlString = user.profileImageUrl, let url = URL(string: urlString) else { return }

        isLoadingExistingPhoto = true
        errorMessage = nil
        defer { isLoadingExistingPhoto = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                errorMessage = "Couldn't load your current photo."
                return
            }
            rawPickedImage = image
            showCropper = true
        } catch {
            errorMessage = "Couldn't load your current photo."
        }
    }

    /// Called by EditProfilePictureView once the crop sheet is dismissed,
    /// either with a finished square image or with nil if the user cancelled.
    func handleCropped(_ cropped: UIImage?) {
        showCropper = false

        guard let cropped else {
            // Cancelling on a brand-new pick (or a reposition of the
            // existing photo) with no prior successful crop to fall back to
            // just clears the in-progress selection — the view reverts to
            // showing the existing profileImageUrl as before. Cancelling a
            // RECROP of an already-cropped photo just leaves the existing
            // previewImage/rawPickedImage as they were.
            if previewImage == nil {
                rawPickedImage = nil
                selectedImage = nil
            }
            return
        }

        uiImage = cropped
        previewImage = Image(uiImage: cropped)
        errorMessage = nil
        // rawPickedImage is deliberately NOT cleared here — it's what lets
        // recrop() reopen the cropper on this same original photo later.
    }

    /// Reopens the cropper on the currently picked (or downloaded-existing)
    /// photo without going back through the system photo picker. No-op if
    /// nothing's been picked/loaded yet.
    func recrop() {
        guard rawPickedImage != nil else { return }
        showCropper = true
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
