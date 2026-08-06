//
//  ServicesViewModel.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

/// ViewModel backing `ServicesView` and `AddPaymentView`.
///
/// Manages the full recurring-payment lifecycle: loading, paying, toggling
/// active/inactive, and deletion. Also owns the Add Payment form state used
/// by `AddPaymentView`.
///
/// When a new recurring payment is added with "Add to Calendar" enabled, this
/// ViewModel calls `CalendarManager.createRecurringPaymentEvent` to schedule
/// an EventKit reminder series before returning to the Services list.
///
/// Isolated to the `MainActor` at class level: every stored property is
/// `@Published` and read directly by the view.
@MainActor
class ServicesViewModel: ObservableObject {
    /// All recurring payments, including inactive ones.
    @Published var recurringPayments: [RecurringPayment] = []
    /// Subset of `recurringPayments` where `isActive == true`.
    @Published var activePayments: [RecurringPayment] = []
    /// Active payments that are due within the next 7 days, shown in the "Due Soon" section.
    @Published var duePayments: [RecurringPayment] = []
    /// `true` while a payment is being processed.
    @Published var isProcessing = false
    /// Localized error message shown when a payment fails.
    @Published var errorMessage: String?
    /// Triggers the success alert after a payment completes.
    @Published var showingSuccess = false
    /// The payment selected for detail inspection (reserved for future use).
    @Published var selectedPayment: RecurringPayment?

    // MARK: - Add Payment Form State
    // These properties are two-way bound to `AddPaymentView` form fields.

    /// Name of the biller entered in the form.
    @Published var billerName = ""
    /// Payment amount entered in the form.
    @Published var amount: Double = 0.0
    /// Selected transaction category for the new payment.
    @Published var selectedCategory: TransactionCategory = .utilities
    /// How often the new payment will repeat.
    @Published var selectedFrequency: PaymentFrequency = .monthly
    /// The first due date for the new recurring payment.
    @Published var nextPaymentDate = Date()
    /// Optional notes for the new payment.
    @Published var notes = ""
    /// When `true`, a `RecurringPayment` entry is created alongside the one-time charge.
    @Published var isRecurringEnabled = false
    /// Enables automatic payment on each due date (UI-only flag; feature not yet implemented).
    @Published var autoPayEnabled = false
    /// When `true`, an EventKit calendar event series is created via `CalendarManager`.
    @Published var addToCalendarEnabled = false
    /// Number of days before the due date the calendar reminder should fire (1, 2, or 3).
    @Published var reminderOffset: Int = 1

    private let paymentManager: any PaymentProcessing
    private let calendarManager: CalendarManager

    /// Creates the ViewModel with the given collaborators.
    ///
    /// Both default to the shared singletons so views can keep calling
    /// `ServicesViewModel()`; tests inject doubles instead.
    init(
        paymentManager: any PaymentProcessing = PaymentManager.shared,
        calendarManager: CalendarManager = .shared
    ) {
        self.paymentManager = paymentManager
        self.calendarManager = calendarManager
        loadRecurringPayments()
    }

    /// Refreshes all derived payment lists from the current `recurringPayments` array.
    func loadRecurringPayments() {
        recurringPayments = RecurringPayment.mockRecurringPayments
        activePayments = recurringPayments.filter { $0.isActive }
        duePayments = recurringPayments.filter { $0.isActive && $0.isDueSoon }
    }

    /// Pays an existing recurring bill immediately and advances its next due date.
    ///
    /// Delegates the charge to `PaymentManager.payBusiness`. On success, the
    /// payment's `lastPaymentDate` is set to now and `nextPaymentDate` is advanced
    /// by one cycle using `PaymentFrequency.nextDate(from:)`.
    ///
    /// - Parameter payment: The recurring payment to charge now.
    func payBill(payment: RecurringPayment) async {
        isProcessing = true
        errorMessage = nil

        let success = await paymentManager.payBusiness(
            name: payment.billerName,
            amount: payment.amount,
            notes: payment.notes
        )

        isProcessing = false

        if success {
            showingSuccess = true
            // Update the next payment date
            if let index = recurringPayments.firstIndex(where: { $0.id == payment.id }) {
                recurringPayments[index].lastPaymentDate = Date()
                recurringPayments[index].nextPaymentDate = payment.frequency.nextDate(from: Date())
            }
            loadRecurringPayments()
        } else {
            errorMessage = paymentManager.errorMessage ?? "Payment failed"
        }
    }

    /// Pays a one-time bill using the current form state, optionally creating a
    /// recurring schedule and calendar reminder series.
    ///
    /// Flow:
    /// 1. Validates `billerName` and `amount`.
    /// 2. Delegates the charge to `PaymentManager.payBusiness`.
    /// 3. If `isRecurringEnabled`, creates a new `RecurringPayment` entry.
    /// 4. If `addToCalendarEnabled`, requests EventKit access and creates a
    ///    recurring calendar event via `CalendarManager`.
    /// 5. Resets the form on success.
    func payOneTimeBill() async {
        guard !billerName.isEmpty, amount > 0 else {
            errorMessage = "Please fill in all required fields"
            return
        }

        isProcessing = true
        errorMessage = nil

        let success = await paymentManager.payBusiness(
            name: billerName,
            amount: amount,
            notes: notes.isEmpty ? nil : notes
        )

        // If payment succeeded and recurring is enabled, create the recurring payment
        if success, isRecurringEnabled {
            let newRecurring = RecurringPayment(
                billerName: billerName,
                amount: amount,
                frequency: selectedFrequency,
                category: selectedCategory,
                nextPaymentDate: selectedFrequency.nextDate(from: Date()),
                isActive: true,
                lastPaymentDate: Date(),
                notes: notes.isEmpty ? nil : notes,
                autoPayEnabled: autoPayEnabled
            )

            // Add to Calendar if enabled
            if addToCalendarEnabled {
                print("📱 ServicesViewModel: Creating calendar event...")
                let calendarSuccess = await calendarManager.createRecurringPaymentEvent(
                    title: "Pay \(billerName)",
                    notes: notes.isEmpty ? nil : notes,
                    startDate: newRecurring.nextPaymentDate,
                    frequency: newRecurring.frequency,
                    reminderOffset: reminderOffset
                )

                if !calendarSuccess {
                    print("❌ ServicesViewModel: Calendar event creation failed")
                    errorMessage = "Payment created but calendar event failed. Check calendar permissions."
                } else {
                    print("✅ ServicesViewModel: Calendar event created successfully")
                }
            }

            recurringPayments.append(newRecurring)
            loadRecurringPayments()
        }

        isProcessing = false

        if success {
            showingSuccess = true
            resetForm()
        } else {
            errorMessage = paymentManager.errorMessage ?? "Payment failed"
        }
    }

    /// Toggles the active/inactive state of a recurring payment.
    ///
    /// - Parameter payment: The payment whose `isActive` flag should be flipped.
    func togglePaymentStatus(_ payment: RecurringPayment) {
        if let index = recurringPayments.firstIndex(where: { $0.id == payment.id }) {
            recurringPayments[index].isActive.toggle()
            loadRecurringPayments()
        }
    }

    /// Permanently removes a recurring payment from the in-memory list.
    ///
    /// - Parameter payment: The payment to delete.
    func deleteRecurringPayment(_ payment: RecurringPayment) {
        recurringPayments.removeAll { $0.id == payment.id }
        loadRecurringPayments()
    }

    /// Resets all Add Payment form fields to their default values.
    func resetForm() {
        billerName = ""
        amount = 0.0
        notes = ""
        isRecurringEnabled = false
        autoPayEnabled = false
        addToCalendarEnabled = false
        reminderOffset = 1
        selectedCategory = .utilities
        selectedFrequency = .monthly
        nextPaymentDate = Date()
    }

    /// Returns the current form amount formatted as a USD currency string.
    func getFormattedAmount() -> String {
        return String(format: "$%.2f", amount)
    }

    /// Filters active payments by their `TransactionCategory`.
    ///
    /// - Parameter category: The category to filter by.
    /// - Returns: Active recurring payments in that category.
    func getActivePaymentsByCategory(_ category: TransactionCategory) -> [RecurringPayment] {
        return activePayments.filter { $0.category == category }
    }

    /// The estimated total monthly cost across all active recurring payments.
    ///
    /// Each payment's amount is normalized to a monthly equivalent so that
    /// weekly, quarterly, and yearly payments can be summed into one comparable figure.
    var totalMonthlyRecurring: Double {
        return activePayments.reduce(0) { total, payment in
            // Normalize each payment frequency to a monthly equivalent cost.
            switch payment.frequency {
            case .weekly:
                return total + (payment.amount * 4)
            case .biWeekly:
                return total + (payment.amount * 2)
            case .monthly:
                return total + payment.amount
            case .quarterly:
                return total + (payment.amount / 3)
            case .yearly:
                return total + (payment.amount / 12)
            }
        }
    }
}
