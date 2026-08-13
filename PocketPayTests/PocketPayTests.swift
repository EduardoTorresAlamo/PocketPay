//
//  PocketPayTests.swift
//  PocketPayTests
//
//  Created by Eduardo Torres on 1/21/26.
//

import Testing
@testable import PocketPay

// MARK: - Test Doubles

/// Deterministic `PaymentOutcomeDeciding` that always returns a fixed verdict,
/// so charge-approval tests never depend on `Double.random`.
struct FixedOutcome: PaymentOutcomeDeciding {
    let approved: Bool
    func isChargeApproved() -> Bool { approved }
}

/// In-memory `AuthManaging` double. Records balance deltas and profile saves so
/// tests can assert what `PaymentManager` / `ProfileView` asked it to do.
@MainActor
final class MockAuthManager: AuthManaging {
    var isAuthenticated: Bool = true
    var currentUser: User?
    var errorMessage: String?
    var biometricType: String = "Face ID"
    var isBiometricAvailable: Bool = true

    /// Value returned from `login`; flip to exercise the failure branch.
    var loginResult = true
    /// Value returned from `authenticateWithBiometrics`.
    var biometricsResult = true

    private(set) var balanceDeltas: [Double] = []
    private(set) var savedProfiles: [User] = []

    init(user: User? = nil) {
        self.currentUser = user
    }

    func login(username: String, password: String) async -> Bool {
        isAuthenticated = loginResult
        return loginResult
    }

    func authenticateWithBiometrics() async -> Bool {
        isAuthenticated = biometricsResult
        return biometricsResult
    }

    func logout() {
        isAuthenticated = false
        currentUser = nil
    }

    func updateBalance(by delta: Double) {
        balanceDeltas.append(delta)
        if var user = currentUser {
            user.balance += delta
            currentUser = user
        }
    }

    func updateProfile(_ user: User) {
        currentUser = user
        savedProfiles.append(user)
    }
}

/// Deterministic `PaymentGateway` double standing in for `StripeManager`, with a
/// controllable approve/decline result and no artificial delay.
final class MockStripeManager: PaymentGateway {
    var errorMessage: String?
    /// Result returned from `processPayment`.
    var chargeApproved = true
    private(set) var chargedAmounts: [Double] = []

    func processPayment(amount: Double) async -> Bool {
        chargedAmounts.append(amount)
        if !chargeApproved {
            errorMessage = "Payment failed. Please try again."
        }
        return chargeApproved
    }
}

private extension User {
    /// A funded test user with the given balance.
    static func funded(_ balance: Double) -> User {
        User(
            username: "demo",
            fullName: "Test User",
            email: "test@example.com",
            phoneNumber: "+1 787 555 0000",
            balance: balance
        )
    }
}

// MARK: - PaymentManager.processCharge (via public charge methods)

/// Exercises the shared `processCharge` pipeline through the public payment
/// methods, using in-memory doubles so no singletons or delays are involved.
@MainActor
struct PaymentManagerTests {
    @Test("Approved charge records a transaction and deducts the balance")
    func approvedChargeDeductsBalance() async {
        let auth = MockAuthManager(user: .funded(100))
        let gateway = MockStripeManager()
        gateway.chargeApproved = true
        let manager = PaymentManager(stripeManager: gateway, authManager: auth)
        let before = manager.transactions.count

        let success = await manager.makeDonation(to: "Red Cross", amount: 40)

        #expect(success)
        #expect(manager.transactions.count == before + 1)
        #expect(gateway.chargedAmounts == [40])
        #expect(auth.balanceDeltas == [-40])
    }

    @Test("Declined charge records nothing and leaves the balance untouched")
    func declinedChargeLeavesBalanceUntouched() async {
        let auth = MockAuthManager(user: .funded(100))
        let gateway = MockStripeManager()
        gateway.chargeApproved = false
        let manager = PaymentManager(stripeManager: gateway, authManager: auth)
        let before = manager.transactions.count

        let success = await manager.makeDonation(to: "Red Cross", amount: 40)

        #expect(!success)
        #expect(manager.transactions.count == before)
        #expect(auth.balanceDeltas.isEmpty)
        #expect(manager.errorMessage != nil)
    }

    @Test("Charge is rejected when the amount exceeds the balance")
    func insufficientBalanceIsRejected() async {
        let auth = MockAuthManager(user: .funded(10))
        let gateway = MockStripeManager()
        let manager = PaymentManager(stripeManager: gateway, authManager: auth)

        let success = await manager.makeDonation(to: "Red Cross", amount: 50)

        #expect(!success)
        #expect(gateway.chargedAmounts.isEmpty)
        #expect(manager.errorMessage == "Insufficient balance")
    }

    @Test("Charge is rejected when there is no authenticated user")
    func unauthenticatedChargeIsRejected() async {
        let auth = MockAuthManager(user: nil)
        let gateway = MockStripeManager()
        let manager = PaymentManager(stripeManager: gateway, authManager: auth)

        let success = await manager.makeDonation(to: "Red Cross", amount: 25)

        #expect(!success)
        #expect(gateway.chargedAmounts.isEmpty)
        #expect(manager.errorMessage == "User not authenticated")
    }

    @Test("Charge is rejected when the amount is not positive")
    func nonPositiveAmountIsRejected() async {
        let auth = MockAuthManager(user: .funded(100))
        let gateway = MockStripeManager()
        let manager = PaymentManager(stripeManager: gateway, authManager: auth)

        let success = await manager.makeDonation(to: "Red Cross", amount: 0)

        #expect(!success)
        #expect(gateway.chargedAmounts.isEmpty)
        #expect(manager.errorMessage == "Amount must be greater than zero")
    }
}

// MARK: - PaymentOutcomeDeciding wired into the real StripeManager

/// Drives `processCharge` through the real `StripeManager` while forcing its
/// outcome via an injected `PaymentOutcomeDeciding`. Serialized because it
/// mutates the shared `StripeManager` singleton.
@MainActor
@Suite(.serialized)
struct StripeOutcomeTests {
    @Test("Fixed-approve decider makes processCharge succeed")
    func fixedApproveSucceeds() async {
        let stripe = StripeManager.shared
        let previous = stripe.outcomeDecider
        stripe.outcomeDecider = FixedOutcome(approved: true)
        defer { stripe.outcomeDecider = previous }

        let auth = MockAuthManager(user: .funded(100))
        let manager = PaymentManager(stripeManager: stripe, authManager: auth)
        let before = manager.transactions.count

        let success = await manager.makeDonation(to: "Red Cross", amount: 30)

        #expect(success)
        #expect(manager.transactions.count == before + 1)
        #expect(auth.balanceDeltas == [-30])
    }

    @Test("Fixed-decline decider makes processCharge fail")
    func fixedDeclineFails() async {
        let stripe = StripeManager.shared
        let previous = stripe.outcomeDecider
        stripe.outcomeDecider = FixedOutcome(approved: false)
        defer { stripe.outcomeDecider = previous }

        let auth = MockAuthManager(user: .funded(100))
        let manager = PaymentManager(stripeManager: stripe, authManager: auth)
        let before = manager.transactions.count

        let success = await manager.makeDonation(to: "Red Cross", amount: 30)

        #expect(!success)
        #expect(manager.transactions.count == before)
        #expect(auth.balanceDeltas.isEmpty)
    }
}

// MARK: - AuthManager biometrics

/// Verifies the biometric surface of the real `AuthManager`. Serialized because
/// it touches the `AuthManager.shared` singleton.
@MainActor
@Suite(.serialized)
struct AuthManagerBiometricTests {
    @Test("biometricType always returns a known label")
    func biometricTypeIsKnownLabel() {
        let known = ["Face ID", "Touch ID", "Optic ID", "Biometrics"]
        #expect(known.contains(AuthManager.shared.biometricType))
    }

    @Test("Biometric login fails gracefully when biometrics are unavailable")
    func biometricLoginFailsWhenUnavailable() async {
        let auth = AuthManager.shared
        // Only drive the async path when biometrics are unavailable, so the
        // system prompt is never shown (it would hang a non-interactive run).
        guard !auth.isBiometricAvailable else { return }

        let result = await auth.authenticateWithBiometrics()

        #expect(!result)
        #expect(!auth.isAuthenticated)
        #expect(auth.errorMessage != nil)
    }
}
