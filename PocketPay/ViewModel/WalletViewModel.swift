//
//  WalletViewModel.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

/// ViewModel backing `WalletView` and `AddCardView`.
///
/// Manages the list of saved payment methods and enforces the single-default-card
/// invariant: exactly one card may have `isDefault == true` at any time.
/// Changes are persisted to `UserDefaults` via `PaymentMethod.saveAll` after
/// every mutating operation.
///
/// This ViewModel is a singleton (`WalletViewModel.shared`) because `WalletView`
/// uses `@StateObject` with the shared instance, ensuring the carousel selection
/// index survives tab switches.
///
/// Isolated to the `MainActor` at class level: every stored property is
/// `@Published` and read directly by the view.
@MainActor
class WalletViewModel: ObservableObject {
    /// The user's full list of saved cards, ordered by insertion.
    @Published var paymentMethods: [PaymentMethod] = []
    /// The card currently highlighted in the carousel. Updated when the user
    /// swipes the card deck or taps a row in the list below.
    @Published var selectedPaymentMethod: PaymentMethod?
    /// Controls presentation of the `AddCardView` sheet.
    @Published var showingAddCard = false

    /// Shared instance used by both `WalletView` and `AddCardView`.
    static let shared = WalletViewModel()

    init() {
        loadPaymentMethods()
    }

    /// Loads cards from `UserDefaults` (or mock data on first launch) and
    /// pre-selects the default card.
    func loadPaymentMethods() {
        paymentMethods = PaymentMethod.loadAll()
        // Auto-select the default card; fall back to the first card if no default is set.
        if selectedPaymentMethod == nil {
            selectedPaymentMethod = paymentMethods.first { $0.isDefault } ?? paymentMethods.first
        }
    }

    /// Adds a new payment method to the wallet.
    ///
    /// Enforces the single-default invariant: if the new card is the first card
    /// ever added, or if `method.isDefault` is `true`, all existing cards are
    /// de-defaulted and the new card becomes the default.
    ///
    /// - Parameter method: The card to add.
    func addPaymentMethod(_ method: PaymentMethod) {
        var newMethod = method

        // If this is the first card or marked as default, set it as default
        if paymentMethods.isEmpty || method.isDefault {
            // Remove default from all existing cards before setting the new one.
            for index in paymentMethods.indices {
                paymentMethods[index].isDefault = false
            }
            newMethod.isDefault = true
        }

        paymentMethods.append(newMethod)
        savePaymentMethods()

        // Set as selected if it's the default
        if newMethod.isDefault {
            selectedPaymentMethod = newMethod
        }
    }

    /// Removes a payment method from the wallet.
    ///
    /// If the removed card was the default, the first remaining card automatically
    /// becomes the new default. Updates `selectedPaymentMethod` if the removed
    /// card was the one currently shown in the carousel.
    ///
    /// - Parameter method: The card to remove.
    func removePaymentMethod(_ method: PaymentMethod) {
        paymentMethods.removeAll { $0.id == method.id }

        // Promote the first remaining card to default if the default was just removed.
        if method.isDefault && !paymentMethods.isEmpty {
            paymentMethods[0].isDefault = true
        }

        if selectedPaymentMethod?.id == method.id {
            selectedPaymentMethod = paymentMethods.first { $0.isDefault } ?? paymentMethods.first
        }

        savePaymentMethods()
    }

    /// Makes a specific card the wallet's default payment method.
    ///
    /// De-defaults all other cards, sets the specified card as default, and
    /// updates `selectedPaymentMethod` to that card.
    ///
    /// - Parameter method: The card to promote to default.
    func setDefaultPaymentMethod(_ method: PaymentMethod) {
        // Remove default from all cards to maintain the single-default invariant.
        for index in paymentMethods.indices {
            paymentMethods[index].isDefault = false
        }

        // Set this card as default
        if let index = paymentMethods.firstIndex(where: { $0.id == method.id }) {
            paymentMethods[index].isDefault = true
            selectedPaymentMethod = paymentMethods[index]
        }

        savePaymentMethods()
    }

    /// Updates `selectedPaymentMethod` to the given card without changing the default.
    ///
    /// - Parameter method: The card to highlight in the carousel.
    func selectPaymentMethod(_ method: PaymentMethod) {
        selectedPaymentMethod = method
    }

    private func savePaymentMethods() {
        PaymentMethod.saveAll(paymentMethods)
    }

    /// The card currently flagged as `isDefault`, or `nil` if the wallet is empty.
    var defaultPaymentMethod: PaymentMethod? {
        return paymentMethods.first { $0.isDefault }
    }
}
