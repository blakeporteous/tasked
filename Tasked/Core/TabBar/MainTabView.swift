//
//  MainTabView.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//  Updated: Goal tab removed — the weekly task now lives at the top of the
//  Home feed (Feature 4). Goal.swift is no longer used and can be deleted
//  from the Xcode project.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedIndex = 0
    let user: User

    var body: some View {
        TabView(selection: $selectedIndex) {

            FeedView()
                .onAppear { selectedIndex = 0 }
                .tabItem {
                    Image(systemName: "house")
                }.tag(0)

            SearchView()
                .onAppear { selectedIndex = 1 }
                .tabItem {
                    Image(systemName: "magnifyingglass")
                }.tag(1)

            UploadPostView(tabIndex: $selectedIndex)
                .onAppear { selectedIndex = 2 }
                .tabItem {
                    Image(systemName: "plus.square")
                }.tag(2)

            CurrentUserProfileView(user: user)
                .onAppear { selectedIndex = 3 }
                .tabItem {
                    Image(systemName: "person")
                }.tag(3)
        }
        .accentColor(.black)
    }
}

#Preview {
    MainTabView(user: User.MOCK_USERS[0])
}
