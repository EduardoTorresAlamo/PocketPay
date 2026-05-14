//
//  HomeView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var authManager = AuthManager.shared
    @State private var showingTransferView = false
    @State private var showingPayBillView = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.getGreeting())
                            .font(AppConstants.Typography.subheadline)
                            .foregroundColor(AppConstants.Colors.secondaryLabel)

                        Text(viewModel.currentUser?.fullName ?? "User")
                            .font(AppConstants.Typography.title2)
                            .foregroundColor(AppConstants.Colors.label)
                            .bold()
                    }

                    Spacer()

                    // Profile Avatar
                    Circle()
                        .fill(AppConstants.Colors.primaryPurple.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(viewModel.currentUser?.fullName.prefix(1) ?? "U"))
                                .font(AppConstants.Typography.title2)
                                .foregroundColor(AppConstants.Colors.primaryPurple)
                                .bold()
                        )
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Balance Card
                BalanceCard(
                    balance: viewModel.getFormattedBalance(),
                    isHidden: viewModel.isBalanceHidden,
                    toggleAction: viewModel.toggleBalanceVisibility
                )
                .padding(.horizontal, 24)

                // Primary Actions - Two Large Buttons
                VStack(spacing: 16) {
                    // Send Money Button
                    LargeActionButton(
                        title: "Send Money",
                        subtitle: "Transfer to friends & family",
                        icon: "arrow.up.circle.fill",
                        color: AppConstants.Colors.primaryPurple,
                        action: { showingTransferView = true }
                    )

                    // Pay Bill Button
                    LargeActionButton(
                        title: "Pay Bill",
                        subtitle: "Utilities, rent & subscriptions",
                        icon: "doc.text.fill",
                        color: AppConstants.Colors.secondaryPurple,
                        action: { showingPayBillView = true }
                    )
                }
                .padding(.horizontal, 24)

                // Recent Transactions Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Recent Transactions")
                            .font(AppConstants.Typography.headline)
                            .foregroundColor(AppConstants.Colors.label)

                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    if viewModel.recentTransactions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(AppConstants.Colors.secondaryLabel)

                            Text("No transactions yet")
                                .font(AppConstants.Typography.subheadline)
                                .foregroundColor(AppConstants.Colors.secondaryLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.recentTransactions.prefix(8)) { transaction in
                                SimpleTransactionRow(transaction: transaction)

                                if transaction.id != viewModel.recentTransactions.prefix(8).last?.id {
                                    Divider()
                                        .padding(.leading, 70)
                                }
                            }
                        }
                        .background(AppConstants.Colors.cardBackground)
                        .cornerRadius(AppConstants.CornerRadius.large)
                        .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(AppConstants.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $showingTransferView) {
            TransferView()
        }
        .sheet(isPresented: $showingPayBillView) {
            AddPaymentView(viewModel: ServicesViewModel())
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}

// MARK: - Balance Card (Updated, cleaner version)

struct BalanceCard: View {
    let balance: String
    let isHidden: Bool
    let toggleAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Balance")
                    .font(AppConstants.Typography.subheadline)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Button(action: toggleAction) {
                    Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.white.opacity(0.9))
                        .font(.title3)
                }
            }

            Text(isHidden ? "••••••" : balance)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    AppConstants.Colors.primaryPurple,
                    AppConstants.Colors.secondaryPurple
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppConstants.CornerRadius.large)
        .shadow(color: AppConstants.Colors.primaryPurple.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Large Action Button

struct LargeActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(color)
                    .cornerRadius(AppConstants.CornerRadius.medium)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppConstants.Typography.headline)
                        .foregroundColor(AppConstants.Colors.label)

                    Text(subtitle)
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(AppConstants.Colors.secondaryLabel)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppConstants.Colors.tertiaryLabel)
                    .font(.body)
            }
            .padding(20)
            .background(AppConstants.Colors.cardBackground)
            .cornerRadius(AppConstants.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Simple Transaction Row

struct SimpleTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 16) {
            // Avatar/Icon
            Circle()
                .fill(transaction.category.color.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: transaction.isIncoming ? "arrow.down.left" : transaction.category.icon)
                        .foregroundColor(transaction.isIncoming ? AppConstants.Colors.successGreen : transaction.category.color)
                        .font(.title3)
                )

            // Name and Date
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.recipientName)
                    .font(AppConstants.Typography.body)
                    .foregroundColor(AppConstants.Colors.label)
                    .lineLimit(1)

                Text(transaction.formattedDate)
                    .font(AppConstants.Typography.caption)
                    .foregroundColor(AppConstants.Colors.secondaryLabel)
            }

            Spacer()

            // Amount
            Text(transaction.formattedAmount)
                .font(AppConstants.Typography.headline)
                .foregroundColor(transaction.isIncoming ? AppConstants.Colors.successGreen : AppConstants.Colors.label)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppConstants.Colors.cardBackground)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
