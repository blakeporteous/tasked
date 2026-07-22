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
    
    var body: some View {
        Group {
            if viewModel.userSession == nil {
                LoginView()
                    .environmentObject(registrationViewModel)
            } else if let currentUser = viewModel.currentUser {
                MainTabView(user: currentUser)
            } else {
                // Signed in, but profile data hasn't loaded (still fetching, or it failed —
                // e.g. no network). Never leave this blank: show a spinner and a way out.
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

#Preview {
    ContentView()
}
