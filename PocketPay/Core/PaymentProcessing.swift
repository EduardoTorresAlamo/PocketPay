//
//  PaymentProcessing.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation

/// Abstraction over the payment layer.
///
/// ViewModels depend on this protocol rather than on `PaymentManager` directly
/// so a test double can be injected in unit tests. The production conformance
/// is `PaymentManager`, whose `shared` singleton is used as the default
/// injected value.
///
/// The protocol is `@MainActor`-isolated because every conformance publishes UI
/// state; isolating the requirement keeps call sites free of actor hops.
@MainActor
protocol PaymentProcessing: AnyObject {
    /// Chronologically sorted list of all transactions, newest first.
    var transactions: [Transaction] { get }
    /// `true` while a payment is being processed.
    var isProcessing: Bool { get }
    /// Describes the last payment failure in user-readable language.
    var errorMessage: String? { get }

    /// Populates `transactions` from the backing store.
    func loadTransactions()
    /// Sends money from the current user to a contact.
    func sendMoney(to contact: Contact, amount: Double, notes: String?) async -> Bool
    /// Pays a business or service provider.
    func payBusiness(name: String, amount: Double, notes: String?) async -> Bool
    /// Donates an amount to an organization.
    func makeDonation(to organization: String, amount: Double) async -> Bool

    /// Returns the most recent transactions up to `limit` items.
    func getRecentTransactions(limit: Int) -> [Transaction]
    /// Filters transactions by `TransactionType`.
    func getTransactionsByType(_ type: TransactionType) -> [Transaction]
    /// Sums all completed outgoing transaction amounts.
    func getTotalSpent() -> Double
    /// Sums all completed incoming transaction amounts.
    func getTotalReceived() -> Double
}
