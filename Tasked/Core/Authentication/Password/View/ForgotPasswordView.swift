//
//  ForgotPasswordView.swift
//  Tasked
//
//  New: sheet presented from LoginView's "Forgot Password?" button.
//  Updated (Ink block pass): "Send Reset Link" now uses the shared
//  inkButton() chrome.
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
                    .foregroundStyle(.secondary)
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
                            .inkButton()
                    } else {
                        Text("Send Reset Link")
                            .inkButton()
                    }
                }
                .disabled(viewModel.isSendingReset)
                .padding(.horizontal, 24)
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
