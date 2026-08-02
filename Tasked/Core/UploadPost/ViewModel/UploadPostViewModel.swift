//
//  UploadPostViewModel.swift
//  Tasked
//
//  Created by Blake Porteous on 24/03/2025.
//  Updated: manual captions removed — the caption is now automatically the
//  active weekly task's title, denormalized onto the post at upload time so
//  older posts keep the task that was active when they were shared (Feature 3).
//  Also adds upload progress/error state for the redesigned Create Post screen (Feature 7).
//

import Foundation
import PhotosUI
import SwiftUI
import Firebase
import FirebaseAuth

@MainActor
class UploadPostViewModel: ObservableObject {

    @Published var selectedImage: PhotosPickerItem? {
        didSet { Task { await loadImage(fromItem: selectedImage) } }
    }
    @Published var postImage: Image?
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var currentTask: WeeklyTask?

    private var uiImage: UIImage?

    init() {
        Task { await loadCurrentTask() }
    }

    func loadCurrentTask() async {
        currentTask = try? await WeeklyTaskService.fetchCurrentTask()
        if currentTask == nil {
            errorMessage = "No active weekly task right now — check back soon."
        }
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
        self.postImage = Image(uiImage: uiImage)
        self.errorMessage = nil
    }

    func uploadPost() async throws {
        errorMessage = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You need to be signed in to post."
            return
        }
        guard let uiImage = uiImage else {
            errorMessage = "Choose a photo before posting."
            return
        }
        guard let task = currentTask else {
            errorMessage = "No active weekly task found. Try again shortly."
            return
        }

        isUploading = true
        uploadProgress = 0.2
        defer { isUploading = false }

        guard let imageUrl = try await ImageUploader.uploadImage(image: uiImage) else {
            errorMessage = "Couldn't upload your photo. Check your connection and try again."
            return
        }
        uploadProgress = 0.7

        let postRef = Firestore.firestore().collection("posts").document()
        let post = Post(
            id: postRef.documentID,
            ownerUid: uid,
            taskId: task.id,
            caption: task.title,
            likes: 0,
            imageUrl: imageUrl,
            timestamp: Timestamp()
        )

        guard let encodedPost = try? Firestore.Encoder().encode(post) else {
            errorMessage = "Something went wrong preparing your post."
            return
        }

        try await postRef.setData(encodedPost)
        uploadProgress = 1.0
        reset()
    }

    func reset() {
        selectedImage = nil
        postImage = nil
        uiImage = nil
        uploadProgress = 0
    }
}
