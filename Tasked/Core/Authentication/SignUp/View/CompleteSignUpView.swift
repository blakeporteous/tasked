//
//  CompleteSignUpView.swift
//  Tasked
//
//  Updated: shows RegistrationViewModel.errorMessage (previously never rendered
//  anywhere) and a loading state while the account is being created.
//  Updated (Ink block pass): "Complete Sign Up" now uses the shared
//  inkButton() chrome.
//  Updated (Centering pass): the welcome text was removed, leaving just the
//  logo and button — relying on Spacer() above and below to center that
//  block doesn't fully account for the toolbar/safe-area, so it read as
//  slightly off-center. Switched to `.frame(maxWidth: .infinity, maxHeight:
//  .infinity)` on the content VStack instead, which centers it explicitly
//  within the whole available space regardless of what's above/below it.
//  Updated (Layout pass): logo is now pinned near the top of the screen
//  (not vertically centered), with the "Welcome, username" message and the
//  Complete Sign Up button as their own centered block in the remaining
//  space below it — two Spacers around that block balance it vertically.
//

import SwiftUI

struct CompleteSignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: RegistrationViewModel
    
    var body: some View {
        VStack {
            Image("Logo")
                .resizable()
                .scaledToFill()
                .frame(width: 220, height: 100)
                .padding(.top, 40)

            Spacer()

            VStack(spacing: 16) {
                Text("Welcome, \(viewModel.username) and thank you for using TASKED.")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    Task { await viewModel.createUser() }
                } label: {
                    if viewModel.isCreatingAccount {
                        ProgressView()
                            .tint(.white)
                            .inkButton()
                    } else {
                        Text("COMPLETE SIGN UP")
                            .inkButton()
                    }
                }
                .disabled(viewModel.isCreatingAccount)
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    CompleteSignUpView()
        .environmentObject(RegistrationViewModel())
}
