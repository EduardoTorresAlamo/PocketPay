//
//  TransferViewModel.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

class TransferViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var filteredContacts: [Contact] = []
    @Published var searchText = ""
    @Published var selectedContact: Contact?
    @Published var amount: Double = 0.0
    @Published var notes: String = ""
    @Published var isProcessing = false
    @Published var showingConfirmation = false
    @Published var showingSuccess = false
    @Published var errorMessage: String?

    private let paymentManager = PaymentManager.shared

    init() {
        loadContacts()
    }

    func loadContacts() {
        contacts = Contact.mockContacts
        filteredContacts = contacts
    }

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

    func selectContact(_ contact: Contact) {
        selectedContact = contact
        searchText = ""
        filteredContacts = contacts
    }

    func appendDigit(_ digit: String) {
        let currentAmountString = String(format: "%.2f", amount)
        let components = currentAmountString.split(separator: ".")

        if components.count == 2 {
            let cents = String(components[1])
            if cents == "00" {
                // Starting fresh
                amount = Double("0.0\(digit)") ?? 0.0
            } else if cents.first == "0" {
                // One digit after decimal
                let newCents = String(cents.last!) + digit
                amount = Double("\(components[0]).\(newCents)") ?? amount
            } else {
                // Two digits, shift left
                let dollars = components[0] + String(cents.first!)
                let newCents = String(cents.last!) + digit
                amount = Double("\(dollars).\(newCents)") ?? amount
            }
        }
    }

    func deleteLastDigit() {
        let currentAmountString = String(format: "%.2f", amount)
        let components = currentAmountString.split(separator: ".")

        if components.count == 2 {
            let dollars = String(components[0])
            let cents = String(components[1])

            if cents == "00" && dollars == "0" {
                // Already at zero
                amount = 0.0
            } else if cents.last == "0" && cents.first == "0" {
                // Only dollars, remove last dollar digit
                let newDollars = String(dollars.dropLast())
                amount = Double(newDollars.isEmpty ? "0" : newDollars) ?? 0.0
            } else {
                // Shift right
                let newCents = "0" + String(cents.first!)
                let newDollars = String(dollars + String(cents.last!)).dropLast()
                amount = Double("\(newDollars.isEmpty ? "0" : String(newDollars)).\(newCents)") ?? amount
            }
        }
    }

    func clearAmount() {
        amount = 0.0
    }

    func getFormattedAmount() -> String {
        return String(format: "$%.2f", amount)
    }

    func canSendMoney() -> Bool {
        return selectedContact != nil && amount > 0
    }

    func sendMoney() async {
        guard let contact = selectedContact else { return }

        await MainActor.run {
            self.isProcessing = true
            self.errorMessage = nil
        }

        let success = await paymentManager.sendMoney(
            to: contact,
            amount: amount,
            notes: notes.isEmpty ? nil : notes
        )

        await MainActor.run {
            self.isProcessing = false

            if success {
                self.showingSuccess = true
                // Reset form
                self.selectedContact = nil
                self.amount = 0.0
                self.notes = ""
            } else {
                self.errorMessage = paymentManager.errorMessage ?? "Transfer failed"
            }
        }
    }

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
