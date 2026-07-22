//
//  SearchViewModel.swift
//  Tasked
//
//  Created by Blake Porteous on 18/07/2025.
//

import Foundation

@MainActor
class SearchViewModel: ObservableObject {
    @Published var users = [User]()
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    init() {
        Task { await fetchAllUsers() }
    }
    
    func fetchAllUsers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            self.users = try await UserService.fetchAllUsers()
        } catch {
            self.errorMessage = "Couldn't load users: \(error.localizedDescription)"
            print("DEBUG: fetchAllUsers failed — \(error)")
        }
    }
}
