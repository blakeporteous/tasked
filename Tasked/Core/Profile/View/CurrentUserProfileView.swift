//
//  CurrentUserProfileView.swift
//  Tasked
//
//  Created by Blake Porteous on 21/03/2025.
//  Updated: menu expanded to Settings / Activity / Sign Out (Feature 6).
//

import SwiftUI

struct CurrentUserProfileView: View {
    let user: User
    @State private var showSettings = false
    @State private var showActivity = false

    var body: some View {
        NavigationStack {
            ScrollView {
                ProfileHeaderView(user: user)
                PostGridView(user: user)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }

                        Button {
                            showActivity = true
                        } label: {
                            Label("Friend Requests", systemImage: "person.badge.plus")
                        }

                        Button(role: .destructive) {
                            AuthService.shared.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "arrow.right.square")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.black)
                    }
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(user: user)
            }
            .navigationDestination(isPresented: $showActivity) {
                ActivityView()
            }
        }
    }
}

#Preview {
    CurrentUserProfileView(user: User.MOCK_USERS[0])
}
