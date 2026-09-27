//
//  EditProfileViewModel.swift
//  Tasked
//
//  Rewritten for Feature 5A: this view model now ONLY handles text fields
//  (username, bio). Profile picture editing moved to
//  EditProfilePictureViewModel.
//  Updated (Single-lowercase-username pass): username force-lowercases
//  itself as it's typed; save() writes only `username`, always lowercase.
//  Updated (Drop fullname pass): removed fullname entirely — it was never
//  collected at sign-up and wasn't used anywhere.
//  Updated (Username availability pass): username now runs the same
//  debounced Firestore availability check RegistrationViewModel uses at
//  sign-up. Skips the check entirely when the typed value matches the
//  user's CURRENT username (nothing to conflict with), and save() now
//  blocks while a check is in flight or if the last check came back taken —
//  mirrors CreateUsernameView's "Next" gating.
//  Updated (Profile revamp pass): added `location`, following the same
//  "diff against the loaded user, only write if changed" pattern bio
//  already uses.
//  Updated (Location pass): `location` is no longer free-typed — EditProfileView's
//  Location row now opens the same LocationPickerView (city search) used by
//  UploadPostView. applyLocation(name:coordinate:) sets `location` and the
//  new `locationLatitude`/`locationLongitude` together whenever a search
//  result is picked; save() diffs and writes all three the same way it
//  already did for the plain string.
//

import Foundation
import Firebase
import CoreLocation

@MainActor
class EditProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var username: String {
        didSet {
            let lowered = username.lowercased()
            if username != lowered {
                // Re-assigning triggers this didSet again; the recursive
                // call sees username already lowercase and falls through to
                // checkUsernameAvailability() below instead.
                username = lowered
                return
            }
            checkUsernameAvailability()
        }
    }
    @Published var bio: String
    @Published var location: String
    @Published var locationLatitude: Double?
    @Published var locationLongitude: Double?
    @Published var showLocationPicker = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    @Published var isCheckingUsername = false
    @Published var usernameError: String?

    private var usernameCheckTask: Task<Void, Never>?

    init(user: User) {
        self.user = user
        self.username = user.username
        self.bio = user.bio ?? ""
        self.location = user.location ?? ""
        self.locationLatitude = user.locationLatitude
        self.locationLongitude = user.locationLongitude
    }

    /// Called from LocationPickerView once a search result is tapped and
    /// resolved. Overwrites whatever was set before — the person can always
    /// tap the Location row again to pick a different one.
    func applyLocation(name: String, coordinate: CLLocationCoordinate2D) {
        location = name
        locationLatitude = coordinate.latitude
        locationLongitude = coordinate.longitude
    }

    /// Returns true on success so the view can dismiss.
    func save() async -> Bool {
        errorMessage = nil

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedUsername.isEmpty else {
            errorMessage = "Username can't be empty."
            return false
        }
        guard !isCheckingUsername else {
            errorMessage = "Still checking that username — try again in a moment."
            return false
        }
        guard usernameError == nil else {
            errorMessage = usernameError
            return false
        }

        var data: [String: Any] = [:]
        if trimmedUsername != user.username {
            data["username"] = trimmedUsername
        }
        if bio != (user.bio ?? "") {
            data["bio"] = bio
        }
        if location != (user.location ?? "") {
            data["location"] = location
        }
        if locationLatitude != user.locationLatitude {
            data["locationLatitude"] = locationLatitude ?? FieldValue.delete()
        }
        if locationLongitude != user.locationLongitude {
            data["locationLongitude"] = locationLongitude ?? FieldValue.delete()
        }

        guard !data.isEmpty else { return true } // nothing changed

        isSaving = true
        defer { isSaving = false }

        do {
            try await Firestore.firestore().collection("users").document(user.id).updateData(data)

            var updatedUser = user
            updatedUser.username = trimmedUsername
            updatedUser.bio = bio.isEmpty ? nil : bio
            updatedUser.location = location.isEmpty ? nil : location
            updatedUser.locationLatitude = locationLatitude
            updatedUser.locationLongitude = locationLongitude
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
    /// Debounced check against Firestore, same pattern (and 400ms delay) as
    /// RegistrationViewModel's sign-up check. Skips the network call
    /// entirely when the typed value is just the user's own current
    /// username — that's always "available" to them.
    /// Updated (Availability-race fix): same fix as RegistrationViewModel —
    /// isCheckingUsername now flips true synchronously before the debounce
    /// delay, not inside the Task after it, closing the brief window where
    /// an already-taken username looked available right after autofill.
    private func checkUsernameAvailability() {
        usernameCheckTask?.cancel()
        let candidate = username.trimmingCharacters(in: .whitespaces)

        guard !candidate.isEmpty else {
            usernameError = nil
            isCheckingUsername = false
            return
        }

        guard candidate != user.username else {
            usernameError = nil
            isCheckingUsername = false
            return
        }

        isCheckingUsername = true
        usernameError = nil

        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            defer { isCheckingUsername = false }

            do {
                if try await UserService.isUsernameTaken(candidate) {
                    usernameError = "That username is already taken."
                } else {
                    usernameError = nil
                }
            } catch {
                // Fail open — the profile-update write is still the source of truth.
                usernameError = nil
            }
        }
    }
}
