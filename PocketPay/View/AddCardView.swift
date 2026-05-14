//
//  AddCardView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct AddCardView: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var cardNumber = ""
    @State private var cardHolderName = ""
    @State private var expiryMonth = ""
    @State private var expiryYear = ""
    @State private var cvv = ""
    @State private var selectedBrand: CardBrand = .visa
    @State private var selectedColor: CardColorTheme = .purple
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

    private var last4Digits: String {
        let digits = cardNumber.replacingOccurrences(of: " ", with: "")
        if digits.count >= 4 {
            return String(digits.suffix(4))
        }
        return "****"
    }

    private var formattedExpiry: String {
        if !expiryMonth.isEmpty && !expiryYear.isEmpty {
            return "\(expiryMonth)/\(expiryYear)"
        }
        return "MM/YY"
    }

    private var isFormValid: Bool {
        let digits = cardNumber.replacingOccurrences(of: " ", with: "")
        return digits.count >= 15 &&
               !cardHolderName.isEmpty &&
               expiryMonth.count == 2 &&
               expiryYear.count == 2 &&
               cvv.count >= 3
    }

    private func formatCardNumber(_ input: String) -> String {
        let digits = input.replacingOccurrences(of: " ", with: "")
        let limited = String(digits.prefix(16))
        var formatted = ""

        for (index, char) in limited.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(char)
        }

        return formatted
    }

    private func formatMonth(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        let limited = String(digits.prefix(2))

        if let month = Int(limited), month > 12 {
            return "12"
        }

        return limited
    }

    private func formatYear(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        return String(digits.prefix(2))
    }

    private func formatCVV(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        return String(digits.prefix(4))
    }

    private func addCard() {
        let newCard = PaymentMethod(
            cardBrand: selectedBrand,
            last4Digits: last4Digits,
            expiryDate: formattedExpiry,
            cardHolderName: cardHolderName,
            colorTheme: selectedColor,
            isDefault: setAsDefault || viewModel.paymentMethods.isEmpty
        )

        viewModel.addPaymentMethod(newCard)
        dismiss()
    }
}

// MARK: - Card Preview

struct CardPreview: View {
    let brand: CardBrand
    let last4: String
    let expiry: String
    let holder: String
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
