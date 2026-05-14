//
//  ServicesViewModel.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

class ServicesViewModel: ObservableObject {
    @Published var recurringPayments: [RecurringPayment] = []
    @Published var activePayments: [RecurringPayment] = []
    @Published var duePayments: [RecurringPayment] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showingSuccess = false
    @Published var selectedPayment: RecurringPayment?

    // Add Payment Form
    @Published var billerName = ""
    @Published var amount: Double = 0.0
    @Published var selectedCategory: TransactionCategory = .utilities
    @Published var selectedFrequency: PaymentFrequency = .monthly
    @Published var nextPaymentDate = Date()
    @Published var notes = ""
    @Published var isRecurringEnabled = false
    @Published var autoPayEnabled = false
    @Published var addToCalendarEnabled = false
    @Published var reminderOffset: Int = 1

    private let paymentManager = PaymentManager.shared
    private let calendarManager = CalendarManager.shared

    init() {
        loadRecurringPayments()
    }

    func loadRecurringPayments() {
        recurringPayments = RecurringPayment.mockRecurringPayments
        activePayments = recurringPayments.filter { $0.isActive }
        duePayments = recurringPayments.filter { $0.isActive && $0.isDueSoon }
    }

    func payBill(payment: RecurringPayment) async {
        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }

        let success = await paymentManager.payBusiness(
            name: payment.billerName,
            amount: payment.amount,
            notes: payment.notes
        )

        await MainActor.run {
            self.isProcessing = false

            if success {
                self.showingSuccess = true
                // Update the next payment date
                if let index = self.recurringPayments.firstIndex(where: { $0.id == payment.id }) {
                    self.recurringPayments[index].lastPaymentDate = Date()
                    self.recurringPayments[index].nextPaymentDate = payment.frequency.nextDate(from: Date())
                }
                self.loadRecurringPayments()
            } else {
                self.errorMessage = paymentManager.errorMessage ?? "Payment failed"
            }
        }
    }

    func payOneTimeBill() async {
        guard !billerName.isEmpty, amount > 0 else {
            await MainActor.run {
                self.errorMessage = "Please fill in all required fields"
            }
            return
        }

        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }

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
                    await MainActor.run {
                        self.errorMessage = "Payment created but calendar event failed. Check calendar permissions."
                    }
                } else {
                    print("✅ ServicesViewModel: Calendar event created successfully")
                }
            }

            await MainActor.run {
                self.recurringPayments.append(newRecurring)
                self.loadRecurringPayments()
            }
        }

        await MainActor.run {
            self.isProcessing = false

            if success {
                self.showingSuccess = true
                self.resetForm()
            } else {
                self.errorMessage = paymentManager.errorMessage ?? "Payment failed"
            }
        }
    }

    func togglePaymentStatus(_ payment: RecurringPayment) {
        if let index = recurringPayments.firstIndex(where: { $0.id == payment.id }) {
            recurringPayments[index].isActive.toggle()
            loadRecurringPayments()
        }
    }

    func deleteRecurringPayment(_ payment: RecurringPayment) {
        recurringPayments.removeAll { $0.id == payment.id }
        loadRecurringPayments()
    }

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

    func getFormattedAmount() -> String {
        return String(format: "$%.2f", amount)
    }

    func getActivePaymentsByCategory(_ category: TransactionCategory) -> [RecurringPayment] {
        return activePayments.filter { $0.category == category }
    }

    var totalMonthlyRecurring: Double {
        return activePayments.reduce(0) { total, payment in
            // Normalize to monthly
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
