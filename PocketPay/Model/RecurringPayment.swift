//
//  RecurringPayment.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import SwiftUI

// MARK: - Payment Frequency
enum PaymentFrequency: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case biWeekly = "Bi-Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"

    var displayName: String {
        return self.rawValue
    }

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

    // Calculate next payment date based on frequency
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
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

// MARK: - Recurring Payment Model
struct RecurringPayment: Identifiable, Codable {
    let id: UUID
    var billerName: String
    var amount: Double
    var frequency: PaymentFrequency
    var category: TransactionCategory
    var nextPaymentDate: Date
    var isActive: Bool
    var lastPaymentDate: Date?
    var notes: String?
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

    var formattedAmount: String {
        return String(format: "$%.2f", amount)
    }

    var formattedNextPaymentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: nextPaymentDate)
    }

    var daysUntilNextPayment: Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let next = calendar.startOfDay(for: nextPaymentDate)
        let components = calendar.dateComponents([.day], from: now, to: next)
        return components.day ?? 0
    }

    var isDueSoon: Bool {
        let days = daysUntilNextPayment
        return days >= 0 && days <= 7 // Due within a week
    }

    var isOverdue: Bool {
        return daysUntilNextPayment < 0
    }

    var statusColor: Color {
        if isOverdue {
            return AppConstants.Colors.errorRed
        } else if isDueSoon {
            return AppConstants.Colors.warningOrange
        } else {
            return AppConstants.Colors.successGreen
        }
    }

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
