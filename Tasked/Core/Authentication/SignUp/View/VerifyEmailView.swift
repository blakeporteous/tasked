//
//  VerifyEmailView.swift
//  Tasked
//
//  New (Email verification pass): shown by ContentView instead of
//  MainTabView whenever the signed-in user's email isn't verified yet.
//  Refreshes verification status on appear (and ContentView also refreshes
//  it whenever the app returns to the foreground), so tapping the link in
//  Mail/Safari and switching back usually clears this screen on its own —
//  the manual button is a fallback for whenever that timing doesn't line up.
//

import SwiftUI

struct VerifyEmailView: View {
    @StateObject private var viewModel = VerifyEmailViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "envelope.badge")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("Verify your email")
                .font(.title2)
                .fontWeight(.bold)

            Text("We sent a verification link to \(viewModel.email). Tap it, then come back here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let infoMessage = viewModel.infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task { await viewModel.refresh() }
            } label: {
                if viewModel.isRefreshing {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 280, height: 44)
                        .background(Color(.systemBlue))
                        .cornerRadius(8)
                } else {
                    Text("I've verified — refresh")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 280, height: 44)
                        .background(Color(.systemBlue))
                        .cornerRadius(8)
                }
            }
            .padding(.top, 8)

            Button {
                Task { await viewModel.resend() }
            } label: {
                if viewModel.isResending {
                    ProgressView()
                } else {
                    Text(viewModel.resendCooldown > 0 ? "Resend in \(viewModel.resendCooldown)s" : "Resend email")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
            }
            .disabled(viewModel.isResending || viewModel.resendCooldown > 0)

            Button("Sign Out") {
                AuthService.shared.signOut()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 20)

            Spacer()
        }
        .padding()
        .task {
            await viewModel.refresh()
        }
    }
}

#Preview {
    VerifyEmailView()
}
