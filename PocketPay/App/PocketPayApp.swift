//
//  PocketPayApp.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

/// Application entry point for PocketPay.
///
/// Holds the root environment objects so that any descendant view can access
/// `AuthManager` and `PaymentManager` via `@EnvironmentObject` if needed.
/// The root view switches between `LoginView` and `MainTabView` based on
/// the authentication state published by `AuthManager`.
@main
struct PocketPayApp: App {
    // AuthManager is observed here so that changes to isAuthenticated
    // trigger a root-level view swap without requiring the login/main
    // views to hold their own references to the manager.
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var paymentManager = PaymentManager.shared

    var body: some Scene {
        WindowGroup {
            // Show the main app only after the user has authenticated.
            // LoginView handles both password and biometric flows.
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
