//
//  LoginView.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

/// The authentication gate shown when no session is active.
///
/// Provides two sign-in paths:
/// - **Username/password**: Demo credentials (`demo` / `password`) are shown at
///   the bottom of the screen for evaluators. In production the hint section
///   should be removed and the login method should call a real API.
/// - **Biometrics**: The button label and icon adapt to the device's biometry type
///   (Face ID, Touch ID, Optic ID) using `AuthManager.biometricType`. The button
///   is hidden on simulators or devices where biometrics are not enrolled.
struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var username = ""
    @State private var password = ""
    /// Controls the loading spinner on the primary login button.
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
                            Text("PP")
                                .font(AppConstants.Typography.largeTitle)
                                .foregroundColor(.white)
                                .bold()
                        )

                    Text("PocketPay")
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

    /// Initiates the username/password login flow in a detached async Task.
    ///
    /// Sets `isLoading` to show the progress indicator while the async call is
    /// in flight, then clears it when `AuthManager.login` resolves.
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

    /// Initiates biometric authentication via `LAContext` through `AuthManager`.
    ///
    /// The system biometric prompt (Face ID / Touch ID dialog) is shown by the
    /// operating system; this method only triggers it and handles the result.
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

/// A styled text field with a leading SF Symbol icon, used in `LoginView`.
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    /// SF Symbol name for the leading icon (e.g., `"person.fill"`).
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

/// A styled secure text field (password entry) with a leading SF Symbol icon.
///
/// Mirrors `CustomTextField` but uses `SecureField` so the input is masked.
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
