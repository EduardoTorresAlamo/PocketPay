//
//  WalletView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

/// Displays the user's saved payment methods in a swipeable card carousel.
///
/// The top section shows a paginated `TabView` of `CreditCardView` items.
/// Below the carousel, contextual action buttons (Set as Default, Remove) appear
/// for the currently visible card. A list below mirrors all cards and allows
/// direct selection by tapping a row. The "Add New Card" button presents `AddCardView`.
struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel.shared
    /// Tracks which card is currently centered in the carousel, synchronized with
    /// the list row selection highlight below.
    @State private var selectedCardIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Card Carousel
                    if viewModel.paymentMethods.isEmpty {
                        EmptyWalletView()
                    } else {
                        TabView(selection: $selectedCardIndex) {
                            ForEach(Array(viewModel.paymentMethods.enumerated()), id: \.element.id) { index, card in
                                CreditCardView(paymentMethod: card)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .frame(height: 240)
                        .padding(.top, 16)

                        // Card Actions — only rendered while the index still points at a card,
                        // since removals can leave `selectedCardIndex` past the end of the array.
                        if selectedCardIndex >= 0, selectedCardIndex < viewModel.paymentMethods.count {
                            CardActionsView(
                                card: viewModel.paymentMethods[selectedCardIndex],
                                setAsDefaultAction: {
                                    guard selectedCardIndex < viewModel.paymentMethods.count else { return }
                                    viewModel.setDefaultPaymentMethod(viewModel.paymentMethods[selectedCardIndex])
                                },
                                removeAction: {
                                    guard selectedCardIndex < viewModel.paymentMethods.count else { return }
                                    viewModel.removePaymentMethod(viewModel.paymentMethods[selectedCardIndex])
                                    if selectedCardIndex > 0 {
                                        selectedCardIndex -= 1
                                    }
                                }
                            )
                            .padding(.horizontal, 24)
                        }
                    }

                    // Add New Card Button
                    Button(action: { viewModel.showingAddCard = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Add New Card")
                                .font(AppConstants.Typography.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppConstants.Colors.primaryPurple)
                        .foregroundColor(.white)
                        .cornerRadius(AppConstants.CornerRadius.medium)
                    }
                    .padding(.horizontal, 24)

                    // Payment Methods List
                    if !viewModel.paymentMethods.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("All Payment Methods")
                                .font(AppConstants.Typography.headline)
                                .foregroundColor(AppConstants.Colors.label)
                                .padding(.horizontal, 24)

                            VStack(spacing: 8) {
                                ForEach(viewModel.paymentMethods) { card in
                                    PaymentMethodListRow(
                                        paymentMethod: card,
                                        isSelected: selectedCardIndex == viewModel.paymentMethods.firstIndex(where: { $0.id == card.id }),
                                        selectAction: {
                                            if let index = viewModel.paymentMethods.firstIndex(where: { $0.id == card.id }) {
                                                selectedCardIndex = index
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(AppConstants.Colors.background.ignoresSafeArea())
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showingAddCard) {
                AddCardView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Credit Card View

/// Renders a physical-card-style view for a saved `PaymentMethod`.
///
/// Shows the card brand icon, a "DEFAULT" badge if applicable, the masked card
/// number, cardholder name, and expiry date on a color-themed gradient background.
struct CreditCardView: View {
    let paymentMethod: PaymentMethod

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card Background
            LinearGradient(
                gradient: Gradient(colors: paymentMethod.colorTheme.gradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(20)
            .shadow(color: paymentMethod.colorTheme.gradient[0].opacity(0.4), radius: 10, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 20) {
                // Card Brand & Default Badge
                HStack {
                    Image(systemName: paymentMethod.cardBrand.icon)
                        .font(.title2)
                        .foregroundColor(.white)

                    Spacer()

                    if paymentMethod.isDefault {
                        Text("DEFAULT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(6)
                    }
                }

                Spacer()

                // Card Number
                Text(paymentMethod.maskedNumber)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                // Cardholder Info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CARDHOLDER")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text(paymentMethod.cardHolderName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("EXPIRES")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text(paymentMethod.expiryDate)
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

// MARK: - Empty Wallet View

/// Placeholder shown when the user has no saved payment methods.
struct EmptyWalletView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "creditcard")
                .font(.system(size: 60))
                .foregroundColor(AppConstants.Colors.secondaryLabel)

            Text("No Cards Added")
                .font(AppConstants.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(AppConstants.Colors.label)

            Text("Add a payment method to start using PRPay")
                .font(AppConstants.Typography.body)
                .foregroundColor(AppConstants.Colors.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }
}

// MARK: - Card Actions View

/// Action buttons displayed below the card carousel for the currently selected card.
///
/// Shows "Set as Default" only when the card is not already the default.
/// The "Remove" button triggers a confirmation alert before deleting.
struct CardActionsView: View {
    let card: PaymentMethod
    let setAsDefaultAction: () -> Void
    let removeAction: () -> Void
    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: 12) {
            if !card.isDefault {
                Button(action: setAsDefaultAction) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Set as Default")
                    }
                    .font(AppConstants.Typography.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppConstants.Colors.cardBackground)
                    .foregroundColor(AppConstants.Colors.primaryPurple)
                    .cornerRadius(AppConstants.CornerRadius.medium)
                }
            }

            Button(action: { showingDeleteAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Remove")
                }
                .font(AppConstants.Typography.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppConstants.Colors.errorRed.opacity(0.1))
                .foregroundColor(AppConstants.Colors.errorRed)
                .cornerRadius(AppConstants.CornerRadius.medium)
            }
            .alert("Remove Card", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive, action: removeAction)
            } message: {
                Text("Are you sure you want to remove this payment method?")
            }
        }
    }
}

// MARK: - Payment Method List Row

/// A compact list row for a saved card, shown below the carousel in `WalletView`.
///
/// A purple border and checkmark indicate the currently selected card. Tapping
/// the row syncs the carousel's `selectedCardIndex` to this card.
struct PaymentMethodListRow: View {
    let paymentMethod: PaymentMethod
    /// `true` when this row corresponds to the card currently shown in the carousel.
    let isSelected: Bool
    let selectAction: () -> Void

    var body: some View {
        Button(action: selectAction) {
            HStack(spacing: 16) {
                // Card Icon
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: paymentMethod.colorTheme.gradient),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 50, height: 50)
                    .cornerRadius(AppConstants.CornerRadius.small)

                    Image(systemName: paymentMethod.cardBrand.icon)
                        .foregroundColor(.white)
                }

                // Card Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(paymentMethod.displayName)
                            .font(AppConstants.Typography.body)
                            .foregroundColor(AppConstants.Colors.label)

                        if paymentMethod.isDefault {
                            Text("DEFAULT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppConstants.Colors.primaryPurple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppConstants.Colors.primaryPurple.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    Text("Expires \(paymentMethod.expiryDate)")
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(AppConstants.Colors.secondaryLabel)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppConstants.Colors.primaryPurple)
                        .font(.title3)
                }
            }
            .padding()
            .background(AppConstants.Colors.cardBackground)
            .cornerRadius(AppConstants.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium)
                    .stroke(isSelected ? AppConstants.Colors.primaryPurple : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    WalletView()
}
