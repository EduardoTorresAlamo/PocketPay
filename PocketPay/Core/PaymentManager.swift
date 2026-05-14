//
//  PaymentManager.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

class PaymentManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?

    static let shared = PaymentManager()

    private let stripeManager = StripeManager.shared
    private let authManager = AuthManager.shared

    private init() {
        // Load mock transactions
        loadTransactions()
    }

    // MARK: - Transaction Methods

    func loadTransactions() {
        // In production, fetch from local storage or API
        transactions = Transaction.mockTransactions.sorted { $0.date > $1.date }
    }

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

        // Process payment through Stripe
        let paymentSuccess = await stripeManager.processPayment(amount: amount)

        if paymentSuccess {
            // Create transaction
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

    func getRecentTransactions(limit: Int = 5) -> [Transaction] {
        return Array(transactions.prefix(limit))
    }

    func getTransactionsByType(_ type: TransactionType) -> [Transaction] {
        return transactions.filter { $0.type == type }
    }

    func getTotalSpent() -> Double {
        return transactions
            .filter { !$0.isIncoming && $0.status == .completed }
            .reduce(0) { $0 + $1.amount }
    }

    func getTotalReceived() -> Double {
        return transactions
            .filter { $0.isIncoming && $0.status == .completed }
            .reduce(0) { $0 + $1.amount }
    }
}
