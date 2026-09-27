//
//  PushNotificationManager.swift
//  Tasked
//
//  New: owns push-notification registration — requesting the OS permission,
//  receiving the FCM token from Firebase once granted, and keeping that
//  token saved on the signed-in user's document so the "sendPushNotification"
//  Cloud Function (functions/index.js) knows where to deliver a push.
//  AuthService calls saveTokenIfNeeded() after loadUserData and
//  clearToken(uid:) from signOut, so a token is never left pointing at a
//  session that's no longer signed in on this device.
//

import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseFirestore

final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    private override init() { super.init() }

    /// Called once from AppDelegate at launch.
    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    /// Shows the OS permission prompt (only actually shows once per install
    /// unless the user resets it in Settings) and, if granted, registers for
    /// remote notifications so APNs hands us a device token.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            return granted
        } catch {
            return false
        }
    }

    /// Saves the current FCM token on the signed-in user's document. Safe to
    /// call with no signed-in user (no-op) or before a token exists yet
    /// (also a no-op) — AuthService re-calls this after every login, and
    /// Messaging's delegate callback below calls it again whenever the token
    /// itself changes, so a token generated before login is never lost.
    func saveTokenIfNeeded() {
        guard let uid = AuthService.shared.currentUser?.id,
              let token = Messaging.messaging().fcmToken else { return }

        Task {
            try? await Firestore.firestore().collection("users").document(uid)
                .updateData(["fcmToken": token])
        }
    }

    /// Clears the token on sign-out so a push never gets sent to a device
    /// that's no longer signed in as this user. Takes `uid` explicitly
    /// (rather than reading AuthService.shared) since the caller (signOut)
    /// clears the session right after calling this.
    func clearToken(uid: String) {
        Task {
            try? await Firestore.firestore().collection("users").document(uid)
                .updateData(["fcmToken": FieldValue.delete()])
        }
    }
}

extension PushNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        saveTokenIfNeeded()
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    // Without this, a push while the app is already open in the foreground
    // does nothing visible at all.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }
}
