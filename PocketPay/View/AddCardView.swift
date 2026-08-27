//
//  AddCardView.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

/// Sheet form for adding a new credit or debit card to the user's wallet.
///
/// As the user types, a `CardPreview` at the top of the scroll view updates in
/// real time to reflect the entered card number (last 4 digits), expiry, holder name,
/// brand icon, and selected color theme.
///
/// Full card numbers are never persisted; only the last 4 digits are stored in
/// the `PaymentMethod` model. In a production Stripe integration, the full number
/// would be tokenized client-side by the Stripe SDK before the token is sent to
/// the backend, and the raw PAN would never touch your servers.
///
/// Input formatters truncate values to their maximum lengths:
/// - Card number: 16 digits displayed as groups of 4 (`XXXX XXXX XXXX XXXX`)
/// - Expiry month: 2 digits, clamped to 12
/// - Expiry year: 2 digits
/// - CVV: 3-4 digits (4 for Amex)
struct AddCardView: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss

    /// Raw card number string managed by `formatCardNumber` as the user types.
    @State private var cardNumber = ""
    @State private var cardHolderName = ""
    /// Two-digit expiry month (`"01"` through `"12"`).
    @State private var expiryMonth = ""
    /// Two-digit expiry year (`"26"`, etc.).
    @State private var expiryYear = ""
    /// 3 or 4-digit card verification value (never persisted).
    @State private var cvv = ""
    @State private var selectedBrand: CardBrand = .visa
    @State private var selectedColor: CardColorTheme = .purple
    /// When `true`, this card becomes the wallet default on save.
    @State private var setAsDefault = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Card Preview
                    CardPreview(
                        brand: selectedBrand,
                        last4: last4Digits,
                        expiry: formattedExpiry,
                        holder: cardHolderName.isEmpty ? "CARDHOLDER NAME" : cardHolderName.uppercased(),
                        colorTheme: selectedColor
                    )
                    .padding(.top, 16)

                    // Form Fields
                    VStack(spacing: 16) {
                        // Card Number
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Card Number")
                                .font(AppConstants.Typography.caption)
                                .foregroundColor(AppConstants.Colors.secondaryLabel)
                                .textCase(.uppercase)

                            TextField("1234 5678 9012 3456", text: $cardNumber)
                                .keyboardType(.numberPad)
                                .font(AppConstants.Typography.body)
                                .padding()
                                .background(AppConstants.Colors.cardBackground)
                                .cornerRadius(AppConstants.CornerRadius.medium)
                                .onChange(of: cardNumber) { _, newValue in
                                    cardNumber = formatCardNumber(newValue)
                                }
                        }

                        // Cardholder Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cardholder Name")
                                .font(AppConstants.Typography.caption)
                                .foregroundColor(AppConstants.Colors.secondaryLabel)
                                .textCase(.uppercase)

                            TextField("John Doe", text: $cardHolderName)
                                .font(AppConstants.Typography.body)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(AppConstants.Colors.cardBackground)
                                .cornerRadius(AppConstants.CornerRadius.medium)
                        }

                        // Expiry & CVV
                        HStack(spacing: 16) {
                            // Expiry Date
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Expiry Date")
                                    .font(AppConstants.Typography.caption)
                                    .foregroundColor(AppConstants.Colors.secondaryLabel)
                                    .textCase(.uppercase)

                                HStack(spacing: 8) {
                                    TextField("MM", text: $expiryMonth)
                                        .keyboardType(.numberPad)
                                        .font(AppConstants.Typography.body)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                        .background(AppConstants.Colors.cardBackground)
                                        .cornerRadius(AppConstants.CornerRadius.medium)
                                        .onChange(of: expiryMonth) { _, newValue in
                                            expiryMonth = formatMonth(newValue)
                                        }

                                    Text("/")
                                        .foregroundColor(AppConstants.Colors.secondaryLabel)

                                    TextField("YY", text: $expiryYear)
                                        .keyboardType(.numberPad)
                                        .font(AppConstants.Typography.body)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                        .background(AppConstants.Colors.cardBackground)
                                        .cornerRadius(AppConstants.CornerRadius.medium)
                                        .onChange(of: expiryYear) { _, newValue in
                                            expiryYear = formatYear(newValue)
                                        }
                                }
                            }

                            // CVV
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CVV")
                                    .font(AppConstants.Typography.caption)
                                    .foregroundColor(AppConstants.Colors.secondaryLabel)
                                    .textCase(.uppercase)

                                TextField("123", text: $cvv)
                                    .keyboardType(.numberPad)
                                    .font(AppConstants.Typography.body)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(AppConstants.Colors.cardBackground)
                                    .cornerRadius(AppConstants.CornerRadius.medium)
                                    .onChange(of: cvv) { _, newValue in
                                        cvv = formatCVV(newValue)
                                    }
                            }
                        }

                        // Card Brand
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Card Brand")
                                .font(AppConstants.Typography.caption)
                                .foregroundColor(AppConstants.Colors.secondaryLabel)
                                .textCase(.uppercase)

                            Picker("Card Brand", selection: $selectedBrand) {
                                ForEach(CardBrand.allCases, id: \.self) { brand in
                                    Text(brand.rawValue).tag(brand)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Card Color
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Card Color")
                                .font(AppConstants.Typography.caption)
                                .foregroundColor(AppConstants.Colors.secondaryLabel)
                                .textCase(.uppercase)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(CardColorTheme.allCases, id: \.self) { theme in
                                        Button(action: { selectedColor = theme }) {
                                            LinearGradient(
                                                gradient: Gradient(colors: theme.gradient),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            .frame(width: 60, height: 40)
                                            .cornerRadius(AppConstants.CornerRadius.small)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppConstants.CornerRadius.small)
                                                    .stroke(selectedColor == theme ? AppConstants.Colors.primaryPurple : Color.clear, lineWidth: 3)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Set as Default
                        Toggle("Set as default payment method", isOn: $setAsDefault)
                            .tint(AppConstants.Colors.primaryPurple)
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 24)

                    // Add Card Button
                    Button(action: addCard) {
                        Text("Add Card")
                            .font(AppConstants.Typography.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? AppConstants.Colors.primaryPurple : AppConstants.Colors.secondaryLabel.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(AppConstants.CornerRadius.medium)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }
            .background(AppConstants.Colors.background.ignoresSafeArea())
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    /// The last 4 digits of `cardNumber`, used for `CardPreview` and `PaymentMethod` storage.
    ///
    /// Falls back to `"****"` while fewer than 4 digits have been entered.
    private var last4Digits: String {
        let digits = cardNumber.replacingOccurrences(of: " ", with: "")
        if digits.count >= 4 {
            return String(digits.suffix(4))
        }
        return "****"
    }

    /// The expiry string in `"MM/YY"` format shown on the card preview.
    ///
    /// Returns the placeholder `"MM/YY"` until both month and year fields are filled.
    private var formattedExpiry: String {
        if !expiryMonth.isEmpty && !expiryYear.isEmpty {
            return "\(expiryMonth)/\(expiryYear)"
        }
        return "MM/YY"
    }

    /// `true` when all required fields contain valid values and the form can be submitted.
    ///
    /// Requires at least 15 digits (Amex uses 15-digit PANs), a non-empty holder name,
    /// two-digit month and year, and at least 3 CVV digits.
    private var isFormValid: Bool {
        let digits = cardNumber.replacingOccurrences(of: " ", with: "")
        return digits.count >= 15 &&
               !cardHolderName.isEmpty &&
               expiryMonth.count == 2 &&
               expiryYear.count == 2 &&
               cvv.count >= 3
    }

    /// Strips non-digit characters and inserts a space every 4 digits.
    ///
    /// Caps input at 16 digits to fit standard card PANs.
    ///
    /// - Parameter input: Raw string from the card number text field.
    /// - Returns: Formatted string such as `"4111 1111 1111 1111"`.
    private func formatCardNumber(_ input: String) -> String {
        let digits = input.replacingOccurrences(of: " ", with: "")
        let limited = String(digits.prefix(16))
        var formatted = ""

        for (index, char) in limited.enumerated() {
            // Insert a space before every 4th digit group to match physical card formatting.
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(char)
        }

        return formatted
    }

    /// Strips non-digit characters from the month field and clamps the value to `"12"`.
    ///
    /// - Parameter input: Raw string from the month text field.
    /// - Returns: Up to 2 digit characters, never exceeding `"12"`.
    private func formatMonth(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        let limited = String(digits.prefix(2))

        // Prevent the user from entering an invalid month like "13" or "99".
        if let month = Int(limited), month > 12 {
            return "12"
        }

        return limited
    }

    /// Strips non-digit characters and caps input at 2 characters for the year field.
    ///
    /// - Parameter input: Raw string from the year text field.
    /// - Returns: Up to 2 digit characters (e.g., `"26"`).
    private func formatYear(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        return String(digits.prefix(2))
    }

    /// Strips non-digit characters and caps the CVV at 4 digits.
    ///
    /// Most cards use 3-digit CVVs; American Express uses 4 digits.
    ///
    /// - Parameter input: Raw string from the CVV text field.
    /// - Returns: Up to 4 digit characters.
    private func formatCVV(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        return String(digits.prefix(4))
    }

    /// Builds a `PaymentMethod` from the current form state and adds it to the wallet.
    ///
    /// The new card is automatically made the default if the wallet is empty or if
    /// `setAsDefault` is toggled on. `WalletViewModel.addPaymentMethod` enforces
    /// the single-default invariant for the remaining cards.
    private func addCard() {
        let newCard = PaymentMethod(
            cardBrand: selectedBrand,
            last4Digits: last4Digits,
            expiryDate: formattedExpiry,
            cardHolderName: cardHolderName,
            colorTheme: selectedColor,
            // Auto-set as default if it is the very first card or explicitly requested.
            isDefault: setAsDefault || viewModel.paymentMethods.isEmpty
        )

        viewModel.addPaymentMethod(newCard)
        dismiss()
    }
}

// MARK: - Card Preview

/// A live card artwork preview shown at the top of `AddCardView`.
///
/// Mirrors the layout of `CreditCardView` from `WalletView`, but is driven by
/// individual field properties rather than a `PaymentMethod` model so it can
/// update incrementally as each form field is filled.
struct CardPreview: View {
    /// The selected card network, used to pick the brand SF Symbol.
    let brand: CardBrand
    /// Last 4 digits of the entered card number, or `"****"` while incomplete.
    let last4: String
    /// Expiry string in `"MM/YY"` format, or `"MM/YY"` placeholder.
    let expiry: String
    /// Uppercased cardholder name, or `"CARDHOLDER NAME"` placeholder.
    let holder: String
    /// Visual gradient theme applied to the card background.
    let colorTheme: CardColorTheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                gradient: Gradient(colors: colorTheme.gradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(20)
            .shadow(color: colorTheme.gradient[0].opacity(0.4), radius: 10, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: brand.icon)
                    .font(.title2)
                    .foregroundColor(.white)

                Spacer()

                Text("•••• •••• •••• \(last4)")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CARDHOLDER")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text(holder)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("EXPIRES")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text(expiry)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(24)
        }
        .frame(height: 220)
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview {
    AddCardView(viewModel: WalletViewModel.shared)
}
