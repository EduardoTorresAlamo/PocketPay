//
//  TransferView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

/// The full P2P money-transfer flow presented as a sheet from `HomeView`.
///
/// The view is stateless and delegates all logic to `TransferViewModel`. It
/// switches between two sub-views based on whether a contact has been selected:
/// - `ContactSelectionView` (Phase 1): search and pick a recipient.
/// - `AmountInputView` (Phase 2): enter an amount on the custom keypad and send.
///
/// A semi-transparent loading overlay appears while the payment is in flight.
struct TransferView: View {
    @StateObject private var viewModel = TransferViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Contact Selection Section
                    if viewModel.selectedContact == nil {
                        ContactSelectionView(viewModel: viewModel)
                    } else {
                        // Amount Input Section
                        AmountInputView(viewModel: viewModel)
                    }
                }

                // Loading Overlay
                if viewModel.isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppConstants.Colors.primaryPurple))
                }
            }
            .navigationTitle(viewModel.selectedContact == nil ? "Send Money" : "Enter Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if viewModel.selectedContact != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Back") {
                            viewModel.selectedContact = nil
                        }
                    }
                }
            }
            .alert("Transfer Successful", isPresented: $viewModel.showingSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("You've successfully sent \(viewModel.getFormattedAmount()) to \(viewModel.selectedContact?.name ?? "recipient")")
            }
            .alert("Transfer Failed", isPresented: $viewModel.showTransferError) {
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

// MARK: - Contact Selection View

/// Phase 1 of the transfer flow: a searchable contact list.
///
/// The search field filters by name or phone number via
/// `TransferViewModel.searchContacts()`. Tapping a row calls
/// `viewModel.selectContact(_:)` which advances to Phase 2.
struct ContactSelectionView: View {
    @ObservedObject var viewModel: TransferViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppConstants.Colors.secondaryLabel)

                TextField("Enter name or phone number", text: $viewModel.searchText)
                    .font(AppConstants.Typography.body)
                    

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.searchContacts()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppConstants.Colors.secondaryLabel)
                    }
                }
            }
            .padding()
            .background(AppConstants.Colors.cardBackground)
            .cornerRadius(AppConstants.CornerRadius.medium)
            .padding()

            // Contacts List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredContacts) { contact in
                        ContactRowView(contact: contact) {
                            viewModel.selectContact(contact)
                        }

                        if contact.id != viewModel.filteredContacts.last?.id {
                            Divider()
                                .padding(.leading, 70)
                        }
                    }
                }
            }
        }
        .background(AppConstants.Colors.cardBackground)
    }
}

// MARK: - Contact Row View

/// A single row in the contact list, showing an avatar with initials,
/// the contact's name, phone number, and a favorite star when applicable.
struct ContactRowView: View {
    let contact: Contact
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppConstants.Spacing.medium) {
                // Avatar
                Circle()
                    .fill(AppConstants.Colors.primaryPurple.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(contact.initials)
                            .font(AppConstants.Typography.headline)
                            .foregroundColor(AppConstants.Colors.primaryPurple)
                    )

                // Contact Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(AppConstants.Typography.body)
                        .foregroundColor(AppConstants.Colors.label)

                    Text(contact.phoneNumber)
                        .font(AppConstants.Typography.caption)
                        .foregroundColor(AppConstants.Colors.secondaryLabel)
                }

                Spacer()

                if contact.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(AppConstants.Colors.primaryPurple)
                        .font(.caption)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(AppConstants.Colors.secondaryLabel)
                    .font(.caption)
            }
            .padding()
            .background(AppConstants.Colors.cardBackground)
        }
    }
}

// MARK: - Amount Input View

/// Phase 2 of the transfer flow: amount entry via the custom numeric keypad.
///
/// Shows the selected contact's avatar and name at the top, the running
/// formatted amount in large text, an optional notes field, and the keypad.
/// The "Send Money" button remains disabled until `viewModel.canSendMoney()` is true.
struct AmountInputView: View {
    @ObservedObject var viewModel: TransferViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Selected Contact Info
            VStack(spacing: AppConstants.Spacing.medium) {
                Circle()
                    .fill(AppConstants.Colors.primaryPurple.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(viewModel.selectedContact?.initials ?? "")
                            .font(AppConstants.Typography.largeTitle)
                            .foregroundColor(AppConstants.Colors.primaryPurple)
                    )

                Text(viewModel.selectedContact?.name ?? "")
                    .font(AppConstants.Typography.title2)
                    .foregroundColor(AppConstants.Colors.label)
                    .bold()

                Text(viewModel.selectedContact?.phoneNumber ?? "")
                    .font(AppConstants.Typography.subheadline)
                    .foregroundColor(AppConstants.Colors.secondaryLabel)
            }
            .padding(.top, AppConstants.Spacing.large)

            Spacer()

            // Amount Display
            VStack(spacing: AppConstants.Spacing.small) {
                Text("Amount")
                    .font(AppConstants.Typography.subheadline)
                    .foregroundColor(AppConstants.Colors.secondaryLabel)

                Text(viewModel.getFormattedAmount())
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(AppConstants.Colors.label)
            }
            .padding()

            // Notes Field
            TextField("Add a note (optional)", text: $viewModel.notes)
                .font(AppConstants.Typography.body)
                .padding()
                .background(AppConstants.Colors.cardBackground)
                .cornerRadius(AppConstants.CornerRadius.medium)
                .padding(.horizontal)

            Spacer()

            // Numeric Keypad
            NumericKeypadView(viewModel: viewModel)
                .padding(.bottom, AppConstants.Spacing.medium)

            // Send Button
            Button(action: {
                Task {
                    await viewModel.sendMoney()
                }
            }) {
                Text("Send Money")
                    .font(AppConstants.Typography.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(viewModel.canSendMoney() ? AppConstants.Colors.primaryPurple : AppConstants.Colors.secondaryLabel.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(AppConstants.CornerRadius.medium)
            }
            .disabled(!viewModel.canSendMoney() || viewModel.isProcessing)
            .padding(.horizontal)
            .padding(.bottom, AppConstants.Spacing.large)
        }
        .background(AppConstants.Colors.cardBackground)
    }
}

// MARK: - Numeric Keypad View

/// A 3x4 grid numeric keypad that drives the shift-register amount input.
///
/// Digits 1-9 are laid out in the top three rows. Row 4 contains:
/// - A disabled decimal point (`.`): the amount always has two implied decimal places,
///   so explicit decimal input is not needed.
/// - The `0` key.
/// - A backspace key (delete icon) that calls `viewModel.deleteLastDigit()`.
struct NumericKeypadView: View {
    @ObservedObject var viewModel: TransferViewModel

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppConstants.Spacing.medium) {
            ForEach(1...9, id: \.self) { number in
                KeypadButton(text: "\(number)") {
                    viewModel.appendDigit("\(number)")
                }
            }

            KeypadButton(text: ".", disabled: true) {
                // Decimal point - disabled for now
            }

            KeypadButton(text: "0") {
                viewModel.appendDigit("0")
            }

            KeypadButton(icon: "delete.left") {
                viewModel.deleteLastDigit()
            }
        }
        .padding(.horizontal, AppConstants.Spacing.large)
    }
}

// MARK: - Keypad Button

/// An individual button cell in `NumericKeypadView`.
///
/// Supports two initializers: one for text labels (digits) and one for SF Symbol
/// icons (the backspace key). A `disabled` flag renders the button grayed-out and
/// non-interactive; used for the decimal point key which is reserved but inactive.
struct KeypadButton: View {
    let text: String?
    let icon: String?
    var disabled: Bool = false
    let action: () -> Void

    /// Text-label initializer for digit keys.
    init(text: String, disabled: Bool = false, action: @escaping () -> Void) {
        self.text = text
        self.icon = nil
        self.disabled = disabled
        self.action = action
    }

    /// Icon initializer for the backspace key (uses an SF Symbol name).
    init(icon: String, disabled: Bool = false, action: @escaping () -> Void) {
        self.text = nil
        self.icon = icon
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(disabled ? Color.clear : AppConstants.Colors.cardBackground)
                    .frame(width: 70, height: 70)

                if let text = text {
                    Text(text)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundColor(disabled ? AppConstants.Colors.secondaryLabel.opacity(0.3) : AppConstants.Colors.label)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(AppConstants.Colors.label)
                }
            }
        }
        .disabled(disabled)
    }
}

// MARK: - Preview

#Preview {
    TransferView()
}
