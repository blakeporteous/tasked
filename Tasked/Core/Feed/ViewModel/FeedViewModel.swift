//
//  FeedViewModel.swift
//  Tasked
//
//  Created by Blake Porteous on 11/08/2025.
//

import Foundation
import Firebase

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts = [Post]()
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    init() {
        Task { await fetchPosts() }
    }
    
    func fetchPosts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            self.posts = try await PostService.fetchFeedPosts()
        } catch {
            self.errorMessage = "Couldn't load feed: \(error.localizedDescription)"
            print("DEBUG: fetchFeedPosts failed — \(error)")
        }
    }
}
