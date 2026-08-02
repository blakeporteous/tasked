//
//  PostGridView.swift
//  Tasked
//
//  Created by Blake Porteous on 24/03/2025.
//  Updated: tapping a post opens a full-screen scrollable feed starting at that
//  post (Feature 2), matching the Instagram profile-grid pattern.
//

import SwiftUI
import Kingfisher

struct PostGridView: View {
    @StateObject var viewModel: PostGridViewModel
    @State private var selectedIndex: Int?

    init(user: User) {
        self._viewModel = StateObject(wrappedValue: PostGridViewModel(user: user))
    }

    private let gridItems: [GridItem] = [
        .init(.flexible(), spacing: 1),
        .init(.flexible(), spacing: 1),
        .init(.flexible(), spacing: 1)
    ]

    private let imageDimension: CGFloat = UIScreen.main.bounds.width/3 - 1

    var body: some View {
        LazyVGrid(columns: gridItems, spacing: 2) {
            ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                KFImage(URL(string: post.imageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageDimension, height: imageDimension)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedIndex = index
                    }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedIndex != nil },
            set: { isPresented in if !isPresented { selectedIndex = nil } }
        )) {
            PostFeedView(posts: viewModel.posts, startIndex: selectedIndex ?? 0)
        }
    }
}

#Preview {
    PostGridView(user: User.MOCK_USERS[0])
}
