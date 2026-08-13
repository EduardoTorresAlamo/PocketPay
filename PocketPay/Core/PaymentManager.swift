//
//  PaymentManager.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

/// Coordinates payment operations and owns the in-memory transaction ledger.
///
/// `PaymentManager` is the high-level payment facade. It validates business
/// rules (authentication, positive amount, sufficient balance) before delegating
/// the actual charge to `StripeManager`. On success it appends a new `Transaction`
/// to its published `transactions` array and deducts the amount from the current
/// user's in-memory balance.
///
/// The whole class is isolated to the `MainActor` so `@Published` changes are
/// always delivered on the main thread regardless of which async context calls
/// these methods. Consumers should depend on `PaymentProcessing` rather than on
/// this concrete type so tests can substitute a double.
@MainActor
class PaymentManager: ObservableObject, PaymentProcessing {
    /// Chronologically sorted list of all transactions. New payments are inserted
    /// at index 0 so the most recent item always appears first.
    @Published var transactions: [Transaction] = []
    /// `true` while a payment is being processed; used to show loading indicators.
    @Published var isProcessing = false
    /// Describes the last payment failure in user-readable language.
    @Published var errorMessage: String?

    /// Shared singleton referenced by ViewModels throughout the app.
    static let shared = PaymentManager()

    private let stripeManager: any PaymentGateway
    private let authManager: any AuthManaging

    /// Keychain account name under which the transaction ledger is persisted.
    private static let transactionsKeychainKey = "com.pocketpay.transactions"

    /// Creates a payment manager backed by the given collaborators.
    ///
    /// Both dependencies default to their shared singletons so production code
    /// keeps using `PaymentManager.shared`; tests construct their own instance
    /// with an `AuthManaging` double.
    init(stripeManager: any PaymentGateway = StripeManager.shared, authManager: any AuthManaging = AuthManager.shared) {
        self.stripeManager = stripeManager
        self.authManager = authManager
        // Restore the persisted ledger, falling back to mock data on first launch
        loadTransactions()
    }

    // MARK: - Transaction Methods

    /// Populates `transactions` from the Keychain-persisted ledger, sorted newest first.
    ///
    /// Falls back to the mock data set when nothing has been persisted yet, so a
    /// fresh install still shows sample history.
    func loadTransactions() {
        let saved: [Transaction]? = KeychainManager.load(key: PaymentManager.transactionsKeychainKey)
        let source = saved ?? Transaction.mockTransactions
        transactions = source.sorted { $0.date > $1.date }
    }

    /// Encodes the current ledger and writes it to the Keychain so it survives relaunch.
    private func saveTransactions() {
        KeychainManager.save(transactions, key: PaymentManager.transactionsKeychainKey)
    }

    /// Sends money from the current user to a contact via Stripe.
    ///
    /// - Parameters:
    ///   - contact: The recipient contact.
    ///   - amount: Transfer amount in USD; must be greater than zero.
    ///   - notes: Optional memo string attached to the transaction.
    /// - Returns: `true` when the transfer completed successfully.
    func sendMoney(to contact: Contact, amount: Double, notes: String?) async -> Bool {
        await processCharge(amount: amount) {
            Transaction(
                type: .p2p,
                category: .p2p,
                amount: amount,
                status: .completed,
                recipientName: contact.name,
                recipientPhone: contact.phoneNumber,
                notes: notes
            )
        }
    }

    /// Pays a business or service provider via Stripe.
    ///
    /// - Parameters:
    ///   - name: Display name of the business or biller.
    ///   - amount: Payment amount in USD.
    ///   - notes: Optional memo.
    /// - Returns: `true` on success.
    func payBusiness(name: String, amount: Double, notes: String?) async -> Bool {
        await processCharge(amount: amount) {
            Transaction(
                type: .business,
                category: .general,
                amount: amount,
                status: .completed,
                recipientName: name,
                notes: notes
            )
        }
    }

    /// Donates an amount to an organization via Stripe.
    ///
    /// - Parameters:
    ///   - organization: Display name of the recipient organization.
    ///   - amount: Donation amount in USD.
    /// - Returns: `true` on success.
    func makeDonation(to organization: String, amount: Double) async -> Bool {
        await processCharge(amount: amount) {
            Transaction(
                type: .donation,
                category: .general,
                amount: amount,
                status: .completed,
                recipientName: organization
            )
        }
    }

    /// Shared charge pipeline behind every public payment method.
    ///
    /// Runs the common flow once so the P2P, business, and donation paths cannot
    /// drift apart: re-entrancy guard (double-charge protection), authentication /
    /// positive-amount / sufficient-balance validation, the Stripe charge, and — on
    /// success — recording the transaction and deducting the balance. Balance
    /// mutation is delegated to `AuthManager`, the single writer of the user model.
    ///
    /// - Parameters:
    ///   - amount: Charge amount in USD; must be greater than zero.
    ///   - buildTransaction: Factory invoked on success to build the ledger entry.
    /// - Returns: `true` when the charge completed and was recorded.
    private func processCharge(amount: Double, buildTransaction: () -> Transaction) async -> Bool {
        // Reject re-entrant taps while a charge is already in flight (double-charge guard).
        guard !isProcessing else { return false }

        guard let currentUser = authManager.currentUser else {
            errorMessage = "User not authenticated"
            return false
        }

        guard amount > 0 else {
            errorMessage = "Amount must be greater than zero"
            return false
        }

        guard currentUser.balance >= amount else {
            errorMessage = "Insufficient balance"
            return false
        }

        isProcessing = true
        errorMessage = nil

        // Delegate the actual charge to StripeManager (or mock).
        let paymentSuccess = await stripeManager.processPayment(amount: amount)

        guard paymentSuccess else {
            errorMessage = stripeManager.errorMessage ?? "Payment failed"
            isProcessing = false
            return false
        }

        // Prepend so the new transaction appears at the top of the history list.
        transactions.insert(buildTransaction(), at: 0)
        saveTransactions()

        // Deduct via AuthManager rather than mutating currentUser.balance here.
        authManager.updateBalance(by: -amount)

        isProcessing = false
        return true
    }

    // MARK: - Helper Methods

    /// Returns the most recent transactions up to `limit` items.
    ///
    /// - Parameter limit: Maximum number of items to return. Defaults to `5`.
    /// - Returns: Slice of `transactions` sorted newest first.
    func getRecentTransactions(limit: Int = 5) -> [Transaction] {
        return Array(transactions.prefix(limit))
    }

    /// Filters transactions by `TransactionType`.
    ///
    /// - Parameter type: The type to filter by (e.g., `.p2p`, `.business`).
    /// - Returns: All transactions matching the specified type.
    func getTransactionsByType(_ type: TransactionType) -> [Transaction] {
        return transactions.filter { $0.type == type }
    }

    /// Sums all completed outgoing transaction amounts.
    ///
    /// - Returns: Total amount spent in USD.
    func getTotalSpent() -> Double {
        return transactions
            .filter { !$0.isIncoming && $0.status == .completed }
            .reduce(0) { $0 + $1.amount }
    }

    /// Sums all completed incoming transaction amounts.
    ///
    /// - Returns: Total amount received in USD.
    func getTotalReceived() -> Double {
        return transactions
            .filter { $0.isIncoming && $0.status == .completed }
            .reduce(0) { $0 + $1.amount }
    }
}
