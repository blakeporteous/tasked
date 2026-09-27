//
//  CreateUsername.swift
//  Tasked
//
//  Created by Blake Porteous on 17/03/2025.
//  Updated: checks username availability against Firestore while typing
//  (debounced in RegistrationViewModel) and blocks "Next" until it's free.
//  Updated (Ink block pass): "Next" now uses the shared inkButton() chrome.
//

import SwiftUI

struct CreateUsernameView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: RegistrationViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Create username")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("You'll use this username to sign in to your account")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            TextField("Username", text: $viewModel.username)
                .modifier(IGTextFieldModifier())

            if viewModel.isCheckingUsername {
                Text("Checking availability…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let usernameError = viewModel.usernameError {
                Text(usernameError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            
            if viewModel.isUsernameValid {
                NavigationLink {
                        CreatePasswordView()
                            .navigationBarBackButtonHidden()
                
                } label: {
                    Text("Next")
                        .inkButton()
                }
                .padding(.horizontal, 24)
                .padding(.vertical)
            } else {
                Text("Next")
                    .inkButton(isDisabled: true)
                    .padding(.horizontal, 24)
                    .padding(.vertical)
            }
            
            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Image(systemName: "chevron.left")
                    .imageScale(.large)
                    .onTapGesture {
                        dismiss()
                    }
            }
        }
    }
}

#Preview {
    CreateUsernameView()
        .environmentObject(RegistrationViewModel())
}
