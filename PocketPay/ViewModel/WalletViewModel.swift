//
//  WalletViewModel.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

class WalletViewModel: ObservableObject {
    @Published var paymentMethods: [PaymentMethod] = []
    @Published var selectedPaymentMethod: PaymentMethod?
    @Published var showingAddCard = false

    static let shared = WalletViewModel()

    init() {
        loadPaymentMethods()
    }

    func loadPaymentMethods() {
        paymentMethods = PaymentMethod.loadAll()
        if selectedPaymentMethod == nil {
            selectedPaymentMethod = paymentMethods.first { $0.isDefault } ?? paymentMethods.first
        }
    }

    func addPaymentMethod(_ method: PaymentMethod) {
        var newMethod = method

        // If this is the first card or marked as default, set it as default
        if paymentMethods.isEmpty || method.isDefault {
            // Remove default from all existing cards
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

    func removePaymentMethod(_ method: PaymentMethod) {
        paymentMethods.removeAll { $0.id == method.id }

        // If we removed the default or selected card, select another
        if method.isDefault && !paymentMethods.isEmpty {
            paymentMethods[0].isDefault = true
        }

        if selectedPaymentMethod?.id == method.id {
            selectedPaymentMethod = paymentMethods.first { $0.isDefault } ?? paymentMethods.first
        }

        savePaymentMethods()
    }

    func setDefaultPaymentMethod(_ method: PaymentMethod) {
        // Remove default from all cards
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

    func selectPaymentMethod(_ method: PaymentMethod) {
        selectedPaymentMethod = method
    }

    private func savePaymentMethods() {
        PaymentMethod.saveAll(paymentMethods)
    }

    var defaultPaymentMethod: PaymentMethod? {
        return paymentMethods.first { $0.isDefault }
    }
}
