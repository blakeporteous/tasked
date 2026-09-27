//
//  ContentView.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//  Updated (Email verification pass): a signed-in user with a loaded profile
//  but an unverified email now sees VerifyEmailView instead of MainTabView.
//  Also refreshes verification status whenever the app returns to the
//  foreground while sitting on that screen, so tapping the link in Mail/
//  Safari and switching back picks it up without needing the manual
//  "I've verified" button.
//  Updated (Launch animation pass): SplashView now drives its own timing —
//  it plays the "logo -> dot flies out -> full-screen blue" sequence and
//  calls onFinished() right as the screen finishes filling with blue.
//  Previously this used a fixed 1.5s Task.sleep unrelated to what was
//  actually on screen; now the splash's own animation is what decides when
//  it's done, so this can never cut away mid-animation (or await longer
//  than needed). The crossfade below then dissolves that solid blue into
//  whatever's underneath instead of a hard cut.
//  Updated (Onboarding pass): the first time MainTabView appears on this
//  device, a short OnboardingView tour is shown as a fullScreenCover over
//  it. Gated on an @AppStorage flag (not tied to the account itself) so it
//  only ever shows once per device, regardless of how many accounts sign
//  in/out on it.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var registrationViewModel = RegistrationViewModel()
    @StateObject var notificationsViewModel = NotificationsViewModel()

    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false


    var body: some View {

        ZStack {

            Group {

                if viewModel.userSession == nil {

                    LoginView()
                        .environmentObject(registrationViewModel)

                } else if let currentUser = viewModel.currentUser {

                    if viewModel.isEmailVerified {

                        MainTabView(user: currentUser)
                            .environmentObject(notificationsViewModel)
                            .onAppear {
                                if !hasSeenOnboarding {
                                    showOnboarding = true
                                }
                            }
                            .fullScreenCover(isPresented: $showOnboarding) {
                                OnboardingView {
                                    hasSeenOnboarding = true
                                    showOnboarding = false
                                }
                            }

                    } else {

                        VerifyEmailView()
                    }

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

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: viewModel.userSession?.uid) { _, uid in

            if let uid {

                notificationsViewModel.startListening(uid: uid)

            } else {

                notificationsViewModel.stopListening()

            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, viewModel.userSession != nil, !viewModel.isEmailVerified {
                Task { await AuthService.shared.refreshEmailVerificationStatus() }
            }
        }
    }
}
