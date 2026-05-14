//
//  HistoryView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var paymentManager = PaymentManager.shared
    @StateObject private var servicesViewModel = ServicesViewModel()
    @State private var selectedCategoryFilter: TransactionCategory? = nil
    @State private var selectedTransaction: Transaction? = nil
    @State private var showingTransactionDetail = false

    var filteredTransactions: [Transaction] {
        if let filter = selectedCategoryFilter {
            return paymentManager.transactions.filter { $0.category == filter }
        }
        return paymentManager.transactions
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppConstants.Spacing.small) {
                        CategoryFilterChip(
                            title: "All",
                            icon: "list.bullet",
                            isSelected: selectedCategoryFilter == nil,
                            color: AppConstants.Colors.primaryPurple,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategoryFilter = nil
                                }
                            }
                        )

                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                            CategoryFilterChip(
                                title: category.displayName,
                                icon: category.icon,
                                isSelected: selectedCategoryFilter == category,
                                color: category.color,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedCategoryFilter = category
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, AppConstants.Spacing.small)
                }
                .background(AppConstants.Colors.background)

                Divider()

                // Transactions List
                if filteredTransactions.isEmpty {
                    VStack(spacing: AppConstants.Spacing.medium) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(AppConstants.Colors.secondaryLabel)

                        Text("No transactions found")
                            .font(AppConstants.Typography.headline)
                            .foregroundColor(AppConstants.Colors.label)

                        Text("Your transaction history will appear here")
                            .font(AppConstants.Typography.subheadline)
                            .foregroundColor(AppConstants.Colors.secondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                                Section {
                                    ForEach(groupedTransactions[date] ?? []) { transaction in
                                        HistoryTransactionRow(transaction: transaction) {
                                            selectedTransaction = transaction
                                            showingTransactionDetail = true
                                        }

                                        if transaction.id != groupedTransactions[date]?.last?.id {
                                            Divider()
                                                .padding(.leading, 70)
                                        }
                                    }
                                } header: {
                                    Text(formatSectionDate(date))
                                        .font(AppConstants.Typography.subheadline)
                                        .foregroundColor(AppConstants.Colors.secondaryLabel)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                        .padding(.vertical, AppConstants.Spacing.small)
                                        .background(AppConstants.Colors.secondaryBackground)
                                }
                            }
                        }
                    }
                    .background(AppConstants.Colors.background)
                }
            }
            .background(AppConstants.Colors.background.ignoresSafeArea())
            .navigationTitle("Transaction History")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingTransactionDetail) {
                if let transaction = selectedTransaction {
                    TransactionDetailView(
                        transaction: transaction,
                        servicesViewModel: servicesViewModel
                    )
                }
            }
        }
    }

    // Group transactions by date
    private var groupedTransactions: [Date: [Transaction]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(AppConstants.Typography.subheadline)
            }
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : AppConstants.Colors.label)
            .padding(.horizontal, AppConstants.Spacing.medium)
            .padding(.vertical, AppConstants.Spacing.small)
            .background(isSelected ? color : AppConstants.Colors.cardBackground)
            .cornerRadius(AppConstants.CornerRadius.large)
            .shadow(color: isSelected ? color.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - History Transaction Row

struct HistoryTransactionRow: View {
    let transaction: Transaction
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppConstants.Spacing.medium) {
                // Icon
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: iconName)
                            .foregroundColor(iconColor)
                            .font(.title3)
                    )

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: AppConstants.Spacing.extraSmall) {
                        Text(transaction.recipientName)
                            .font(AppConstants.Typography.body)
                            .foregroundColor(AppConstants.Colors.label)

                        if transaction.isRecurring {
                            Image(systemName: "repeat.circle.fill")
                                .foregroundColor(AppConstants.Colors.subscriptionColor)
                                .font(.caption)
                        }
                    }

                    HStack(spacing: AppConstants.Spacing.small) {
                        // Category Badge
                        HStack(spacing: 4) {
                            Image(systemName: transaction.category.icon)
                                .font(.caption2)
                            Text(transaction.category.displayName)
                                .font(AppConstants.Typography.caption)
                        }
                        .foregroundColor(transaction.category.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(transaction.category.color.opacity(0.1))
                        .cornerRadius(6)

                        Circle()
                            .fill(AppConstants.Colors.separator)
                            .frame(width: 3, height: 3)

                        Text(transaction.formattedDate)
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(AppConstants.Colors.secondaryLabel)
                    }

                    if let notes = transaction.notes {
                        Text(notes)
                            .font(AppConstants.Typography.caption)
                            .foregroundColor(AppConstants.Colors.tertiaryLabel)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Amount and Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.formattedAmount)
                        .font(AppConstants.Typography.headline)
                        .foregroundColor(transaction.isIncoming ? AppConstants.Colors.successGreen : AppConstants.Colors.label)

                    HistoryStatusBadge(status: transaction.status)
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppConstants.Colors.tertiaryLabel)
            }
            .padding()
            .background(AppConstants.Colors.background)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var iconName: String {
        switch transaction.category {
        case .utilities:
            return "bolt.fill"
        case .rent:
            return "house.fill"
        case .subscription:
            return "repeat.circle.fill"
        case .p2p:
            return transaction.isIncoming ? "arrow.down.left" : "arrow.up.right"
        case .general:
            return "creditcard.fill"
        }
    }

    private var iconColor: Color {
        if transaction.isIncoming && transaction.category == .p2p {
            return AppConstants.Colors.successGreen
        }
        return transaction.category.color
    }

    private var iconBackgroundColor: Color {
        iconColor.opacity(0.15)
    }
}

// MARK: - History Status Badge

struct HistoryStatusBadge: View {
    let status: TransactionStatus

    var body: some View {
        Text(status.rawValue)
            .font(AppConstants.Typography.caption)
            .fontWeight(.semibold)
            .foregroundColor(statusColor)
            .padding(.horizontal, AppConstants.Spacing.small)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.1))
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch status {
        case .completed:
            return AppConstants.Colors.successGreen
        case .pending:
            return AppConstants.Colors.warningOrange
        case .failed:
            return AppConstants.Colors.errorRed
        }
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
}
