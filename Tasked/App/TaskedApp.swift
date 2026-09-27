//
//  TaskedApp.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//  Updated (Push notifications): AppDelegate now configures
//  PushNotificationManager and forwards the APNs device token to
//  FirebaseMessaging once the OS hands it over (only happens after
//  PushNotificationManager.requestAuthorization() succeeds, triggered from
//  NotificationSettingsView).
//  Updated (Dark mode pass): reads a device-wide "isDarkModeEnabled" flag
//  (same @AppStorage pattern as ContentView's "hasSeenOnboarding") and
//  applies it via .preferredColorScheme on the root view. Toggled from
//  SettingsView. Defaults to false (light mode / system's usual default)
//  until someone flips it on.
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    PushNotificationManager.shared.configure()

    return true
  }

  // APNs hands us the raw device token here; forward it to FirebaseMessaging
  // so it can pair it with an FCM token, which is what
  // PushNotificationManager.saveTokenIfNeeded() actually stores.
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("DEBUG: Failed to register for remote notifications — \(error)")
  }
}


@main
struct InstagramTutorialApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
        }
    }
}
