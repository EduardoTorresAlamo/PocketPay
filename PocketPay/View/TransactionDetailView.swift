//
//  TransactionDetailView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct TransactionDetailView: View {
    let transaction: Transaction
    @ObservedObject var servicesViewModel: ServicesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingStopRecurring = false

    var recurringPayment: RecurringPayment? {
        guard let recurringId = transaction.recurringPaymentId else { return nil }
        return servicesViewModel.recurringPayments.first { $0.id == recurringId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppConstants.Spacing.large) {
                    // Amount Display
                    VStack(spacing: AppConstants.Spacing.small) {
                        Image(systemName: transaction.isIncoming ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(transaction.isIncoming ? AppConstants.Colors.successGreen : AppConstants.Colors.primaryPurple)

                        Text(transaction.formattedAmount)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(AppConstants.Colors.label)

                        Text(transaction.status.rawValue)
                            .font(AppConstants.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppConstants.Spacing.medium)
                            .padding(.vertical, AppConstants.Spacing.extraSmall)
                            .background(statusColor)
                            .cornerRadius(AppConstants.CornerRadius.medium)
                    }
                    .padding(.vertical, AppConstants.Spacing.large)

                    // Transaction Details
                    VStack(spacing: AppConstants.Spacing.small) {
                        DetailRow(label: "Recipient", value: transaction.recipientName)

                        if let phone = transaction.recipientPhone {
                            DetailRow(label: "Phone", value: phone)
                        }

                        DetailRow(label: "Category", value: transaction.category.displayName, icon: transaction.category.icon, iconColor: transaction.category.color)

                        DetailRow(label: "Type", value: transaction.type.rawValue)

                        DetailRow(label: "Date", value: transaction.formattedDate)

                        DetailRow(label: "Time", value: transaction.formattedTime)

                        if let notes = transaction.notes {
                            DetailRow(label: "Notes", value: notes)
                        }

                        if transaction.isRecurring {
                            DetailRow(
                                label: "Recurring",
                                value: "Yes",
                                icon: "repeat.circle.fill",
                                iconColor: AppConstants.Colors.subscriptionColor
                            )

                            if let recurring = recurringPayment {
                                DetailRow(
                                    label: "Frequency",
                                    value: recurring.frequency.displayName
                                )

                                DetailRow(
                                    label: "Next Payment",
                                    value: recurring.formattedNextPaymentDate
                                )
                            }
                        }

                        DetailRow(label: "Transaction ID", value: transaction.id.uuidString.prefix(8).uppercased())
                    }

                    // Stop Recurring Button
                    if transaction.isRecurring, let recurring = recurringPayment, recurring.isActive {
                        Button(action: { showingStopRecurring = true }) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("Stop Recurring Payment")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppConstants.Colors.errorRed)
                            .foregroundColor(.white)
                            .cornerRadius(AppConstants.CornerRadius.large)
                        }
                        .padding(.top, AppConstants.Spacing.medium)
                    }
                }
                .padding()
            }
            .background(AppConstants.Colors.background.ignoresSafeArea())
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppConstants.Colors.primaryPurple)
                }
            }
            .alert("Stop Recurring Payment", isPresented: $showingStopRecurring) {
                Button("Cancel", role: .cancel) {}
                Button("Stop Payment", role: .destructive) {
                    if let recurring = recurringPayment {
                        servicesViewModel.togglePaymentStatus(recurring)
                    }
                }
            } message: {
                Text("Are you sure you want to stop this recurring payment? You can reactivate it later from the Services tab.")
            }
        }
    }

    private var statusColor: Color {
        switch transaction.status {
        case .completed:
            return AppConstants.Colors.successGreen
        case .pending:
            return AppConstants.Colors.warningOrange
        case .failed:
            return AppConstants.Colors.errorRed
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(AppConstants.Typography.subheadline)
                .foregroundColor(AppConstants.Colors.secondaryLabel)

            Spacer()

            if let icon = icon, let iconColor = iconColor {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.caption)
            }

            Text(value)
                .font(AppConstants.Typography.body)
                .foregroundColor(AppConstants.Colors.label)
                .multilineTextAlignment(.trailing)
        }
        .padding()
        .background(AppConstants.Colors.cardBackground)
        .cornerRadius(AppConstants.CornerRadius.medium)
    }
}

// MARK: - Preview

#Preview {
    TransactionDetailView(
        transaction: Transaction.mockTransactions[0],
        servicesViewModel: ServicesViewModel()
    )
}
