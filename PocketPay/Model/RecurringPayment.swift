//
//  RecurringPayment.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import SwiftUI

// MARK: - Payment Frequency

/// How often a recurring payment repeats.
///
/// Used by `CalendarManager` to choose the correct `EKRecurrenceRule` and
/// by `ServicesViewModel.totalMonthlyRecurring` to normalize amounts for display.
enum PaymentFrequency: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case biWeekly = "Bi-Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"

    /// Human-readable label shown in pickers and list rows.
    var displayName: String {
        return self.rawValue
    }

    /// SF Symbol name used in frequency picker rows.
    var icon: String {
        switch self {
        case .weekly:
            return "calendar.badge.clock"
        case .biWeekly:
            return "calendar"
        case .monthly:
            return "calendar.circle"
        case .quarterly:
            return "calendar.badge.plus"
        case .yearly:
            return "calendar.badge.exclamationmark"
        }
    }

    /// Computes the next occurrence of a payment based on this frequency.
    ///
    /// - Parameter date: The reference date (typically the most recent payment date).
    /// - Returns: The next due date after `date`. Returns `date` unchanged if
    ///   `Calendar.date(byAdding:)` fails (e.g., on an overflow date).
    func nextDate(from date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biWeekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            // Quarterly = every 3 months
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

// MARK: - Recurring Payment Model

/// A scheduled repeating payment such as rent, a subscription, or a utility bill.
///
/// `RecurringPayment` drives the Services tab. Each item tracks its schedule
/// (`frequency`, `nextPaymentDate`), its status flags (`isActive`, `autoPayEnabled`),
/// and links into `ServicesViewModel` for pay/toggle/delete actions.
struct RecurringPayment: Identifiable, Codable, Hashable {
    /// Stable identifier used for list diffing and linking to `Transaction.recurringPaymentId`.
    let id: UUID
    /// Display name of the biller shown in the Services list.
    var billerName: String
    /// Amount due each payment cycle, in USD.
    var amount: Double
    /// How often the payment recurs (weekly, monthly, etc.).
    var frequency: PaymentFrequency
    /// Semantic category used for icon and color in the UI.
    var category: TransactionCategory
    /// The date the next payment is due. Updated after each successful payment.
    var nextPaymentDate: Date
    /// `false` when the user has paused this recurring payment.
    var isActive: Bool
    /// Date of the most recent successful payment; `nil` if the payment has never been made.
    var lastPaymentDate: Date?
    /// Optional user-supplied memo forwarded to each generated transaction.
    var notes: String?
    /// When `true`, the payment will be processed automatically on `nextPaymentDate`
    /// without requiring manual confirmation (not yet implemented; reserved for future use).
    var autoPayEnabled: Bool

    init(
        id: UUID = UUID(),
        billerName: String,
        amount: Double,
        frequency: PaymentFrequency,
        category: TransactionCategory,
        nextPaymentDate: Date,
        isActive: Bool = true,
        lastPaymentDate: Date? = nil,
        notes: String? = nil,
        autoPayEnabled: Bool = false
    ) {
        self.id = id
        self.billerName = billerName
        self.amount = amount
        self.frequency = frequency
        self.category = category
        self.nextPaymentDate = nextPaymentDate
        self.isActive = isActive
        self.lastPaymentDate = lastPaymentDate
        self.notes = notes
        self.autoPayEnabled = autoPayEnabled
    }

    /// Amount formatted as a currency string, e.g., `"$125.50"`.
    var formattedAmount: String {
        return CurrencyFormatter.format(amount)
    }

    /// Next payment date formatted as `"Jan 5, 2026"`.
    var formattedNextPaymentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: nextPaymentDate)
    }

    /// Number of calendar days between today and `nextPaymentDate`.
    ///
    /// Negative values indicate the payment is overdue. Uses `startOfDay` to
    /// ignore time-of-day differences so a payment due "today" shows 0, not -1.
    var daysUntilNextPayment: Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let next = calendar.startOfDay(for: nextPaymentDate)
        let components = calendar.dateComponents([.day], from: now, to: next)
        return components.day ?? 0
    }

    /// `true` when the payment is due within the next 7 days (inclusive of today).
    var isDueSoon: Bool {
        let days = daysUntilNextPayment
        return days >= 0 && days <= 7 // Due within a week
    }

    /// `true` when `nextPaymentDate` is in the past.
    var isOverdue: Bool {
        return daysUntilNextPayment < 0
    }

    /// Color used for the status badge: red for overdue, orange for due soon, green otherwise.
    var statusColor: Color {
        if isOverdue {
            return AppConstants.Colors.errorRed
        } else if isDueSoon {
            return AppConstants.Colors.warningOrange
        } else {
            return AppConstants.Colors.successGreen
        }
    }

    /// Short human-readable status label shown on the payment card.
    var statusText: String {
        if !isActive {
            return "Inactive"
        } else if isOverdue {
            return "Overdue"
        } else if isDueSoon {
            return "Due Soon"
        } else {
            return "Active"
        }
    }

    // MARK: - Mock Recurring Payments
    static var mockRecurringPayments: [RecurringPayment] {
        let calendar = Calendar.current
        let now = Date()

        return [
            // Rent - Due in 3 days
            RecurringPayment(
                billerName: "Apartment 4B",
                amount: 1200.00,
                frequency: .monthly,
                category: .rent,
                nextPaymentDate: calendar.date(byAdding: .day, value: 3, to: now)!,
                isActive: true,
                lastPaymentDate: calendar.date(byAdding: .day, value: -27, to: now),
                notes: "Monthly rent payment",
                autoPayEnabled: true
            ),
            // Netflix - Due in 12 days
            RecurringPayment(
                billerName: "Netflix",
                amount: 15.99,
                frequency: .monthly,
                category: .subscription,
                nextPaymentDate: calendar.date(byAdding: .day, value: 12, to: now)!,
                isActive: true,
                lastPaymentDate: calendar.date(byAdding: .day, value: -18, to: now),
                notes: "Premium plan",
                autoPayEnabled: true
            ),
            // Spotify - Due in 15 days
            RecurringPayment(
                billerName: "Spotify",
                amount: 9.99,
                frequency: .monthly,
                category: .subscription,
                nextPaymentDate: calendar.date(byAdding: .day, value: 15, to: now)!,
                isActive: true,
                lastPaymentDate: calendar.date(byAdding: .day, value: -15, to: now),
                notes: "Student plan",
                autoPayEnabled: true
            ),
            // Electric Bill - Due in 5 days
            RecurringPayment(
                billerName: "LUMA Energy",
                amount: 125.50,
                frequency: .monthly,
                category: .utilities,
                nextPaymentDate: calendar.date(byAdding: .day, value: 5, to: now)!,
                isActive: true,
                lastPaymentDate: calendar.date(byAdding: .day, value: -25, to: now),
                notes: "Electric bill",
                autoPayEnabled: false
            ),
            // Internet - Due in 2 days (Due Soon)
            RecurringPayment(
                billerName: "Liberty Internet",
                amount: 79.99,
                frequency: .monthly,
                category: .utilities,
                nextPaymentDate: calendar.date(byAdding: .day, value: 2, to: now)!,
                isActive: true,
                lastPaymentDate: calendar.date(byAdding: .day, value: -28, to: now),
                notes: "Fiber 500MB",
                autoPayEnabled: true
            ),
            // HOA - Due in 25 days
            RecurringPayment(
                billerName: "HOA Management",
                amount: 250.00,
                frequency: .monthly,
                category: .general,
                nextPaymentDate: calendar.date(byAdding: .day, value: 25, to: now)!,
                isActive: true,
                lastPaymentDate: calendar.date(byAdding: .day, value: -5, to: now),
                notes: "Monthly HOA fee",
                autoPayEnabled: true
            ),
            // Gym - Inactive
            RecurringPayment(
                billerName: "Planet Fitness",
                amount: 35.00,
                frequency: .monthly,
                category: .subscription,
                nextPaymentDate: calendar.date(byAdding: .day, value: 10, to: now)!,
                isActive: false,
                lastPaymentDate: calendar.date(byAdding: .day, value: -20, to: now),
                notes: "Monthly membership",
                autoPayEnabled: false
            ),
            // Apple iCloud - Due in 20 days
            RecurringPayment(
                billerName: "Apple iCloud",
                amount: 2.99,
                frequency: .monthly,
                category: .subscription,
                nextPaymentDate: calendar.date(byAdding: .day, value: 20, to: now)!,
                isActive: true,
                lastPaymentDate: calendar.date(byAdding: .day, value: -10, to: now),
                notes: "200GB storage",
                autoPayEnabled: true
            ),
            // Car Insurance - Due in 60 days
            RecurringPayment(
                billerName: "Triple S Insurance",
                amount: 150.00,
                frequency: .monthly,
                category: .general,
                nextPaymentDate: calendar.date(byAdding: .day, value: 60, to: now)!,
                isActive: true,
                lastPaymentDate: calendar.date(byAdding: .day, value: -30, to: now),
                notes: "Auto insurance",
                autoPayEnabled: true
            )
        ]
    }
}
