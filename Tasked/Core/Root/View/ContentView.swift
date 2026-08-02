//
//  ContentView.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var registrationViewModel = RegistrationViewModel()
    @StateObject var notificationsViewModel = NotificationsViewModel()

    @State private var showSplash = true


    var body: some View {

        Group {

            if showSplash {

                SplashView()

            } else {

                Group {

                    if viewModel.userSession == nil {

                        LoginView()
                            .environmentObject(registrationViewModel)

                    } else if let currentUser = viewModel.currentUser {

                        MainTabView(user: currentUser)
                            .environmentObject(notificationsViewModel)

                    } else {

                        VStack(spacing: 16) {

                            ProgressView()

                            Text("Loading your profile…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)


                            Button("Sign Out") {
                                AuthService.shared.signOut()
                            }
                            .font(.footnote)
                            .padding(.top, 8)
                        }
                    }

                }
            }
        }
        .task {

            // Let the splash animation play
            try? await Task.sleep(
                nanoseconds: 1_500_000_000
            )

            withAnimation {
                showSplash = false
            }
        }
        .onChange(of: viewModel.userSession?.uid) { _, uid in

            if let uid {

                notificationsViewModel.startListening(uid: uid)

            } else {

                notificationsViewModel.stopListening()

            }
        }
    }
}
