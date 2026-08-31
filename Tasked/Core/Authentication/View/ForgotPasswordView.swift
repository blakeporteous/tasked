//
//  ForgotPasswordView.swift
//  Tasked
//
//  New: sheet presented from LoginView's "Forgot Password?" button.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Reset your password")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)

                Text("Enter the email on your account and we'll send you a reset link")
                    .font(.footnote)
                    .foregroundStyle(Color(.gray))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                TextField("Email", text: $viewModel.resetEmail)
                    .keyboardType(.emailAddress)
                    .modifier(IGTextFieldModifier())

                if let resetMessage = viewModel.resetMessage {
                    Text(resetMessage)
                        .font(.footnote)
                        .foregroundStyle(resetMessage.hasPrefix("Check") ? Color.secondary : Color.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    Task { await viewModel.sendPasswordReset() }
                } label: {
                    if viewModel.isSendingReset {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 360, height: 44)
                            .background(Color(.systemBlue))
                            .cornerRadius(8)
                    } else {
                        Text("Send Reset Link")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 360, height: 44)
                            .background(Color(.systemBlue))
                            .cornerRadius(8)
                    }
                }
                .disabled(viewModel.isSendingReset)
                .padding(.vertical)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView(viewModel: LoginViewModel())
}
