//
//  ContentViewModel.swift
//  Tasked
//
//  Created by Blake Porteous on 22/04/2025.
//  Updated (Email verification pass): now also mirrors
//  AuthService.shared.isEmailVerified, so ContentView can gate MainTabView
//  behind it without talking to AuthService directly.
//

import Foundation
import Firebase
import FirebaseAuth
import Combine

class ContentViewModel: ObservableObject {
    
    private let service = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isEmailVerified: Bool = false
    
    init() {
        setupSubscribers()
    }
    
    func setupSubscribers() {
        service.$userSession.sink { [weak self] userSession in
            self?.userSession = userSession
        }
        .store(in: &cancellables)
        
        service.$currentUser.sink { [weak self] currentUser in
            self?.currentUser = currentUser
        }
        .store(in: &cancellables)

        service.$isEmailVerified.sink { [weak self] isEmailVerified in
            self?.isEmailVerified = isEmailVerified
        }
        .store(in: &cancellables)
    }
    
}
