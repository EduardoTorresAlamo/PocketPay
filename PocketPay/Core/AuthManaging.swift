//
//  AuthManaging.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation

/// Abstraction over the authentication layer.
///
/// ViewModels depend on this protocol rather than on `AuthManager` directly so
/// a test double can be injected in unit tests. The production conformance is
/// `AuthManager`, whose `shared` singleton is used as the default injected value.
///
/// The protocol is `@MainActor`-isolated because every conformance publishes UI
/// state; isolating the requirement keeps call sites free of actor hops.
@MainActor
protocol AuthManaging: AnyObject {
    /// Whether the user currently has an active session.
    var isAuthenticated: Bool { get set }
    /// The profile of the authenticated user, or `nil` when logged out.
    var currentUser: User? { get set }
    /// A localized message describing the most recent auth failure.
    var errorMessage: String? { get set }
    /// A human-readable name for the biometric type available on this device.
    var biometricType: String { get }
    /// `true` when at least one biometric factor is enrolled and available.
    var isBiometricAvailable: Bool { get }

    /// Authenticates a user with a username and password.
    func login(username: String, password: String) async -> Bool
    /// Authenticates the user with the device's biometric sensor.
    func authenticateWithBiometrics() async -> Bool
    /// Ends the current user session and resets all published auth state.
    func logout()
}
