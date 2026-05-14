//
//  ServicesView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct ServicesView: View {
    @StateObject private var viewModel = ServicesViewModel()
    @State private var showingAddPayment = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppConstants.Spacing.large) {
                    // Summary Card
                    SummaryCard(
                        totalRecurring: viewModel.totalMonthlyRecurring,
                        dueCount: viewModel.duePayments.count
                    )

                    // Due Soon Section
                    if !viewModel.duePayments.isEmpty {
                        DuePaymentsSection(
                            payments: viewModel.duePayments,
                            payAction: { payment in
                                Task {
                                    await viewModel.payBill(payment: payment)
                                }
                            }
                        )
                    }

                    // Active Subscriptions
                    ActiveSubscriptionsSection(
                        payments: viewModel.activePayments,
                        payAction: { payment in
                            Task {
                                await viewModel.payBill(payment: payment)
                            }
                        },
                        toggleAction: { payment in
                            viewModel.togglePaymentStatus(payment)
                        }
                    )

                    // Categories Section
                    CategoriesSection(
                        selectedAction: { category in
                            // Could navigate to filtered view
                        }
                    )
                }
                .padding(.horizontal, AppConstants.Spacing.medium)
                .padding(.vertical, AppConstants.Spacing.small)
            }
            .background(AppConstants.Colors.background.ignoresSafeArea())
            .navigationTitle("Services & Bills")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPayment = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppConstants.Colors.primaryPurple)
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddPayment) {
                AddPaymentView(viewModel: viewModel)
            }
            .alert("Payment Successful", isPresented: $viewModel.showingSuccess) {
                Button("OK") {
                    viewModel.showingSuccess = false
                }
            } message: {
                Text("Your payment has been processed successfully")
            }
            .alert("Payment Failed", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .overlay {
                if viewModel.isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppConstants.Colors.primaryPurple))
                }
            }
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let totalRecurring: Double
    let dueCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.Spacing.medium) {
            Text("Monthly Overview")
                .font(AppConstants.Typography.headline)
                .foregroundColor(AppConstants.Colors.label)

            HStack(spacing: AppConstants.Spacing.large) {
                VStack(alignment: .leading, spacing: AppConstants.Spacing.extraSmall) {
                    Text("Total Recurring")
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(AppConstants.Colors.secondaryLabel)

                    Text(String(format: "$%.2f", totalRecurring))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppConstants.Colors.primaryPurple)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: AppConstants.Spacing.extraSmall) {
                    Text("Due Soon")
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(AppConstants.Colors.secondaryLabel)

                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(AppConstants.Colors.warningOrange)
                        Text("\(dueCount)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppConstants.Colors.label)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppConstants.Spacing.large)
        .background(AppConstants.Colors.cardBackground)
        .cornerRadius(AppConstants.CornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Due Payments Section

struct DuePaymentsSection: View {
    let payments: [RecurringPayment]
    let payAction: (RecurringPayment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.Spacing.medium) {
            Text("Due Soon")
                .font(AppConstants.Typography.headline)
                .foregroundColor(AppConstants.Colors.label)
                .padding(.horizontal, AppConstants.Spacing.small)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppConstants.Spacing.medium) {
                    ForEach(payments) { payment in
                        DuePaymentCard(payment: payment, payAction: payAction)
                    }
                }
                .padding(.horizontal, AppConstants.Spacing.small)
            }
        }
    }
}

// MARK: - Due Payment Card

struct DuePaymentCard: View {
    let payment: RecurringPayment
    let payAction: (RecurringPayment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.Spacing.small) {
            HStack {
                Image(systemName: payment.category.icon)
                    .foregroundColor(payment.category.color)
                    .font(.title3)

                Spacer()

                Text(payment.statusText)
                    .font(AppConstants.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppConstants.Spacing.small)
                    .padding(.vertical, 2)
                    .background(payment.statusColor)
                    .cornerRadius(8)
            }

            Text(payment.billerName)
                .font(AppConstants.Typography.headline)
                .foregroundColor(AppConstants.Colors.label)
                .lineLimit(1)

            Text(payment.formattedAmount)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppConstants.Colors.primaryPurple)

            Text("Due \(payment.formattedNextPaymentDate)")
                .font(AppConstants.Typography.caption)
                .foregroundColor(AppConstants.Colors.secondaryLabel)

            Button(action: { payAction(payment) }) {
                Text("Pay Now")
                    .font(AppConstants.Typography.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppConstants.Spacing.small)
                    .background(AppConstants.Colors.primaryPurple)
                    .foregroundColor(.white)
                    .cornerRadius(AppConstants.CornerRadius.medium)
            }
            .padding(.top, AppConstants.Spacing.small)
        }
        .frame(width: 200)
        .padding(AppConstants.Spacing.medium)
        .background(AppConstants.Colors.cardBackground)
        .cornerRadius(AppConstants.CornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Active Subscriptions Section

struct ActiveSubscriptionsSection: View {
    let payments: [RecurringPayment]
    let payAction: (RecurringPayment) -> Void
    let toggleAction: (RecurringPayment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.Spacing.medium) {
            Text("All Services")
                .font(AppConstants.Typography.headline)
                .foregroundColor(AppConstants.Colors.label)
                .padding(.horizontal, AppConstants.Spacing.small)

            VStack(spacing: AppConstants.Spacing.small) {
                ForEach(payments) { payment in
                    RecurringPaymentRow(
                        payment: payment,
                        payAction: payAction,
                        toggleAction: toggleAction
                    )
                }
            }
        }
    }
}

// MARK: - Recurring Payment Row

struct RecurringPaymentRow: View {
    let payment: RecurringPayment
    let payAction: (RecurringPayment) -> Void
    let toggleAction: (RecurringPayment) -> Void

    var body: some View {
        HStack(spacing: AppConstants.Spacing.medium) {
            // Icon
            Circle()
                .fill(payment.category.color.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: payment.category.icon)
                        .foregroundColor(payment.category.color)
                        .font(.title3)
                )

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.billerName)
                    .font(AppConstants.Typography.body)
                    .foregroundColor(AppConstants.Colors.label)

                HStack(spacing: AppConstants.Spacing.small) {
                    Text(payment.frequency.displayName)
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(AppConstants.Colors.secondaryLabel)

                    if payment.autoPayEnabled {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                            Text("Auto")
                        }
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(AppConstants.Colors.successGreen)
                    }
                }

                Text("Next: \(payment.formattedNextPaymentDate)")
                    .font(AppConstants.Typography.caption)
                    .foregroundColor(AppConstants.Colors.tertiaryLabel)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(payment.formattedAmount)
                    .font(AppConstants.Typography.headline)
                    .foregroundColor(AppConstants.Colors.label)

                if payment.isDueSoon {
                    Button(action: { payAction(payment) }) {
                        Text("Pay")
                            .font(AppConstants.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppConstants.Spacing.small)
                            .padding(.vertical, 4)
                            .background(AppConstants.Colors.primaryPurple)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(AppConstants.Spacing.medium)
        .background(AppConstants.Colors.cardBackground)
        .cornerRadius(AppConstants.CornerRadius.medium)
    }
}

// MARK: - Categories Section

struct CategoriesSection: View {
    let selectedAction: (TransactionCategory) -> Void

    let categories: [TransactionCategory] = [.rent, .utilities, .subscription, .general]

    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.Spacing.medium) {
            Text("Pay by Category")
                .font(AppConstants.Typography.headline)
                .foregroundColor(AppConstants.Colors.label)
                .padding(.horizontal, AppConstants.Spacing.small)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppConstants.Spacing.medium) {
                ForEach(categories, id: \.self) { category in
                    CategoryCard(category: category, action: selectedAction)
                }
            }
        }
        .padding(.bottom, AppConstants.Spacing.large)
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: TransactionCategory
    let action: (TransactionCategory) -> Void

    var body: some View {
        Button(action: { action(category) }) {
            VStack(spacing: AppConstants.Spacing.small) {
                Image(systemName: category.icon)
                    .font(.title)
                    .foregroundColor(category.color)
                    .frame(width: 60, height: 60)
                    .background(category.color.opacity(0.1))
                    .cornerRadius(AppConstants.CornerRadius.medium)

                Text(category.displayName)
                    .font(AppConstants.Typography.subheadline)
                    .foregroundColor(AppConstants.Colors.label)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppConstants.Spacing.medium)
            .background(AppConstants.Colors.cardBackground)
            .cornerRadius(AppConstants.CornerRadius.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    ServicesView()
}
