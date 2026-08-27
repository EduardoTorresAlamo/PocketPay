//
//  ServicesView.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

/// The Services tab that shows recurring bills, a monthly cost summary, and a "Due Soon" section.
///
/// Uses `ServicesViewModel` for all data and payment actions. The toolbar "+" button
/// presents `AddPaymentView` as a sheet to add a new one-time or recurring payment.
/// A full-screen loading overlay is shown while `viewModel.isProcessing` is `true`.
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
            .navigationDestination(for: RecurringPayment.self) { payment in
                RecurringPaymentDetailView(payment: payment, viewModel: viewModel)
            }
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

// MARK: - Recurring Payment Detail

/// Destination shown when a `RecurringPayment` value is pushed onto the
/// Services `NavigationStack`.
struct RecurringPaymentDetailView: View {
    let payment: RecurringPayment
    @ObservedObject var viewModel: ServicesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppConstants.Spacing.large) {
                DetailRow(label: "Biller", value: payment.billerName)
                DetailRow(label: "Amount", value: payment.amount.formatted(.currency(code: "USD")))
                DetailRow(label: "Frequency", value: payment.frequency.rawValue)
                DetailRow(label: "Category", value: payment.category.rawValue)
                DetailRow(label: "Next Payment", value: payment.nextPaymentDate.formatted(date: .abbreviated, time: .omitted))
                DetailRow(label: "Status", value: payment.isActive ? "Active" : "Paused")

                if let notes = payment.notes, !notes.isEmpty {
                    DetailRow(label: "Notes", value: notes)
                }

                Button("Pay Now") {
                    Task {
                        await viewModel.payBill(payment: payment)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppConstants.Colors.primaryPurple)
                .disabled(viewModel.isProcessing)
            }
            .padding(AppConstants.Spacing.medium)
        }
        .background(AppConstants.Colors.background.ignoresSafeArea())
        .navigationTitle(payment.billerName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Summary Card

/// A card at the top of the Services tab showing total monthly recurring cost
/// and the number of payments due within the next 7 days.
struct SummaryCard: View {
    /// Total estimated monthly cost across all active recurring payments,
    /// normalized to a monthly equivalent (see `ServicesViewModel.totalMonthlyRecurring`).
    let totalRecurring: Double
    /// Number of active payments due within 7 days, shown with a warning icon.
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

                    Text(CurrencyFormatter.format(totalRecurring))
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

/// A horizontally scrolling section that surfaces payments due within 7 days.
///
/// Each payment is rendered as a `DuePaymentCard`. This section is only shown
/// when `ServicesViewModel.duePayments` is non-empty.
struct DuePaymentsSection: View {
    /// Payments that are active and due within the next 7 days.
    let payments: [RecurringPayment]
    /// Closure called with the selected payment when the user taps "Pay Now".
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

/// A fixed-width card in the horizontal "Due Soon" scroll view.
///
/// Shows the payment's category icon, status badge, biller name, amount,
/// due date, and a "Pay Now" button that triggers immediate processing.
struct DuePaymentCard: View {
    /// The recurring payment displayed by this card.
    let payment: RecurringPayment
    /// Closure invoked with `payment` when the user taps "Pay Now".
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

/// The "All Services" section that lists every active recurring payment as a
/// `RecurringPaymentRow`. Despite the name it is not limited to subscriptions;
/// it shows all active categories (rent, utilities, subscriptions, general).
struct ActiveSubscriptionsSection: View {
    /// All currently active recurring payments.
    let payments: [RecurringPayment]
    /// Closure invoked when the user taps the inline "Pay" button on a due-soon row.
    let payAction: (RecurringPayment) -> Void
    /// Closure invoked when the user long-presses to toggle a payment's active state.
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

/// A list row for a single recurring payment inside `ActiveSubscriptionsSection`.
///
/// Shows the biller icon, name, frequency, auto-pay badge, next due date,
/// and amount. When `payment.isDueSoon`, an inline "Pay" button is shown
/// so the user can act without navigating away.
struct RecurringPaymentRow: View {
    /// The recurring payment displayed in this row.
    let payment: RecurringPayment
    /// Called when the user taps the inline "Pay" button.
    let payAction: (RecurringPayment) -> Void
    /// Called when the user toggles the active state; currently wired to a context menu.
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

/// A 2-column grid of category shortcut cards at the bottom of the Services tab.
///
/// Tapping a card calls `selectedAction` with the corresponding category,
/// which can be used to navigate to a pre-filtered payment or history view.
/// Only the four main bill categories are shown (rent, utilities, subscription, general).
struct CategoriesSection: View {
    /// Closure called with the tapped category so the parent can act (e.g., navigate).
    let selectedAction: (TransactionCategory) -> Void

    // Only bill-relevant categories are included; p2p is handled in TransferView.
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

/// A tappable card in `CategoriesSection` representing a single payment category.
///
/// Renders the category's SF Symbol icon in a colored rounded square above
/// the category display name. Tapping forwards the category to `action`.
struct CategoryCard: View {
    /// The transaction category this card represents.
    let category: TransactionCategory
    /// Called with `category` when the user taps the card.
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
