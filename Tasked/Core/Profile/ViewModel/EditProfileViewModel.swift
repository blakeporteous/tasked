//
//  EditProfileViewModel.swift
//  Tasked
//
//  Rewritten for Feature 5A: this view model now ONLY handles text fields
//  (username, fullname, bio). Profile picture editing moved to
//  EditProfilePictureViewModel so the two flows can't be conflated again.
//

import Foundation
import Firebase

@MainActor
class EditProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var username: String
    @Published var fullname: String
    @Published var bio: String
    @Published var isSaving = false
    @Published var errorMessage: String?

    init(user: User) {
        self.user = user
        self.username = user.username
        self.fullname = user.fullname ?? ""
        self.bio = user.bio ?? ""
    }

    /// Returns true on success so the view can dismiss.
    func save() async -> Bool {
        errorMessage = nil

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        guard !trimmedUsername.isEmpty else {
            errorMessage = "Username can't be empty."
            return false
        }

        var data: [String: Any] = [:]
        if trimmedUsername != user.username {
            data["username"] = trimmedUsername
            // Keeps UserService.searchUsers working after a rename.
            data["usernameLower"] = trimmedUsername.lowercased()
        }
        if fullname != (user.fullname ?? "") {
            data["fullname"] = fullname
        }
        if bio != (user.bio ?? "") {
            data["bio"] = bio
        }

        guard !data.isEmpty else { return true } // nothing changed

        isSaving = true
        defer { isSaving = false }

        do {
            try await Firestore.firestore().collection("users").document(user.id).updateData(data)

            var updatedUser = user
            updatedUser.username = trimmedUsername
            updatedUser.fullname = fullname.isEmpty ? nil : fullname
            updatedUser.bio = bio.isEmpty ? nil : bio
            user = updatedUser

            // Push the change up so Feed/Search/Profile all reflect it immediately
            // without needing a fresh fetch.
            AuthService.shared.currentUser = updatedUser

            return true
        } catch {
            errorMessage = "Couldn't save changes: \(error.localizedDescription)"
            return false
        }
    }
}
