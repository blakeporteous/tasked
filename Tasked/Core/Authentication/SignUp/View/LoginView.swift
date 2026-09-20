//
//  LoginView.swift
//  Tasked
//
//  Created by Blake Porteous on 21/02/2025.
//  Updated: "Forgot Password?" now opens a sheet that sends a real password
//  reset email instead of just printing to the console.
//

import SwiftUI

struct LoginView: View {
    @StateObject var viewModel = LoginViewModel()
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack{
            VStack{
                
                Spacer()
                
                //Image("logo")
                    //.resizable()
                    //.scaledToFill()
                    //.frame(width: 220, height: 100)
                
                VStack {
                    TextField("Enter your email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .modifier(IGTextFieldModifier())

                    
                    SecureField("Enter your password", text: $viewModel.password)
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
                            .frame(width: 360, height: 44)
                            .background(Color(.systemBlue))
                            .cornerRadius(8)
                    } else {
                        Text("Login")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 360, height: 44)
                            .background(Color(.systemBlue))
                            .cornerRadius(8)
                    }
                }
                .disabled(viewModel.isLoading)
                .padding(.vertical)
                
                Spacer()
                
                Divider()
                
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
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(viewModel: viewModel)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(RegistrationViewModel())
}
