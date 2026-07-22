//
//  LoginViewModel.swift
//  InstagramTutorial
//
//  Created by Blake Porteous on 14/07/2025.
//

import Foundation

@MainActor
class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AuthService.shared.login(withEmail: email, password: password)
        } catch {
            errorMessage = "Couldn't sign in. Check your email and password and try again."
        }
    }
}
