//
//  EditProfilePictureViewModel.swift
//  Tasked
//
//  New in Feature 5B: handles ONLY picture selection, upload to Firebase Storage,
//  and updating profileImageUrl. No text fields here — see EditProfileViewModel.
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
        guard let uiImage = UIImage(data: data) else {
            errorMessage = "That file isn't a supported image."
            return
        }

        self.uiImage = uiImage
        self.previewImage = Image(uiImage: uiImage)
        self.errorMessage = nil
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
