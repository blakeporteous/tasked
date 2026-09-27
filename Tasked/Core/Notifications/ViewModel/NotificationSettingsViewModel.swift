//
//  NotificationSettingsViewModel.swift
//  Tasked
//
//  New: backs NotificationSettingsView. Loads from
//  AuthService.currentUser.notificationPreferences and saves the whole
//  struct back on every toggle change (auto-save, no explicit Save button —
//  matches how a single-purpose settings toggle usually behaves).
//

import Foundation
import UserNotifications
import Firebase
import FirebaseFirestore

@MainActor
class NotificationSettingsViewModel: ObservableObject {
    @Published var preferences: NotificationPreferences
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var pushAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    init() {
        self.preferences = AuthService.shared.currentUser?.notificationPreferences ?? NotificationPreferences()
    }

    func refreshPushStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        pushAuthorizationStatus = settings.authorizationStatus
    }

    func requestPushPermission() {
        Task {
            await PushNotificationManager.shared.requestAuthorization()
            await refreshPushStatus()
        }
    }

    /// Saves the whole preferences struct and pushes the change into
    /// AuthService.currentUser locally so nothing needs a relaunch to pick
    /// it up (same pattern as EditProfileViewModel.save()).
    func save() async {
        guard let uid = AuthService.shared.currentUser?.id else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let encoded = try Firestore.Encoder().encode(preferences)
            try await Firestore.firestore().collection("users").document(uid)
                .updateData(["notificationPreferences": encoded])

            if var user = AuthService.shared.currentUser {
                user.notificationPreferences = preferences
                AuthService.shared.currentUser = user
            }
        } catch {
            errorMessage = "Couldn't save notification settings: \(error.localizedDescription)"
        }
    }
}
