//
//  TransferViewModel.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

/// ViewModel backing `TransferView` (the P2P money-send flow).
///
/// The transfer flow has two phases managed by `selectedContact`:
/// - Phase 1 (`selectedContact == nil`): Contact selection and search.
/// - Phase 2 (`selectedContact != nil`): Custom numeric keypad entry and send confirmation.
///
/// The numeric keypad uses a fixed-decimal representation: `amount` is always
/// kept as dollars with exactly two decimal places, and `appendDigit` / `deleteLastDigit`
/// implement a shift-register style input so users type cents first (e.g., pressing
/// "1", "5", "0" results in "$1.50").
class TransferViewModel: ObservableObject {
    /// Full contact list loaded from the mock source.
    @Published var contacts: [Contact] = []
    /// Subset of `contacts` matching the current `searchText`.
    @Published var filteredContacts: [Contact] = []
    /// Live search query bound to the contact search field.
    @Published var searchText = ""
    /// The contact the user has chosen to send to. Setting this nil returns to Phase 1.
    @Published var selectedContact: Contact?
    /// Transfer amount in USD, managed by the custom keypad.
    @Published var amount: Double = 0.0
    /// Optional memo string attached to the outgoing transaction.
    @Published var notes: String = ""
    /// `true` while the Stripe payment call is in flight.
    @Published var isProcessing = false
    /// Reserved for a future confirmation step before submission.
    @Published var showingConfirmation = false
    /// Triggers the success alert when the payment completes.
    @Published var showingSuccess = false
    /// Holds the error message when a payment attempt fails.
    @Published var errorMessage: String?

    private let paymentManager = PaymentManager.shared

    init() {
        loadContacts()
    }

    /// Loads the mock contact list and initializes the filtered view.
    func loadContacts() {
        contacts = Contact.mockContacts
        filteredContacts = contacts
    }

    /// Filters `contacts` by name or phone number to update `filteredContacts`.
    ///
    /// Called whenever `searchText` changes via `onChange` in `ContactSelectionView`.
    func searchContacts() {
        if searchText.isEmpty {
            filteredContacts = contacts
        } else {
            filteredContacts = contacts.filter { contact in
                contact.name.localizedCaseInsensitiveContains(searchText) ||
                contact.phoneNumber.contains(searchText)
            }
        }
    }

    /// Moves to Phase 2 (amount entry) by setting the selected contact and clearing the search.
    ///
    /// - Parameter contact: The contact chosen from the list.
    func selectContact(_ contact: Contact) {
        selectedContact = contact
        searchText = ""
        // Reset the filter so all contacts are visible if the user navigates back.
        filteredContacts = contacts
    }

    /// Appends a digit to the custom keypad amount using shift-register arithmetic.
    ///
    /// The amount is always expressed as `dollars.cents` with exactly two
    /// fractional digits. Each new digit is added to the rightmost cents
    /// position and the existing digits shift left:
    ///
    /// ```
    /// amount = 0.00  + "1" -> 0.01
    /// amount = 0.01  + "5" -> 0.15
    /// amount = 0.15  + "0" -> 1.50
    /// amount = 1.50  + "3" -> 15.03
    /// ```
    ///
    /// - Parameter digit: A single-character digit string (`"0"` through `"9"`).
    func appendDigit(_ digit: String) {
        let currentAmountString = String(format: "%.2f", amount)
        let components = currentAmountString.split(separator: ".")

        if components.count == 2 {
            let cents = String(components[1])
            if cents == "00" {
                // Starting fresh from zero: place the digit in the rightmost cent position.
                amount = Double("0.0\(digit)") ?? 0.0
            } else if cents.first == "0" {
                // One significant cent digit: shift it left and add the new digit on the right.
                let newCents = String(cents.last!) + digit
                amount = Double("\(components[0]).\(newCents)") ?? amount
            } else {
                // Two significant cent digits: shift the leftmost cent into dollars.
                let dollars = components[0] + String(cents.first!)
                let newCents = String(cents.last!) + digit
                amount = Double("\(dollars).\(newCents)") ?? amount
            }
        }
    }

    /// Removes the last entered digit from the keypad amount by shifting right.
    ///
    /// Reverses the shift-register operation of `appendDigit`:
    /// ```
    /// amount = 15.03 -> delete -> 1.50
    /// amount = 1.50  -> delete -> 0.15
    /// ```
    func deleteLastDigit() {
        let currentAmountString = String(format: "%.2f", amount)
        let components = currentAmountString.split(separator: ".")

        if components.count == 2 {
            let dollars = String(components[0])
            let cents = String(components[1])

            if cents == "00" && dollars == "0" {
                // Already at zero; nothing to delete.
                amount = 0.0
            } else if cents.last == "0" && cents.first == "0" {
                // Only dollars remain; remove the least significant dollar digit.
                let newDollars = String(dollars.dropLast())
                amount = Double(newDollars.isEmpty ? "0" : newDollars) ?? 0.0
            } else {
                // Shift right: move the rightmost dollar digit into the cents position.
                let newCents = "0" + String(cents.first!)
                let newDollars = String(dollars + String(cents.last!)).dropLast()
                amount = Double("\(newDollars.isEmpty ? "0" : String(newDollars)).\(newCents)") ?? amount
            }
        }
    }

    /// Resets the keypad amount to zero.
    func clearAmount() {
        amount = 0.0
    }

    /// Returns the current amount formatted as a USD currency string (e.g., `"$25.00"`).
    func getFormattedAmount() -> String {
        return String(format: "$%.2f", amount)
    }

    /// `true` when both a recipient contact is selected and the amount is greater than zero.
    func canSendMoney() -> Bool {
        return selectedContact != nil && amount > 0
    }

    /// Submits the transfer to `PaymentManager` and handles the result.
    ///
    /// Resets the form on success and populates `errorMessage` on failure.
    func sendMoney() async {
        guard let contact = selectedContact else { return }

        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }

        let success = await paymentManager.sendMoney(
            to: contact,
            amount: amount,
            // Pass nil instead of an empty string to keep the Transaction.notes field clean.
            notes: notes.isEmpty ? nil : notes
        )

        await MainActor.run {
            self.isProcessing = false

            if success {
                self.showingSuccess = true
                // Reset form after successful send so the sheet is clean on next open.
                self.selectedContact = nil
                self.amount = 0.0
                self.notes = ""
            } else {
                self.errorMessage = paymentManager.errorMessage ?? "Transfer failed"
            }
        }
    }

    /// Resets all ViewModel state to initial values.
    func reset() {
        selectedContact = nil
        amount = 0.0
        notes = ""
        searchText = ""
        showingConfirmation = false
        showingSuccess = false
        errorMessage = nil
    }
}
