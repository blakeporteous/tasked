//
//  CreatePasswordView.swift
//  Tasked
//
//  Created by Blake Porteous on 17/03/2025.
//  Updated (Ink block pass): "Next" now uses the shared inkButton() chrome.
//  Updated (Password policy pass): now validates against PasswordPolicy
//  (lowercase, uppercase, number, special character, minimum length) and
//  shows the same live PasswordRequirementsView checklist as
//  ChangePasswordView, instead of a flat "6 characters" check. Also added a
//  "Confirm password" field — RegistrationViewModel already tracked
//  confirmPassword, it just wasn't being collected here yet.
//  Updated (Spacing pass): added breathing room between "Create a
//  password" and the requirements checklist below it — everything was
//  packed too tightly under the shared VStack's flat 12pt spacing.
//  Updated (Public/private pass): "Next" now pushes to PublicPrivateView
//  instead of going straight to CompleteSignUpView.
//

import SwiftUI

struct CreatePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: RegistrationViewModel

    private var passwordsMatch: Bool {
        viewModel.password == viewModel.confirmPassword
    }

    private var isValid: Bool {
        PasswordPolicy.validate(viewModel.password).isValid && passwordsMatch
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Create a password")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("Choose a strong password to protect your account")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            SecureField("Password", text: $viewModel.password)
                .modifier(IGTextFieldModifier())
                .padding(.top)

            SecureField("Confirm password", text: $viewModel.confirmPassword)
                .modifier(IGTextFieldModifier())

            PasswordRequirementsView(password: viewModel.password)
                .padding(.top, 20)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !viewModel.confirmPassword.isEmpty && !passwordsMatch {
                Text("Passwords don't match.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if isValid {
                NavigationLink {
                    PublicPrivateView()
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
    CreatePasswordView()
        .environmentObject(RegistrationViewModel())
}
