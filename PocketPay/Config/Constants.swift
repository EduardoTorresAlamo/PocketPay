//
//  Constants.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct AppConstants {
    // MARK: - Colors (Dynamic - supports Light & Dark Mode)
    struct Colors {
        // Primary Brand Colors
        static let primaryPurple = Color(hex: "#8A2BE2") // BlueViolet
        static let secondaryPurple = Color(hex: "#9370DB") // MediumPurple
        static let accentLavender = Color(hex: "#E6E6FA") // Lavender

        // Semantic Colors (Adaptive)
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)

        // Text Colors (Adaptive)
        static let label = Color(.label)
        static let secondaryLabel = Color(.secondaryLabel)
        static let tertiaryLabel = Color(.tertiaryLabel)

        // UI Element Colors (Adaptive)
        static let cardBackground = Color(.systemGray6)
        static let inputBackground = Color(.systemGray6)
        static let separator = Color(.separator)

        // Status Colors
        static let successGreen = Color.green
        static let errorRed = Color.red
        static let warningOrange = Color.orange
        static let infoBluePurple = Color(hex: "#9370DB")

        // Category Colors
        static let rentColor = Color.blue
        static let utilitiesColor = Color.orange
        static let subscriptionColor = Color.purple
        static let p2pColor = Color.green
        static let generalColor = Color.gray
    }

    // MARK: - Typography
    struct Typography {
        static let largeTitle: Font = .system(size: 34, weight: .bold)
        static let title: Font = .system(size: 28, weight: .bold)
        static let title2: Font = .system(size: 22, weight: .bold)
        static let headline: Font = .system(size: 17, weight: .semibold)
        static let body: Font = .system(size: 17, weight: .regular)
        static let callout: Font = .system(size: 16, weight: .regular)
        static let subheadline: Font = .system(size: 15, weight: .regular)
        static let footnote: Font = .system(size: 13, weight: .regular)
        static let caption: Font = .system(size: 12, weight: .regular)
    }

    // MARK: - Spacing
    struct Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    // MARK: - Corner Radius (Updated for friendlier look)
    struct CornerRadius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 28
    }

    // MARK: - App Info
    struct AppInfo {
        static let name = "PRPay"
        static let version = "1.0.0"
        static let defaultCurrency = "USD"
        static let currencySymbol = "$"
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
