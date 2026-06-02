//
//  Transaction.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import SwiftUI

// MARK: - Transaction Category

/// Classifies a transaction for display, filtering, and color-coding purposes.
///
/// `CaseIterable` conformance lets `HistoryView` enumerate all categories
/// for its filter chip row.
enum TransactionCategory: String, Codable, CaseIterable {
    case utilities = "Utilities"
    case rent = "Rent"
    case subscription = "Subscription"
    /// Person-to-person transfer between app users.
    case p2p = "Person to Person"
    case general = "General"

    /// Human-readable label used in the UI. Backed by the raw value.
    var displayName: String {
        return self.rawValue
    }

    /// SF Symbol name representing this category in icon views.
    var icon: String {
        switch self {
        case .utilities:
            return "bolt.fill"
        case .rent:
            return "house.fill"
        case .subscription:
            return "repeat.circle.fill"
        case .p2p:
            return "person.2.fill"
        case .general:
            return "creditcard.fill"
        }
    }

    /// Brand color associated with this category, sourced from `AppConstants.Colors`.
    var color: Color {
        switch self {
        case .utilities:
            return AppConstants.Colors.utilitiesColor
        case .rent:
            return AppConstants.Colors.rentColor
        case .subscription:
            return AppConstants.Colors.subscriptionColor
        case .p2p:
            return AppConstants.Colors.p2pColor
        case .general:
            return AppConstants.Colors.generalColor
        }
    }
}

// MARK: - Transaction Type (Deprecated - use Category instead)

/// High-level classification of a transaction's origin.
///
/// This enum predates `TransactionCategory` and is retained for
/// `Codable` backward-compatibility. Prefer `TransactionCategory` for
/// any new display or filtering logic.
enum TransactionType: String, Codable {
    case p2p = "Person to Person"
    case business = "Business Payment"
    case donation = "Donation"
    case accountTransfer = "Account Transfer"
}

// MARK: - Transaction Status

/// The settlement state of a transaction.
enum TransactionStatus: String, Codable {
    case completed = "Completed"
    case pending = "Pending"
    case failed = "Failed"
}

// MARK: - Transaction Model

/// Represents a single financial transaction recorded in the app ledger.
///
/// Transactions are immutable once created (all `let` properties) except for
/// `status`, which can be updated if a pending payment is later resolved.
/// `isIncoming` determines the sign prefix shown in `formattedAmount`.
struct Transaction: Identifiable, Codable {
    /// Stable unique identifier used by SwiftUI `ForEach` and list diffing.
    let id: UUID
    /// High-level origin type of the transaction (P2P, business, donation).
    let type: TransactionType
    /// Semantic category used for filtering, icons, and color coding.
    let category: TransactionCategory
    /// Absolute dollar amount of the transaction (always positive; direction is set by `isIncoming`).
    let amount: Double
    /// Timestamp when the transaction was initiated.
    let date: Date
    /// Current settlement state; mutable so pending transactions can be resolved later.
    var status: TransactionStatus
    /// Display name of the payee or payer shown in transaction rows.
    let recipientName: String
    /// Phone number of the recipient for P2P transfers; `nil` for business payments.
    let recipientPhone: String?
    /// Optional user-supplied memo attached to the transaction.
    let notes: String?
    /// `true` when money was received by the current user (e.g., a friend sent funds).
    let isIncoming: Bool
    /// Links this transaction to a `RecurringPayment` so it can be identified
    /// as an auto-pay entry in `TransactionDetailView`.
    let recurringPaymentId: UUID? // Link to recurring payment if applicable

    init(
        id: UUID = UUID(),
        type: TransactionType,
        category: TransactionCategory,
        amount: Double,
        date: Date = Date(),
        status: TransactionStatus,
        recipientName: String,
        recipientPhone: String? = nil,
        notes: String? = nil,
        isIncoming: Bool = false,
        recurringPaymentId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.amount = amount
        self.date = date
        self.status = status
        self.recipientName = recipientName
        self.recipientPhone = recipientPhone
        self.notes = notes
        self.isIncoming = isIncoming
        self.recurringPaymentId = recurringPaymentId
    }

    /// Dollar amount with a `+` prefix for incoming and `-` for outgoing transactions.
    var formattedAmount: String {
        let prefix = isIncoming ? "+" : "-"
        return "\(prefix)$\(String(format: "%.2f", amount))"
    }

    /// Transaction date formatted as `"Jan 5, 2026"`.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Transaction time formatted as `"3:45 PM"`.
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    /// `true` when this transaction is linked to a recurring payment schedule.
    var isRecurring: Bool {
        return recurringPaymentId != nil
    }

    // MARK: - Mock Transactions with Categories
    static var mockTransactions: [Transaction] {
        [
            // Rent Payment
            Transaction(
                type: .business,
                category: .rent,
                amount: 1200.00,
                date: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                status: .completed,
                recipientName: "Apartment 4B",
                notes: "Monthly rent payment",
                recurringPaymentId: UUID()
            ),
            // Netflix Subscription
            Transaction(
                type: .business,
                category: .subscription,
                amount: 15.99,
                date: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                status: .completed,
                recipientName: "Netflix",
                notes: "Premium plan",
                recurringPaymentId: UUID()
            ),
            // Spotify Subscription
            Transaction(
                type: .business,
                category: .subscription,
                amount: 9.99,
                date: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                status: .completed,
                recipientName: "Spotify",
                notes: "Student plan",
                recurringPaymentId: UUID()
            ),
            // Electric Bill
            Transaction(
                type: .business,
                category: .utilities,
                amount: 125.50,
                date: Date().addingTimeInterval(-86400 * 7), // 7 days ago
                status: .completed,
                recipientName: "LUMA Energy",
                notes: "Electric bill",
                recurringPaymentId: UUID()
            ),
            // Water Bill
            Transaction(
                type: .business,
                category: .utilities,
                amount: 45.00,
                date: Date().addingTimeInterval(-86400 * 10), // 10 days ago
                status: .completed,
                recipientName: "AAA Water",
                notes: "Water service"
            ),
            // Internet Bill
            Transaction(
                type: .business,
                category: .utilities,
                amount: 79.99,
                date: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                status: .completed,
                recipientName: "Liberty Internet",
                notes: "Fiber 500MB",
                recurringPaymentId: UUID()
            ),
            // P2P Payment
            Transaction(
                type: .p2p,
                category: .p2p,
                amount: 50.00,
                date: Date().addingTimeInterval(-3600), // 1 hour ago
                status: .completed,
                recipientName: "Jose Rivera",
                recipientPhone: "+1 787 555 0001",
                notes: "Dinner split"
            ),
            // P2P Incoming
            Transaction(
                type: .p2p,
                category: .p2p,
                amount: 75.00,
                date: Date().addingTimeInterval(-86400), // 1 day ago
                status: .completed,
                recipientName: "Maria Garcia",
                recipientPhone: "+1 787 555 0002",
                notes: "Thanks!",
                isIncoming: true
            ),
            // HOA Fee
            Transaction(
                type: .business,
                category: .general,
                amount: 250.00,
                date: Date().addingTimeInterval(-86400 * 30), // 30 days ago
                status: .completed,
                recipientName: "HOA Management",
                notes: "Monthly HOA fee",
                recurringPaymentId: UUID()
            ),
            // Gym Membership
            Transaction(
                type: .business,
                category: .subscription,
                amount: 35.00,
                date: Date().addingTimeInterval(-86400 * 15), // 15 days ago
                status: .completed,
                recipientName: "Planet Fitness",
                notes: "Monthly membership",
                recurringPaymentId: UUID()
            ),
            // Donation
            Transaction(
                type: .donation,
                category: .general,
                amount: 25.00,
                date: Date().addingTimeInterval(-86400 * 20), // 20 days ago
                status: .completed,
                recipientName: "Red Cross PR"
            ),
            // Pending Payment
            Transaction(
                type: .business,
                category: .utilities,
                amount: 89.99,
                date: Date().addingTimeInterval(86400), // Tomorrow
                status: .pending,
                recipientName: "Phone Bill",
                notes: "T-Mobile"
            )
        ]
    }
}
