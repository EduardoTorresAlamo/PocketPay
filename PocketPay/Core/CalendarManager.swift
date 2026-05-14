//
//  CalendarManager.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import EventKit
import Combine

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    static let shared = CalendarManager()

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    private func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        print("📅 CalendarManager: Requesting calendar access...")
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                print("📅 CalendarManager: Authorization status: \(self.authorizationStatus.rawValue)")
            }
            if granted {
                print("✅ CalendarManager: User granted calendar access")
            } else {
                print("❌ CalendarManager: User denied calendar access")
            }
            return granted
        } catch {
            print("❌ CalendarManager: Calendar access error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Event Creation with Smart Reminders

    /// Creates a calendar event for a recurring payment with a custom reminder offset
    /// - Parameters:
    ///   - title: Event title (e.g., "Pay Electric Bill")
    ///   - notes: Additional notes about the payment
    ///   - dueDate: When the payment is due
    ///   - reminderOffset: Days before due date to remind (1, 2, or 3)
    /// - Returns: Success status
    func createPaymentEvent(
        title: String,
        notes: String?,
        dueDate: Date,
        reminderOffset: Int = 1
    ) async -> Bool {
        // Ensure we have access
        if !(authorizationStatus == .fullAccess || authorizationStatus == .authorized) {
            guard await requestAccess() else { return false }
        }

        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Set the event to the due date (all-day event)
        event.startDate = dueDate
        event.endDate = dueDate
        event.isAllDay = true

        // Add Smart Reminder with relative offset
        let alarm = createSmartReminder(for: reminderOffset)
        event.addAlarm(alarm)

        // Save the event
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("Error saving calendar event: \(error.localizedDescription)")
            return false
        }
    }

    /// Creates a recurring calendar event for subscription payments
    /// - Parameters:
    ///   - title: Event title
    ///   - notes: Additional notes
    ///   - startDate: First payment date
    ///   - frequency: How often the payment recurs
    ///   - reminderOffset: Days before each payment to remind (1, 2, or 3)
    /// - Returns: Success status
    func createRecurringPaymentEvent(
        title: String,
        notes: String?,
        startDate: Date,
        frequency: PaymentFrequency,
        reminderOffset: Int = 1
    ) async -> Bool {
        print("📅 CalendarManager: Starting to create recurring event '\(title)'")

        // Ensure we have access
        if !(authorizationStatus == .fullAccess || authorizationStatus == .authorized) {
            print("📅 CalendarManager: Not authorized, requesting access...")
            guard await requestAccess() else {
                print("❌ CalendarManager: Access denied")
                return false
            }
            print("✅ CalendarManager: Access granted")
        } else {
            print("✅ CalendarManager: Already authorized")
        }

        // Verify we have a default calendar
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            print("❌ CalendarManager: No default calendar available")
            return false
        }
        print("📅 CalendarManager: Using calendar: \(defaultCalendar.title)")

        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.calendar = defaultCalendar

        // Set the event timing
        event.startDate = startDate
        event.endDate = startDate
        event.isAllDay = true

        print("📅 CalendarManager: Event date: \(startDate)")

        // Set up recurrence rule based on frequency
        let recurrenceRule = createRecurrenceRule(for: frequency)
        event.addRecurrenceRule(recurrenceRule)
        print("📅 CalendarManager: Recurrence rule: \(frequency.rawValue)")

        // Add Smart Reminder
        let alarm = createSmartReminder(for: reminderOffset)
        event.addAlarm(alarm)
        print("📅 CalendarManager: Reminder: \(reminderOffset) day(s) before")

        // Save the event
        do {
            try eventStore.save(event, span: .futureEvents)
            print("✅ CalendarManager: Event saved successfully!")
            return true
        } catch {
            print("❌ CalendarManager: Error saving event: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Smart Reminder Creation

    /// Creates an EKAlarm with relative offset based on days before
    /// - Parameter daysBefor: Number of days before event (1, 2, or 3)
    /// - Returns: EKAlarm with relative offset
    private func createSmartReminder(for daysBefore: Int) -> EKAlarm {
        // Calculate offset in seconds (negative for before the event)
        // 1 day = 86400 seconds
        let secondsOffset = TimeInterval(-daysBefore * 86400)

        // Create alarm with relative offset
        let alarm = EKAlarm(relativeOffset: secondsOffset)
        return alarm
    }

    // MARK: - Recurrence Rules

    private func createRecurrenceRule(for frequency: PaymentFrequency) -> EKRecurrenceRule {
        switch frequency {
        case .weekly:
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: nil
            )
        case .biWeekly:
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 2,
                end: nil
            )
        case .monthly:
            return EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 1,
                end: nil
            )
        case .quarterly:
            return EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 3,
                end: nil
            )
        case .yearly:
            return EKRecurrenceRule(
                recurrenceWith: .yearly,
                interval: 1,
                end: nil
            )
        }
    }

    // MARK: - Helper Methods

    var isAuthorized: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }

    var needsPermission: Bool {
        authorizationStatus == .notDetermined || authorizationStatus == .denied
    }
}
