//
//  PaymentManager.swift
//  PRPay
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
/// All UI state mutations happen on the `MainActor` so `@Published` changes are
/// always delivered on the main thread regardless of which async context calls
/// these methods.
class PaymentManager: ObservableObject {
    /// Chronologically sorted list of all transactions. New payments are inserted
    /// at index 0 so the most recent item always appears first.
    @Published var transactions: [Transaction] = []
    /// `true` while a payment is being processed; used to show loading indicators.
    @Published var isProcessing = false
    /// Describes the last payment failure in user-readable language.
    @Published var errorMessage: String?

    /// Shared singleton referenced by ViewModels throughout the app.
    static let shared = PaymentManager()

    private let stripeManager = StripeManager.shared
    private let authManager = AuthManager.shared

    private init() {
        // Load mock transactions
        loadTransactions()
    }

    // MARK: - Transaction Methods

    /// Populates `transactions` from the mock data set, sorted newest first.
    ///
    /// In production, replace this with a network or local-database fetch.
    func loadTransactions() {
        // In production, fetch from local storage or API
        transactions = Transaction.mockTransactions.sorted { $0.date > $1.date }
    }

    /// Sends money from the current user to a contact via Stripe.
    ///
    /// Validation order: authentication check, positive amount, sufficient balance.
    /// If all checks pass, delegates to `StripeManager.processPayment` and then
    /// records the transaction and adjusts the user's balance on success.
    ///
    /// - Parameters:
    ///   - contact: The recipient contact.
    ///   - amount: Transfer amount in USD; must be greater than zero.
    ///   - notes: Optional memo string attached to the transaction.
    /// - Returns: `true` when the transfer completed successfully.
    func sendMoney(to contact: Contact, amount: Double, notes: String?) async -> Bool {
        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return false
        }

        guard amount > 0 else {
            await MainActor.run {
                self.errorMessage = "Amount must be greater than zero"
            }
            return false
        }

        guard currentUser.balance >= amount else {
            await MainActor.run {
                self.errorMessage = "Insufficient balance"
            }
            return false
        }

        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }

        // Delegate the actual charge to StripeManager (or mock).
        let paymentSuccess = await stripeManager.processPayment(amount: amount)

        if paymentSuccess {
            // Record the completed P2P transaction in the ledger.
            let transaction = Transaction(
                type: .p2p,
                category: .p2p,
                amount: amount,
                status: .completed,
                recipientName: contact.name,
                recipientPhone: contact.phoneNumber,
                notes: notes
            )

            await MainActor.run {
                // Prepend so the new transaction appears at the top of the history list.
                self.transactions.insert(transaction, at: 0)

                // Optimistically deduct balance from the in-memory user model.
                self.authManager.currentUser?.balance -= amount

                self.isProcessing = false
            }

            return true
        } else {
            await MainActor.run {
                self.errorMessage = stripeManager.errorMessage ?? "Payment failed"
                self.isProcessing = false
            }
            return false
        }
    }

    /// Pays a business or service provider via Stripe.
    ///
    /// Identical validation flow to `sendMoney(to:amount:notes:)` but creates a
    /// `.business` type transaction and does not store a recipient phone number.
    ///
    /// - Parameters:
    ///   - name: Display name of the business or biller.
    ///   - amount: Payment amount in USD.
    ///   - notes: Optional memo.
    /// - Returns: `true` on success.
    func payBusiness(name: String, amount: Double, notes: String?) async -> Bool {
        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return false
        }

        guard amount > 0 else {
            await MainActor.run {
                self.errorMessage = "Amount must be greater than zero"
            }
            return false
        }

        guard currentUser.balance >= amount else {
            await MainActor.run {
                self.errorMessage = "Insufficient balance"
            }
            return false
        }

        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }

        // Process payment through Stripe
        let paymentSuccess = await stripeManager.processPayment(amount: amount)

        if paymentSuccess {
            // Create transaction
            let transaction = Transaction(
                type: .business,
                category: .general,
                amount: amount,
                status: .completed,
                recipientName: name,
                notes: notes
            )

            await MainActor.run {
                // Add transaction to history
                self.transactions.insert(transaction, at: 0)

                // Update user balance
                self.authManager.currentUser?.balance -= amount

                self.isProcessing = false
            }

            return true
        } else {
            await MainActor.run {
                self.errorMessage = stripeManager.errorMessage ?? "Payment failed"
                self.isProcessing = false
            }
            return false
        }
    }

    /// Donates an amount to an organization via Stripe.
    ///
    /// Creates a `.donation` type transaction. Logic is structurally identical
    /// to `payBusiness` but uses a distinct transaction type for reporting.
    ///
    /// - Parameters:
    ///   - organization: Display name of the recipient organization.
    ///   - amount: Donation amount in USD.
    /// - Returns: `true` on success.
    func makeDonation(to organization: String, amount: Double) async -> Bool {
        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return false
        }

        guard amount > 0 else {
            await MainActor.run {
                self.errorMessage = "Amount must be greater than zero"
            }
            return false
        }

        guard currentUser.balance >= amount else {
            await MainActor.run {
                self.errorMessage = "Insufficient balance"
            }
            return false
        }

        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }

        // Process payment through Stripe
        let paymentSuccess = await stripeManager.processPayment(amount: amount)

        if paymentSuccess {
            // Create transaction
            let transaction = Transaction(
                type: .donation,
                category: .general,
                amount: amount,
                status: .completed,
                recipientName: organization
            )

            await MainActor.run {
                // Add transaction to history
                self.transactions.insert(transaction, at: 0)

                // Update user balance
                self.authManager.currentUser?.balance -= amount

                self.isProcessing = false
            }

            return true
        } else {
            await MainActor.run {
                self.errorMessage = stripeManager.errorMessage ?? "Payment failed"
                self.isProcessing = false
            }
            return false
        }
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
