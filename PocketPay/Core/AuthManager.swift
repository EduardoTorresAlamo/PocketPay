//
//  AuthManager.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine
import LocalAuthentication

/// Manages user identity and session state for the app.
///
/// `AuthManager` is a singleton that drives the root authentication gate in
/// `PocketPayApp`. It publishes `isAuthenticated` so the root view can reactively
/// switch between `LoginView` and `MainTabView`.
///
/// Authentication strategies supported:
/// - Username/password (mock implementation for demo; replace with a real API call in production)
/// - Biometrics via `LocalAuthentication` (Face ID, Touch ID, or Optic ID depending on device)
///
/// The whole class is isolated to the `MainActor` because every stored property
/// is `@Published` and drives UI. Consumers should depend on `AuthManaging`
/// rather than on this concrete type so tests can substitute a double.
@MainActor
class AuthManager: ObservableObject, AuthManaging {
    /// Whether the user currently has an active session.
    @Published var isAuthenticated = false
    /// The profile of the authenticated user, or `nil` when logged out.
    @Published var currentUser: User?
    /// A localized message describing the most recent auth failure. Cleared on success.
    @Published var errorMessage: String?

    /// Shared singleton instance used throughout the app.
    static let shared = AuthManager()

    /// Persistence layer for the user profile. Injected so the domain model stays
    /// unaware of storage and tests can substitute a double.
    private let userRepository: any UserRepository

    private init(userRepository: any UserRepository = KeychainUserRepository()) {
        self.userRepository = userRepository
        // Check if user is already logged in (from UserDefaults or Keychain in production)
        checkAuthStatus()
    }

    // MARK: - Authentication Methods

    /// Authenticates a user with a username and password against the mock backend.
    ///
    /// In production this method should issue a network request to your authentication
    /// endpoint and securely store the returned token in the Keychain. The current
    /// implementation accepts only `demo` / `password` for demonstration purposes.
    ///
    /// - Parameters:
    ///   - username: The user-supplied username string.
    ///   - password: The user-supplied password string.
    /// - Returns: `true` if authentication succeeded; `false` otherwise.
    func login(username: String, password: String) async -> Bool {
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

        // Mock authentication - in production, call your backend API
        if username.lowercased() == "demo" && password == "password" {
            // Load saved user or use mock user
            var user = userRepository.load() ?? User.mockUser
            user.username = username
            currentUser = user
            isAuthenticated = true
            errorMessage = nil
            // Save user for persistence
            userRepository.save(user)
            return true
        } else {
            errorMessage = "Invalid username or password"
            isAuthenticated = false
            return false
        }
    }

    /// Authenticates the user with the device's biometric sensor via `LocalAuthentication`.
    ///
    /// `LAContext.canEvaluatePolicy` is called first to confirm biometrics are enrolled
    /// and available. If unavailable, the error (e.g., "Biometric data not enrolled")
    /// is forwarded to `errorMessage`. On success the previously saved `User` profile is
    /// restored so the session feels seamless.
    ///
    /// - Returns: `true` when the biometric challenge succeeded; `false` otherwise.
    func authenticateWithBiometrics() async -> Bool {
        // LAContext is the LocalAuthentication entry point. A new instance is
        // required for each authentication request; reusing a context can cause
        // unexpected behavior after a failed evaluation.
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available on this device.
        // The policy .deviceOwnerAuthenticationWithBiometrics also allows the
        // device passcode as a fallback when biometrics fail too many times.
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = error?.localizedDescription ?? "Biometric authentication not available"
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                // localizedReason is shown in the system biometric prompt dialog.
                localizedReason: "Log in to PocketPay"
            )

            if success {
                // Load saved user or use mock user
                let user = userRepository.load() ?? User.mockUser
                currentUser = user
                isAuthenticated = true
                errorMessage = nil
            }
            return success
        } catch {
            // LAError codes include userCancel, authenticationFailed, etc.
            errorMessage = "Authentication failed. Please try again."
            return false
        }
    }

    /// Ends the current user session and resets all published auth state.
    ///
    /// Persisted profile data in `UserDefaults` is intentionally left intact so
    /// the user's name and preferences are restored on next login.
    func logout() {
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
        // Note: We don't clear the saved user data, so profile info persists
        // If you want to clear it completely, uncomment: userRepository.clear()
    }

    /// Applies a signed delta to the current user's balance and persists the result.
    ///
    /// No-op when there is no authenticated user. Reassigning `currentUser`
    /// publishes the change so observing views update, and `save()` persists the
    /// new balance to the Keychain so it survives relaunch.
    ///
    /// - Parameter delta: Amount to add to the balance; pass a negative value to deduct.
    func updateBalance(by delta: Double) {
        guard var user = currentUser else { return }
        user.balance += delta
        currentUser = user
        userRepository.save(user)
    }

    /// Applies edited profile fields to the current user and persists the result.
    ///
    /// `AuthManager` is the single writer of the user model, so profile edits from
    /// `ProfileView` are routed here rather than persisting the model directly.
    ///
    /// - Parameter user: The updated user profile to publish and persist.
    func updateProfile(_ user: User) {
        currentUser = user
        userRepository.save(user)
    }

    private func checkAuthStatus() {
        // In production, check for stored credentials/tokens (e.g., a Keychain token).
        // For now, default to not authenticated so the login screen always shows on launch.
        isAuthenticated = false
    }

    // MARK: - Helper Methods

    /// A human-readable name for the biometric type available on this device.
    ///
    /// Returns `"Face ID"`, `"Touch ID"`, `"Optic ID"`, or `"Biometrics"` as a
    /// generic fallback. Used to label the biometric button in `LoginView`.
    var biometricType: String {
        // A fresh LAContext is needed to read biometryType accurately.
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
            // Guard against future biometry types added by Apple.
            return "Biometrics"
        }
    }

    /// `true` when at least one biometric factor is enrolled and available on this device.
    var isBiometricAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
}
