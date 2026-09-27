//
//  UploadPostViewModel.swift
//  Tasked
//
//  (earlier header comments unchanged — trimmed here for brevity)
//  Updated (New Post revamp pass): added `aspectRatio` (defaults to
//  .feed, matching FeedCell's own display ratio), set from whichever
//  ratio ImageCropperView's new picker was on when "Choose" was tapped —
//  handleCropped(_:aspectRatio:) replaces the old single-argument version.
//  Also added `hideLikeCount`/`commentsDisabled` — UI-only "Advanced
//  options" toggles for now (Post.swift has no matching fields yet), same
//  affordance-now-wiring-later pattern already used by PostingSettingsViews.
//  Updated (Location pass): added `selectedLocationName`/
//  `selectedLocationCoordinate` + `showLocationPicker`. loadImage(fromItem:)
//  now also tries to auto-detect a location straight from the picked
//  photo's embedded GPS EXIF data (no photo-library permission needed —
//  this reads the coordinate directly out of the image bytes the picker
//  already handed over) and reverse-geocodes it to a display name via
//  CLGeocoder. That's only ever a starting guess: applyLocation(name:
//  coordinate:) (called from LocationPickerView) overwrites it any time the
//  person picks one manually instead, and a fresh photo pick clears
//  whatever was set for the previous one.
//

import Foundation
import Combine
import PhotosUI
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import MapKit
import ImageIO

@MainActor
class UploadPostViewModel: ObservableObject {

    @Published var selectedImage: PhotosPickerItem? {
        didSet { Task { await loadImage(fromItem: selectedImage) } }
    }
    /// The original, uncropped photo currently picked. Kept around for the
    /// lifetime of the current selection so recrop() can reopen
    /// ImageCropperView on it at any time.
    @Published var rawPickedImage: UIImage?
    @Published var showCropper = false

    @Published var postImage: Image?
    /// Which aspect ratio the current postImage was cropped at — drives the
    /// preview frame's shape on UploadPostView and is passed back into
    /// ImageCropperView as the starting ratio on Recrop. Defaults to
    /// .feed, matching FeedCell's own image frame exactly.
    @Published var aspectRatio: CropAspectRatio = .feed

    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var currentTask: WeeklyTask?

    /// UI-only for now — Post.swift has no matching fields, so these don't
    /// affect what actually gets written on upload yet.
    @Published var hideLikeCount = false
    @Published var commentsDisabled = false

    /// Display name for where this post is tagged — either auto-detected
    /// from the photo's GPS data or picked manually via LocationPickerView.
    /// nil until one of those happens.
    @Published var selectedLocationName: String?
    @Published var selectedLocationCoordinate: CLLocationCoordinate2D?
    @Published var showLocationPicker = false

    /// True once the signed-in user has already posted during the current
    /// Monday-Sunday week.
    @Published var hasPostedThisWeek = false

    private var uiImage: UIImage?
    private var cancellables = Set<AnyCancellable>()

    init() {
        Task { await loadCurrentTask() }
        observeCurrentUser()
    }

    func loadCurrentTask() async {
        do {
            currentTask = try await WeeklyTaskService.fetchCurrentTask()
            if currentTask == nil {
                errorMessage = "No active weekly task right now — check back soon."
            }
        } catch {
            print("DEBUG: fetchCurrentTask failed — \(error)")
            errorMessage = "Couldn't load this week's task: \(error.localizedDescription)"
        }
    }

    private func observeCurrentUser() {
        AuthService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.recomputeHasPostedThisWeek(user: user)
            }
            .store(in: &cancellables)
    }

    private func recomputeHasPostedThisWeek(user: User?) {
        guard let lastPostWeekStart = user?.lastPostWeekStart?.dateValue() else {
            hasPostedThisWeek = false
            return
        }
        let currentWeekStart = DateWeek.startOfWeek(containing: Date())
        hasPostedThisWeek = lastPostWeekStart == currentWeekStart
    }

    func refreshHasPostedThisWeek() {
        recomputeHasPostedThisWeek(user: AuthService.shared.currentUser)
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

        // Fresh photo — whatever location was set for the previous one no
        // longer applies. Try to fill in a new starting guess from this
        // photo's own GPS metadata; the person can always override it (or
        // add one) manually via the Location row either way.
        selectedLocationName = nil
        selectedLocationCoordinate = nil
        Task { await autoDetectLocation(from: data) }
    }

    /// Called by UploadPostView once the crop sheet is dismissed, with the
    /// finished image (or nil if cancelled) and whichever aspect ratio was
    /// selected in the cropper at that point.
    func handleCropped(_ cropped: UIImage?, aspectRatio: CropAspectRatio) {
        showCropper = false
        self.aspectRatio = aspectRatio

        guard let cropped else {
            if postImage == nil {
                rawPickedImage = nil
                selectedImage = nil
            }
            return
        }

        uiImage = cropped
        postImage = Image(uiImage: cropped)
        errorMessage = nil
    }

    /// Reopens the cropper on the currently picked photo, starting on
    /// whichever ratio is currently set, without going back through the
    /// system photo picker.
    func recrop() {
        guard rawPickedImage != nil else { return }
        showCropper = true
    }

    // MARK: - Location

    /// Called from LocationPickerView once a search result is tapped and
    /// resolved. Overwrites whatever auto-detected (or previously picked)
    /// location was set.
    func applyLocation(name: String, coordinate: CLLocationCoordinate2D) {
        selectedLocationName = name
        selectedLocationCoordinate = coordinate
    }

    func clearLocation() {
        selectedLocationName = nil
        selectedLocationCoordinate = nil
    }

    /// Reads embedded GPS EXIF data straight out of the picked photo's raw
    /// bytes (no photo-library permission needed — this is just parsing the
    /// image data the picker already handed over) and, if present,
    /// reverse-geocodes it into a display name. No-ops silently if the
    /// photo has no GPS data (most screenshots/downloaded images won't) or
    /// the person has since picked a different photo/location already.
    private func autoDetectLocation(from data: Data) async {
        guard let coordinate = extractGPSCoordinate(from: data) else { return }

        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else { return }

        // Don't clobber a manual pick the person made while this was
        // resolving in the background.
        guard selectedLocationName == nil else { return }

        let name = LocationSearchViewModel.displayName(for: MKPlacemark(placemark: placemark), fallback: "")
        guard !name.isEmpty else { return }

        selectedLocationName = name
        selectedLocationCoordinate = coordinate
    }

    private func extractGPSCoordinate(from data: Data) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
              let longitude = gps[kCGImagePropertyGPSLongitude] as? Double,
              let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
        else { return nil }

        let lat = latitudeRef == "S" ? -latitude : latitude
        let lon = longitudeRef == "W" ? -longitude : longitude
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func uploadPost() async throws {
        errorMessage = nil

        guard !hasPostedThisWeek else {
            errorMessage = "You've already posted this week. Check back next week!"
            return
        }
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

        let postId = Firestore.firestore().collection("posts").document().documentID
        let timestamp = Timestamp()
        let post = Post(
            id: postId,
            ownerUid: uid,
            taskId: task.id,
            caption: task.title,
            likes: 0,
            isPublic: AuthService.shared.currentUser?.isPublicAccount ?? true,
            location: selectedLocationName,
            locationLatitude: selectedLocationCoordinate?.latitude,
            locationLongitude: selectedLocationCoordinate?.longitude,
            imageUrl: imageUrl,
            timestamp: timestamp
        )

        do {
            let newStreak = try await PostService.createPost(post, ownerUid: uid)

            if var updatedUser = AuthService.shared.currentUser {
                updatedUser.currentStreak = newStreak
                updatedUser.lastPostWeekStart = Timestamp(date: DateWeek.startOfWeek(containing: timestamp.dateValue()))
                AuthService.shared.currentUser = updatedUser
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == FirestoreErrorDomain && nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                refreshHasPostedThisWeek()
                errorMessage = "You've already posted this week. Check back next week!"
            } else {
                errorMessage = "Couldn't create your post: \(error.localizedDescription)"
            }
            return
        }

        uploadProgress = 1.0
        reset()
    }

    func reset() {
        selectedImage = nil
        rawPickedImage = nil
        showCropper = false
        postImage = nil
        uiImage = nil
        uploadProgress = 0
        aspectRatio = .feed
        hideLikeCount = false
        commentsDisabled = false
        selectedLocationName = nil
        selectedLocationCoordinate = nil
    }
}
