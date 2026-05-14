//
//  LoginView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false

    var body: some View {
        ZStack {
            // Background
            AppConstants.Colors.background
                .ignoresSafeArea()

            VStack(spacing: AppConstants.Spacing.large) {
                Spacer()

                // Logo and Title
                VStack(spacing: AppConstants.Spacing.medium) {
                    // Logo placeholder (use Image for actual logo)
                    Circle()
                        .fill(AppConstants.Colors.primaryPurple)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text("PR")
                                .font(AppConstants.Typography.largeTitle)
                                .foregroundColor(.white)
                                .bold()
                        )

                    Text("PRPay")
                        .font(AppConstants.Typography.largeTitle)
                        .foregroundColor(AppConstants.Colors.label)
                        .bold()

                    Text("Your Digital Wallet")
                        .font(AppConstants.Typography.subheadline)
                        .foregroundColor(AppConstants.Colors.secondaryLabel)
                }
                .padding(.bottom, AppConstants.Spacing.extraLarge)

                // Login Form
                VStack(spacing: AppConstants.Spacing.medium) {
                    // Username Field
                    CustomTextField(
                        placeholder: "Username",
                        text: $username,
                        icon: "person.fill"
                    )

                    // Password Field
                    CustomSecureField(
                        placeholder: "Password",
                        text: $password,
                        icon: "lock.fill"
                    )

                    // Error Message
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(AppConstants.Colors.errorRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppConstants.Spacing.small)
                    }

                    // Login Button
                    Button(action: login) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Login")
                                    .font(AppConstants.Typography.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppConstants.Colors.primaryPurple)
                        .foregroundColor(.white)
                        .cornerRadius(AppConstants.CornerRadius.medium)
                    }
                    .disabled(isLoading || username.isEmpty || password.isEmpty)
                    .opacity((isLoading || username.isEmpty || password.isEmpty) ? 0.6 : 1.0)

                    // Biometric Login Button
                    if authManager.isBiometricAvailable {
                        Button(action: loginWithBiometrics) {
                            HStack(spacing: AppConstants.Spacing.small) {
                                Image(systemName: authManager.biometricType == "Face ID" ? "faceid" : "touchid")
                                    .font(.title2)
                                Text("Login with \(authManager.biometricType)")
                                    .font(AppConstants.Typography.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppConstants.Colors.cardBackground)
                            .foregroundColor(AppConstants.Colors.primaryPurple)
                            .cornerRadius(AppConstants.CornerRadius.medium)
                        }
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, AppConstants.Spacing.large)

                Spacer()

                // Demo Credentials Helper
                VStack(spacing: AppConstants.Spacing.extraSmall) {
                    Text("Demo Credentials")
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(AppConstants.Colors.secondaryLabel)

                    Text("Username: demo | Password: password")
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(AppConstants.Colors.secondaryLabel)
                }
                .padding(.bottom, AppConstants.Spacing.large)
            }
        }
    }

    // MARK: - Actions

    private func login() {
        isLoading = true
        Task {
            let success = await authManager.login(username: username, password: password)
            await MainActor.run {
                isLoading = false
                if !success {
                    showError = true
                }
            }
        }
    }

    private func loginWithBiometrics() {
        isLoading = true
        Task {
            let success = await authManager.authenticateWithBiometrics()
            await MainActor.run {
                isLoading = false
                if !success {
                    showError = true
                }
            }
        }
    }
}

// MARK: - Custom Text Field

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack(spacing: AppConstants.Spacing.medium) {
            Image(systemName: icon)
                .foregroundColor(AppConstants.Colors.secondaryLabel)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .font(AppConstants.Typography.body)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .cornerRadius(AppConstants.CornerRadius.medium)
    }
}

// MARK: - Custom Secure Field

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack(spacing: AppConstants.Spacing.medium) {
            Image(systemName: icon)
                .foregroundColor(AppConstants.Colors.secondaryLabel)
                .frame(width: 20)

            SecureField(placeholder, text: $text)
                .font(AppConstants.Typography.body)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .cornerRadius(AppConstants.CornerRadius.medium)
    }
}

// MARK: - Preview

#Preview {
    LoginView()
}
