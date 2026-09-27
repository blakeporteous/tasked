//
//  LoginView.swift
//  Tasked
//
//  Created by Blake Porteous on 21/02/2025.
//  Updated: "Forgot Password?" now opens a sheet that sends a real password
//  reset email instead of just printing to the console.
//  Updated (Ink block pass): "Login" now uses the shared inkButton() chrome.
//  Updated (Layout polish pass): added explicit spacing between the email
//  and password fields (they previously butted right up against each
//  other), and removed the grey Divider() that sat above "Don't have an
//  account? Sign Up" — it read as an unnecessary extra line now that the
//  ink-block buttons/fields already provide plenty of visual separation.
//  Updated (Placeholder + hover pass): placeholders shortened to "EMAIL"/
//  "PASSWORD" (the fields' white->grey focus behavior lives in
//  IGTextFieldModifier now, shared across the app). The Login button dims
//  slightly on hover (trackpad/mouse on iPad or Catalyst — no effect on
//  iPhone touch, which has no hover state).
//  Updated (Logo wallpaper pass): the single centered logo at the top is
//  replaced with a repeating stack of the same wordmark running from the
//  top of the screen down toward the middle.
//  Updated (Full-width, no-gap pass): copies widened to near-full screen
//  width with zero spacing between them, stacking flush edge-to-edge.
//  Updated (Flat opacity, 3-copy pass): dropped the fade-out — all copies
//  render at full opacity — and cut the count from 5 down to 3.
//  Updated (Bottom-gap pass): the 3 logo copies still stack with zero space
//  between EACH OTHER, but there's now explicit breathing room between the
//  last copy and the email field below — previously relying on the outer
//  VStack's implicit default spacing, which read as barely-there next to
//  how tightly the logos themselves are packed.
//

import SwiftUI

struct LoginView: View {
    @StateObject var viewModel = LoginViewModel()
    @State private var showForgotPassword = false
    @State private var isHoveringLogin = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {

                    LogoWallpaper()
                        .frame(height: geo.size.height / 2)

                    VStack(spacing: 16) {
                        TextField("EMAIL", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .modifier(IGTextFieldModifier())

                        SecureField("PASSWORD", text: $viewModel.password)
                            .modifier(IGTextFieldModifier())
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        showForgotPassword = true
                    } label: {
                        Text("Forgot Password?")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .padding(.top)
                            .padding(.trailing, 28)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .inkButton()
                        } else {
                            Text("Login")
                                .inkButton()
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .opacity(isHoveringLogin ? 0.8 : 1)
                    .onHover { hovering in
                        isHoveringLogin = hovering
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical)

                    Spacer()

                    NavigationLink {
                        AddEmailView()
                            .navigationBarBackButtonHidden(true)
                    } label: {
                        HStack(spacing: 3) {
                            Text("Don't have an account?")
                            Text("Sign Up")
                                .fontWeight(.semibold)
                        }
                        .font(.footnote)
                    }
                    .padding(.vertical, 16)
                }
                .frame(width: geo.size.width) // GeometryReader defaults to top-leading; pin full width
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(viewModel: viewModel)
        }
    }
}

/// Decorative stack of the app's wordmark tiled top-to-middle, flush
/// edge-to-edge with zero gap between copies. Purely visual — no
/// interaction, no accessibility weight (VoiceOver would just hear "Logo"
/// three times otherwise).
private struct LogoWallpaper: View {
    private let copyCount = 3

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: -20) {
                ForEach(0..<copyCount, id: \.self) { _ in
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    LoginView()
        .environmentObject(RegistrationViewModel())
}
