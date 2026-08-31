//
//  CompleteSignUpView.swift
//  Tasked
//
//  Updated: shows RegistrationViewModel.errorMessage (previously never rendered
//  anywhere) and a loading state while the account is being created.
//

import SwiftUI

struct CompleteSignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: RegistrationViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Text("Welcome to Tasked, \(viewModel.username)")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .multilineTextAlignment(.center)
            
            Text("Click below to complete sign up and start using Tasked")
                .font(.footnote)
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
                        .frame(width: 360, height: 44)
                        .background(Color(.systemBlue))
                        .cornerRadius(8)
                } else {
                    Text("Complete Sign Up")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 360, height: 44)
                        .background(Color(.systemBlue))
                        .cornerRadius(8)
                }
            }
            .disabled(viewModel.isCreatingAccount)
            .padding(.vertical)
            
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
    CompleteSignUpView()
        .environmentObject(RegistrationViewModel())
}
