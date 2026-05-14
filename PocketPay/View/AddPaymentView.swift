//
//  AddPaymentView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

struct AddPaymentView: View {
    @ObservedObject var viewModel: ServicesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Biller Information") {
                    TextField("Biller Name", text: $viewModel.billerName)
                        .autocapitalization(.words)

                    HStack {
                        Text("$")
                            .foregroundColor(AppConstants.Colors.secondaryLabel)
                        TextField("Amount", value: $viewModel.amount, format: .number)
                            .keyboardType(.decimalPad)
                    }

                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                }

                Section {
                    Toggle("Make this a recurring payment", isOn: $viewModel.isRecurringEnabled)
                        .tint(AppConstants.Colors.primaryPurple)
                }

                if viewModel.isRecurringEnabled {
                    Section("Recurring Payment Details") {
                        Picker("Frequency", selection: $viewModel.selectedFrequency) {
                            ForEach(PaymentFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }

                        DatePicker(
                            "Next Payment Date",
                            selection: $viewModel.nextPaymentDate,
                            displayedComponents: .date
                        )

                        Toggle("Enable Auto-Pay", isOn: $viewModel.autoPayEnabled)
                            .tint(AppConstants.Colors.primaryPurple)

                        Toggle("Add to Calendar", isOn: $viewModel.addToCalendarEnabled)
                            .tint(AppConstants.Colors.primaryPurple)

                        if viewModel.addToCalendarEnabled {
                            Picker("Remind me", selection: $viewModel.reminderOffset) {
                                Text("1 day before").tag(1)
                                Text("2 days before").tag(2)
                                Text("3 days before").tag(3)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                Section("Additional Notes") {
                    TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.payOneTimeBill()
                            if viewModel.errorMessage == nil && !viewModel.isProcessing {
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(viewModel.isRecurringEnabled ? "Add & Pay" : "Pay Now")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.billerName.isEmpty || viewModel.amount <= 0 || viewModel.isProcessing)
                    .listRowBackground(
                        (viewModel.billerName.isEmpty || viewModel.amount <= 0 || viewModel.isProcessing)
                        ? AppConstants.Colors.secondaryLabel.opacity(0.3)
                        : AppConstants.Colors.primaryPurple
                    )
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("Pay a Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.resetForm()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddPaymentView(viewModel: ServicesViewModel())
}
