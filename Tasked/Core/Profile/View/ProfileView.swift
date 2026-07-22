//
//  ProfileView.swift
//  Tasked
//
//  Created by Blake Porteous on 20/02/2025.
//

import SwiftUI

struct ProfileView: View {
    
    let user: User
    
    var body: some View {
            ScrollView{
                
                ProfileHeaderView(user: user)

                PostGridView(user: user)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
}

#Preview {
    ProfileView(user: User.MOCK_USERS[0])
}
