//
//  APIKeys.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation

struct APIKeys {
    // MARK: - Stripe Keys
    // NOTE: Replace these with your actual Stripe keys from https://dashboard.stripe.com/apikeys
    // For production, use a secure key management solution

    static let stripePublishableKey = "pk_test_YOUR_PUBLISHABLE_KEY_HERE"

    // IMPORTANT: Never expose your secret key in client-side code
    // This is for demonstration purposes only. In production, all payment intents
    // should be created on your backend server.
    static let stripeSecretKey = "sk_test_YOUR_SECRET_KEY_HERE"

    // Backend API endpoint (if you have one)
    static let backendURL = "https://your-backend-api.com"

    // MARK: - Mock Settings
    // Set to true to use mock payment processing without actual Stripe calls
    static let useMockPayments = true
}
