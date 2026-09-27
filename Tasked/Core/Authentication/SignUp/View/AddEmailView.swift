//
//  AddEmailView.swift
//  Tasked
//
//  Created by Blake Porteous on 17/03/2025.
//  Updated (Ink block pass): "Next" now uses the shared inkButton() chrome
//  instead of a hand-rolled blue rounded rect.
//  Updated (Stricter email pass): "Next" gate now uses
//  RegistrationViewModel.isValidEmail (a real regex check) instead of just
//  contains("@") && contains(".") — that loose check let obviously
//  unfinished addresses like "test@gmail." through.
//

import SwiftUI

struct AddEmailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: RegistrationViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Add your email")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("You'll use this email to sign in to your account")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .modifier(IGTextFieldModifier())
                
            if viewModel.isValidEmail {
                NavigationLink {
                        CreateUsernameView()
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
    AddEmailView()
        .environmentObject(RegistrationViewModel())
}
