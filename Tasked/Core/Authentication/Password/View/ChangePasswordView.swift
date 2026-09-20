//
//  ChangePasswordView.swift
//  Tasked
//
//  New: reachable from Settings > Account > Change Password.
//

import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ChangePasswordViewModel()

    var body: some View {
        Form {
            Section {
                SecureField("New password", text: $viewModel.newPassword)
                SecureField("Confirm new password", text: $viewModel.confirmPassword)
            } footer: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        if await viewModel.save() {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(viewModel.isSaving || viewModel.newPassword.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack { ChangePasswordView() }
}
