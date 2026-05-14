//
//  AuthManager.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine
import LocalAuthentication

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?

    static let shared = AuthManager()

    private init() {
        // Check if user is already logged in (from UserDefaults or Keychain in production)
        checkAuthStatus()
    }

    // MARK: - Authentication Methods

    func login(username: String, password: String) async -> Bool {
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

        // Mock authentication - in production, call your backend API
        if username.lowercased() == "demo" && password == "password" {
            await MainActor.run {
                // Load saved user or use mock user
                var user = User.load() ?? User.mockUser
                user.username = username
                self.currentUser = user
                self.isAuthenticated = true
                self.errorMessage = nil
                // Save user for persistence
                user.save()
            }
            return true
        } else {
            await MainActor.run {
                self.errorMessage = "Invalid username or password"
                self.isAuthenticated = false
            }
            return false
        }
    }

    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            await MainActor.run {
                self.errorMessage = error?.localizedDescription ?? "Biometric authentication not available"
            }
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Log in to PRPay"
            )

            if success {
                await MainActor.run {
                    // Load saved user or use mock user
                    let user = User.load() ?? User.mockUser
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.errorMessage = nil
                }
            }
            return success
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }

    func logout() {
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
        // Note: We don't clear the saved user data, so profile info persists
        // If you want to clear it completely, uncomment: User.clearSaved()
    }

    private func checkAuthStatus() {
        // In production, check for stored credentials/tokens
        // For now, default to not authenticated
        isAuthenticated = false
    }

    // MARK: - Helper Methods

    var biometricType: String {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Biometrics"
        }

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Biometrics"
        }
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
}
