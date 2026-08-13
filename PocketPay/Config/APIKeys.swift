//
//  APIKeys.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation

/// Central store for API credentials and feature flags.
///
/// Only publishable keys belong here. Secret keys must NEVER live
/// in client-side code — they belong on a backend server only.
struct APIKeys {
    /// Stripe publishable key used to initialize the Stripe SDK on the client.
    /// Safe to include in the app bundle; does not grant access to your Stripe account.
    static let stripePublishableKey = "pk_test_YOUR_PUBLISHABLE_KEY_HERE"

    /// Base URL of the backend API used to create Stripe payment intents.
    /// Replace with your actual server URL before going to production.
    static let backendURL = "https://your-backend-api.com"

    /// When `true`, all payment calls use mock implementations inside `StripeManager`.
    /// Set to `false` when a real backend is available.
    static let useMockPayments = true
}
