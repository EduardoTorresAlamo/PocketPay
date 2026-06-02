//
//  StripeManager.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine
// import StripePaymentSheet // Uncomment when Stripe SDK is added via Swift Package Manager

/// Handles all Stripe payment operations for the app.
///
/// The Stripe integration follows a two-step pattern:
/// 1. A **payment intent** is created server-side (or mocked locally) to obtain a
///    client secret. The client secret represents the intended charge and its amount.
/// 2. The **PaymentSheet** is presented to the user, who enters card details and
///    confirms. Stripe then charges the payment method and resolves the intent.
///
/// When `APIKeys.useMockPayments` is `true`, both steps are simulated locally
/// with artificial delays so the UI behaves realistically without needing a live
/// Stripe account or a backend server. Set it to `false` and add the
/// `StripePaymentSheet` SPM package when moving to production.
class StripeManager: ObservableObject {
    /// The active `PaymentSheet.FlowController` instance. Typed as `Any?` because
    /// the Stripe SDK is not yet linked; once added, change this to
    /// `PaymentSheet.FlowController?`.
    @Published var paymentSheet: Any? // Will be PaymentSheet.FlowController? when Stripe is added
    /// `true` while a payment intent creation or payment sheet presentation is in flight.
    @Published var isProcessing = false
    /// A localized error message populated when a payment operation fails.
    @Published var errorMessage: String?

    /// Shared singleton; `PaymentManager` routes all charges through this instance.
    static let shared = StripeManager()

    private init() {
        // Configure Stripe with publishable key
        configureStripe()
    }

    // MARK: - Configuration

    private func configureStripe() {
        // When StripePaymentSheet is added, set the publishable key here so that
        // the SDK knows which Stripe account to charge:
        // StripeAPI.defaultPublishableKey = APIKeys.stripePublishableKey
        print("⚠️ Stripe SDK not configured. Add StripePaymentSheet via Swift Package Manager.")
    }

    // MARK: - Payment Intent

    /// Creates a Stripe payment intent for the given amount.
    ///
    /// In production this call must go to your backend server. The server uses
    /// the Stripe **secret key** to create the intent and returns only the
    /// `clientSecret` to the app. Exposing the secret key on the client is a
    /// critical security risk.
    ///
    /// - Parameter amount: Charge amount in USD (e.g., `25.00`).
    /// - Returns: The payment intent client secret string, or `nil` on failure.
    func createPaymentIntent(amount: Double) async -> String? {
        // Route to mock when mock mode is enabled.
        if APIKeys.useMockPayments {
            return await mockCreatePaymentIntent(amount: amount)
        }

        // TODO: Implement real backend call
        // Example:
        // let url = URL(string: "\(APIKeys.backendURL)/create-payment-intent")!
        // var request = URLRequest(url: url)
        // request.httpMethod = "POST"
        // request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        //
        // let body: [String: Any] = [
        //     "amount": Int(amount * 100), // Convert dollars to cents (Stripe uses smallest currency unit)
        //     "currency": "usd"
        // ]
        // request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        //
        // let (data, _) = try await URLSession.shared.data(for: request)
        // let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        // return json?["clientSecret"] as? String

        return nil
    }

    /// Simulates payment intent creation with a short artificial network delay.
    ///
    /// Returns a placeholder client secret string that is never sent to Stripe.
    ///
    /// - Parameter amount: Requested charge amount (unused in mock mode).
    /// - Returns: A mock client secret of the form `pi_mock_secret_<UUID>`.
    private func mockCreatePaymentIntent(amount: Double) async -> String? {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Return a mock client secret formatted to look like a real Stripe value.
        return "pi_mock_secret_\(UUID().uuidString)"
    }

    // MARK: - Payment Sheet

    /// Fetches a payment intent and prepares the Stripe `PaymentSheet` for presentation.
    ///
    /// When the Stripe SDK is integrated, this method constructs a
    /// `PaymentSheet.FlowController` and stores it in `paymentSheet`. The view
    /// layer then calls `flowController.presentPaymentOptions` to let the user
    /// choose or enter a payment method.
    ///
    /// - Parameter amount: Charge amount in USD.
    /// - Returns: `true` when the sheet is ready; `false` on any error.
    func preparePaymentSheet(amount: Double) async -> Bool {
        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }

        guard let clientSecret = await createPaymentIntent(amount: amount) else {
            await MainActor.run {
                self.errorMessage = "Failed to create payment intent"
                self.isProcessing = false
            }
            return false
        }

        // Uncomment when Stripe SDK is added:
        // var configuration = PaymentSheet.Configuration()
        // configuration.merchantDisplayName = AppConstants.AppInfo.name
        // configuration.allowsDelayedPaymentMethods = false
        //
        // do {
        //     let flowController = try await PaymentSheet.FlowController(
        //         paymentIntentClientSecret: clientSecret,
        //         configuration: configuration
        //     )
        //     await MainActor.run {
        //         self.paymentSheet = flowController
        //         self.isProcessing = false
        //     }
        //     return true
        // } catch {
        //     await MainActor.run {
        //         self.errorMessage = error.localizedDescription
        //         self.isProcessing = false
        //     }
        //     return false
        // }

        // Mock success for now
        await MainActor.run {
            self.isProcessing = false
        }
        return true
    }

    // MARK: - Process Payment

    /// Processes a payment for the given amount, routing to mock or live Stripe.
    ///
    /// The mock path simulates a 90% success rate with a 2-second delay to mimic
    /// realistic network and card-processing latency.
    ///
    /// - Parameter amount: Charge amount in USD.
    /// - Returns: `true` when the charge was approved; `false` on failure.
    func processPayment(amount: Double) async -> Bool {
        // useMockPayments bypasses Stripe entirely for dev/demo; set to false for production
        if APIKeys.useMockPayments {
            return await mockProcessPayment(amount: amount)
        }

        // TODO: Implement real Stripe payment processing
        // When Stripe SDK is added, present the payment sheet and handle the result
        return false
    }

    /// Simulates payment processing with a 2-second delay and a 90% success rate.
    ///
    /// The artificial failure rate (10%) lets UI error states be exercised during
    /// development without needing a real declined card.
    ///
    /// - Parameter amount: Charge amount in USD (unused in mock mode).
    /// - Returns: `true` on simulated approval; `false` on simulated decline.
    private func mockProcessPayment(amount: Double) async -> Bool {
        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }

        // Simulate payment processing
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Mock success (90% success rate to exercise failure UI in development)
        let isSuccess = Double.random(in: 0...1) < 0.9

        await MainActor.run {
            self.isProcessing = false
            if !isSuccess {
                self.errorMessage = "Payment failed. Please try again."
            }
        }

        return isSuccess
    }

    // MARK: - Helper Methods

    /// Formats a dollar amount as a currency string.
    ///
    /// - Parameter amount: Amount in USD.
    /// - Returns: Formatted string such as `"$12.50"`.
    func formatAmount(_ amount: Double) -> String {
        return String(format: "$%.2f", amount)
    }
}
