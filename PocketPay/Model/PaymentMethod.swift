//
//  PaymentMethod.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import SwiftUI

// MARK: - Card Brand
enum CardBrand: String, Codable, CaseIterable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "American Express"
    case discover = "Discover"
    case other = "Other"

    var icon: String {
        switch self {
        case .visa:
            return "creditcard.fill"
        case .mastercard:
            return "creditcard.circle.fill"
        case .amex:
            return "creditcard"
        case .discover:
            return "creditcard.fill"
        case .other:
            return "creditcard"
        }
    }
}

// MARK: - Card Color Theme
enum CardColorTheme: String, Codable, CaseIterable {
    case purple = "Purple"
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    case black = "Black"

    var gradient: [Color] {
        switch self {
        case .purple:
            return [Color(hex: "#8A2BE2"), Color(hex: "#9370DB")]
        case .blue:
            return [Color(hex: "#4A90E2"), Color(hex: "#50C878")]
        case .green:
            return [Color(hex: "#00C853"), Color(hex: "#64DD17")]
        case .orange:
            return [Color(hex: "#FF6B35"), Color(hex: "#F7931E")]
        case .pink:
            return [Color(hex: "#FF6B9D"), Color(hex: "#C44569")]
        case .black:
            return [Color(hex: "#2C3E50"), Color(hex: "#34495E")]
        }
    }
}

// MARK: - Payment Method Model
struct PaymentMethod: Identifiable, Codable {
    let id: UUID
    var cardBrand: CardBrand
    var last4Digits: String
    var expiryDate: String // Format: "MM/YY"
    var cardHolderName: String
    var colorTheme: CardColorTheme
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        cardBrand: CardBrand,
        last4Digits: String,
        expiryDate: String,
        cardHolderName: String,
        colorTheme: CardColorTheme = .purple,
        isDefault: Bool = false
    ) {
        self.id = id
        self.cardBrand = cardBrand
        self.last4Digits = last4Digits
        self.expiryDate = expiryDate
        self.cardHolderName = cardHolderName
        self.colorTheme = colorTheme
        self.isDefault = isDefault
    }

    var displayName: String {
        return "\(cardBrand.rawValue) •••• \(last4Digits)"
    }

    var maskedNumber: String {
        return "•••• •••• •••• \(last4Digits)"
    }

    var isExpired: Bool {
        guard let month = Int(expiryDate.prefix(2)),
              let year = Int("20" + expiryDate.suffix(2)) else {
            return false
        }

        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        if year < currentYear {
            return true
        } else if year == currentYear && month < currentMonth {
            return true
        }

        return false
    }

    // MARK: - Mock Payment Methods
    static var mockPaymentMethods: [PaymentMethod] {
        [
            PaymentMethod(
                cardBrand: .visa,
                last4Digits: "1234",
                expiryDate: "12/26",
                cardHolderName: "John Doe",
                colorTheme: .purple,
                isDefault: true
            ),
            PaymentMethod(
                cardBrand: .mastercard,
                last4Digits: "5678",
                expiryDate: "03/27",
                cardHolderName: "John Doe",
                colorTheme: .blue,
                isDefault: false
            ),
            PaymentMethod(
                cardBrand: .amex,
                last4Digits: "9012",
                expiryDate: "08/25",
                cardHolderName: "John Doe",
                colorTheme: .black,
                isDefault: false
            )
        ]
    }
}

// MARK: - Payment Method Persistence
extension PaymentMethod {
    private static let paymentMethodsKey = "prpay_payment_methods"

    // Save payment methods to UserDefaults
    static func saveAll(_ methods: [PaymentMethod]) {
        if let encoded = try? JSONEncoder().encode(methods) {
            UserDefaults.standard.set(encoded, forKey: paymentMethodsKey)
        }
    }

    // Load payment methods from UserDefaults
    static func loadAll() -> [PaymentMethod] {
        guard let data = UserDefaults.standard.data(forKey: paymentMethodsKey),
              let methods = try? JSONDecoder().decode([PaymentMethod].self, from: data) else {
            return mockPaymentMethods
        }
        return methods
    }

    // Clear saved payment methods
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: paymentMethodsKey)
    }
}
