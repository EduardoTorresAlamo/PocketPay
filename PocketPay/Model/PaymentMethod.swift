//
//  PaymentMethod.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import SwiftUI

// MARK: - Card Brand

/// The payment network of a stored card.
///
/// Used to select the appropriate SF Symbol icon and to label cards in the
/// wallet view. `CaseIterable` enables the brand picker in `AddCardView`.
enum CardBrand: String, Codable, CaseIterable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "American Express"
    case discover = "Discover"
    case other = "Other"

    /// SF Symbol name representing this card brand in the wallet UI.
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

/// Visual color theme for the card artwork displayed in `WalletView` and `AddCardView`.
///
/// Each theme provides a two-stop gradient used to render the card background.
/// `CaseIterable` enables the color swatch picker in `AddCardView`.
enum CardColorTheme: String, Codable, CaseIterable {
    case purple = "Purple"
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    case black = "Black"

    /// Two-color gradient used as the card background, from top-leading to bottom-trailing.
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

/// A credit or debit card saved in the user's digital wallet.
///
/// Full card numbers are never stored; only the last 4 digits are retained.
/// In a production integration the card token from Stripe would replace
/// the raw number entirely.
struct PaymentMethod: Identifiable, Codable {
    /// Unique identifier for list diffing and wallet management operations.
    let id: UUID
    /// The card network (Visa, Mastercard, etc.).
    var cardBrand: CardBrand
    /// The last four digits of the card number displayed on the card artwork.
    var last4Digits: String
    /// Expiry date in `"MM/YY"` format, e.g., `"12/26"`.
    var expiryDate: String // Format: "MM/YY"
    /// Name of the cardholder as printed on the physical card.
    var cardHolderName: String
    /// Visual color theme for the card rendering in `WalletView`.
    var colorTheme: CardColorTheme
    /// Whether this card is the default payment method used for new charges.
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

    /// Short label combining the brand name and masked digits, e.g., `"Visa •••• 1234"`.
    var displayName: String {
        return "\(cardBrand.rawValue) •••• \(last4Digits)"
    }

    /// Full masked card number for display on the card artwork: `"•••• •••• •••• 1234"`.
    var maskedNumber: String {
        return "•••• •••• •••• \(last4Digits)"
    }

    /// `true` when the card's expiry date is in the past.
    ///
    /// Parses the `"MM/YY"` expiry string and compares it against the current
    /// calendar month. Cards are considered valid until the end of their expiry month.
    var isExpired: Bool {
        guard let month = Int(expiryDate.prefix(2)),
              // Prepend "20" to convert two-digit year to four-digit year.
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

/// `UserDefaults`-backed persistence for the user's saved cards.
///
/// In a production app, card tokens would be stored in Stripe's Customer API
/// on the server and fetched on session start. `UserDefaults` is used here
/// for demo simplicity since only non-sensitive metadata (last 4 digits, expiry)
/// is persisted.
extension PaymentMethod {
    /// `UserDefaults` key for the encoded card list.
    private static let paymentMethodsKey = "prpay_payment_methods"

    /// Encodes and writes all payment methods to `UserDefaults`.
    ///
    /// - Parameter methods: The current list of cards to persist.
    static func saveAll(_ methods: [PaymentMethod]) {
        if let encoded = try? JSONEncoder().encode(methods) {
            UserDefaults.standard.set(encoded, forKey: paymentMethodsKey)
        }
    }

    /// Loads saved payment methods from `UserDefaults`, falling back to mock data if none exist.
    ///
    /// - Returns: The persisted card list, or `mockPaymentMethods` on first launch.
    static func loadAll() -> [PaymentMethod] {
        guard let data = UserDefaults.standard.data(forKey: paymentMethodsKey),
              let methods = try? JSONDecoder().decode([PaymentMethod].self, from: data) else {
            // Fall back to mock cards on first launch so the wallet is never empty in demo mode.
            return mockPaymentMethods
        }
        return methods
    }

    /// Removes all saved payment methods from `UserDefaults`.
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: paymentMethodsKey)
    }
}
