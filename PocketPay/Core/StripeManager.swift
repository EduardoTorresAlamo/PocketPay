//
//  StripeManager.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine
// import StripePaymentSheet // Uncomment when Stripe SDK is added via Swift Package Manager

/// Decides whether a mock charge is approved.
///
/// Injecting this into `StripeManager` replaces the hard-coded `Double.random`
/// success roll, so tests can force a deterministic approve/decline instead of
/// depending on chance.
protocol PaymentOutcomeDeciding {
    /// - Returns: `true` when the simulated charge should be approved.
    func isChargeApproved() -> Bool
}

/// Default outcome provider: approves a configurable fraction of charges at random.
struct RandomPaymentOutcome: PaymentOutcomeDeciding {
    /// Probability in `0...1` that a charge is approved. Defaults to 90% so the
    /// failure UI still gets exercised during development.
    let approvalRate: Double

    init(approvalRate: Double = 0.9) {
        self.approvalRate = approvalRate
    }

    func isChargeApproved() -> Bool {
        Double.random(in: 0...1) < approvalRate
    }
}

/// Handles all Stripe payment operations for the app.
///
/// When `APIKeys.useMockPayments` is `true`, charges are simulated locally with
/// an artificial delay so the UI behaves realistically without a live Stripe
/// account or backend server. Set it to `false` and add the `StripePaymentSheet`
/// SPM package when moving to production.
class StripeManager: ObservableObject {
    /// `true` while a payment is in flight; used to drive loading indicators.
    @Published var isProcessing = false
    /// A localized error message populated when a payment operation fails.
    @Published var errorMessage: String?

    /// Decides mock charge outcomes. Overridable so tests can force a result.
    var outcomeDecider: PaymentOutcomeDeciding = RandomPaymentOutcome()

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

    // MARK: - Process Payment

    /// Processes a payment for the given amount, routing to mock or live Stripe.
    ///
    /// - Parameter amount: Charge amount in USD.
    /// - Returns: `true` when the charge was approved; `false` on failure.
    func processPayment(amount: Double) async -> Bool {
        // useMockPayments bypasses Stripe entirely for dev/demo; set to false for production
        if APIKeys.useMockPayments {
            return await mockProcessPayment(amount: amount)
        }

        // TODO: Implement real Stripe payment processing.
        // In production the client must create the payment intent server-side
        // (the Stripe secret key must never live in the app) and present the
        // PaymentSheet with the returned client secret.
        return false
    }

    /// Simulates payment processing with a 2-second delay and an injectable outcome.
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

        let isSuccess = outcomeDecider.isChargeApproved()

        await MainActor.run {
            self.isProcessing = false
            if !isSuccess {
                self.errorMessage = "Payment failed. Please try again."
            }
        }

        return isSuccess
    }
}
