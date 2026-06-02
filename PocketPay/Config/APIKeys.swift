//
//  APIKeys.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation

/// Central store for API credentials and feature flags.
///
/// All keys are static constants so they can be referenced without instantiation.
/// In a production app, publishable keys belong here; secret keys must NEVER live
/// in client-side code and should only be used on a backend server.
struct APIKeys {
    // MARK: - Stripe Keys
    // NOTE: Replace these with your actual Stripe keys from https://dashboard.stripe.com/apikeys
    // For production, use a secure key management solution

    /// Stripe publishable key used to initialize the Stripe SDK on the client.
    /// Safe to include in the app bundle; does not grant access to your Stripe account.
    static let stripePublishableKey = "pk_test_YOUR_PUBLISHABLE_KEY_HERE"

    // IMPORTANT: Never expose your secret key in client-side code
    // This is for demonstration purposes only. In production, all payment intents
    // should be created on your backend server.
    /// Stripe secret key placeholder. This value must NEVER be shipped in a
    /// production build. Payment intents must be created server-side via a
    /// secure backend endpoint, and only the resulting client secret returned to
    /// the app.
    static let stripeSecretKey = "sk_test_YOUR_SECRET_KEY_HERE"

    /// Base URL of the backend API used to create Stripe payment intents.
    /// Replace with your actual server URL before going to production.
    static let backendURL = "https://your-backend-api.com"

    // MARK: - Mock Settings

    /// When `true`, all payment calls are intercepted by mock implementations
    /// inside `StripeManager`, so no real network requests are made and no
    /// actual Stripe credentials are required. Set to `false` to enable live
    /// Stripe processing in production builds.
    static let useMockPayments = true
}
