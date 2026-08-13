//
//  CalendarManager.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import EventKit
import Combine
import os

/// Manages EventKit calendar permissions and creates payment-related calendar events.
///
/// When a user enables "Add to Calendar" for a recurring payment, `CalendarManager`
/// requests `EventKit` authorization and saves an `EKEvent` with a configurable
/// reminder alarm to the user's default calendar. Events use `EKAlarm.relativeOffset`
/// so reminders fire a specified number of days before each due date.
class CalendarManager: ObservableObject {
    /// Backing `EKEventStore` used for all EventKit read/write operations.
    private let eventStore = EKEventStore()
    /// Structured logger. Payment titles/notes are user PII, so they are never
    /// interpolated into log messages (which land in the system syslog).
    private let log = Logger(subsystem: "com.pocketpay", category: "Calendar")
    /// Reflects the current calendar authorization state so the UI can show
    /// appropriate prompts or disabled states.
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    /// Shared singleton; `ServicesViewModel` calls into this instance.
    static let shared = CalendarManager()

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    private func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Prompts the user for full EventKit calendar access.
    ///
    /// Uses `requestFullAccessToEvents()` which requires the
    /// `NSCalendarsFullAccessUsageDescription` key in `Info.plist`.
    /// On iOS 17+ this method replaces the deprecated `requestAccess(to:)`.
    ///
    /// - Returns: `true` when the user granted access; `false` when denied or on error.
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            log.info("Calendar access request granted: \(granted, privacy: .public)")
            return granted
        } catch {
            log.error("Calendar access request failed")
            return false
        }
    }

    // MARK: - Event Creation with Smart Reminders

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
        // Ensure we have access
        if !(authorizationStatus == .fullAccess || authorizationStatus == .authorized) {
            guard await requestAccess() else {
                log.info("Recurring event not created: calendar access denied")
                return false
            }
        }

        // Verify we have a default calendar
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            log.error("Recurring event not created: no default calendar available")
            return false
        }

        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.calendar = defaultCalendar

        // Set the event timing
        event.startDate = startDate
        event.endDate = startDate
        event.isAllDay = true

        // Set up recurrence rule based on frequency
        let recurrenceRule = createRecurrenceRule(for: frequency)
        event.addRecurrenceRule(recurrenceRule)

        // Add Smart Reminder
        let alarm = createSmartReminder(for: reminderOffset)
        event.addAlarm(alarm)

        // Save the event
        do {
            try eventStore.save(event, span: .futureEvents)
            log.info("Recurring payment event saved")
            return true
        } catch {
            log.error("Failed to save recurring payment event")
            return false
        }
    }

    // MARK: - Smart Reminder Creation

    /// Creates an EKAlarm with relative offset based on days before
    /// - Parameter daysBefore: Number of days before event (1, 2, or 3)
    /// - Returns: EKAlarm with relative offset in seconds (negative = before the event)
    private func createSmartReminder(for daysBefore: Int) -> EKAlarm {
        // Calculate offset in seconds (negative = fires before the event date).
        // 1 day = 86400 seconds
        let secondsOffset = TimeInterval(-daysBefore * 86400)

        // EKAlarm.relativeOffset fires the alarm relative to the event's start date.
        let alarm = EKAlarm(relativeOffset: secondsOffset)
        return alarm
    }

    // MARK: - Recurrence Rules

    /// Builds an `EKRecurrenceRule` matching the given `PaymentFrequency`.
    ///
    /// - Parameter frequency: How often the payment repeats.
    /// - Returns: An `EKRecurrenceRule` with no end date (runs indefinitely).
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

    /// `true` when the app has been granted full calendar access by the user.
    var isAuthorized: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }

    /// `true` when the authorization status indicates a permission prompt is required
    /// (not yet asked) or access was previously denied.
    var needsPermission: Bool {
        authorizationStatus == .notDetermined || authorizationStatus == .denied
    }
}
