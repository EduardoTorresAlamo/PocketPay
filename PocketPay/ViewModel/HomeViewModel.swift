//
//  HomeViewModel.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

/// ViewModel backing `HomeView`.
///
/// Follows the MVVM pattern: `HomeView` observes `@Published` properties here
/// and calls the mutating methods below in response to user actions. Business
/// logic (balance formatting, greeting) is kept in the ViewModel so the view
/// remains purely declarative.
///
/// Isolated to the `MainActor` at class level: every stored property is
/// `@Published` and read directly by the view.
@MainActor
class HomeViewModel: ObservableObject {
    /// The authenticated user; sourced from `AuthManager.currentUser`.
    @Published var currentUser: User?
    /// The five most recent transactions, pre-fetched for the home screen summary.
    @Published var recentTransactions: [Transaction] = []
    /// Controls whether the balance card shows the actual amount or masked dots.
    @Published var isBalanceHidden = false
    /// Navigation flags for sheet presentation driven from action buttons.
    @Published var showingTransferView = false
    @Published var showingHistoryView = false
    @Published var showingScanQRView = false

    private let authManager: any AuthManaging
    private let paymentManager: any PaymentProcessing

    /// Creates the ViewModel with the given collaborators.
    ///
    /// Both default to the shared singletons so views can keep calling
    /// `HomeViewModel()`; tests inject doubles instead.
    init(
        authManager: any AuthManaging = AuthManager.shared,
        paymentManager: any PaymentProcessing = PaymentManager.shared
    ) {
        self.authManager = authManager
        self.paymentManager = paymentManager
        loadData()
    }

    /// Refreshes the user snapshot and recent transaction list from the shared singletons.
    func loadData() {
        currentUser = authManager.currentUser
        recentTransactions = paymentManager.getRecentTransactions(limit: 5)
    }

    /// Toggles the balance visibility flag, showing or hiding the dollar amount on the card.
    func toggleBalanceVisibility() {
        isBalanceHidden.toggle()
    }

    /// Returns a time-appropriate greeting string based on the current local hour.
    ///
    /// - Returns: `"Good Morning"` (0-11), `"Good Afternoon"` (12-16), or `"Good Evening"` (17-23).
    func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 0..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }

    /// Formats the current user's wallet balance as a USD currency string.
    ///
    /// - Returns: e.g., `"$1,250.00"`, or `"$0.00"` when no user is loaded.
    func getFormattedBalance() -> String {
        guard let balance = currentUser?.balance else { return "$0.00" }
        return String(format: "$%.2f", balance)
    }

    /// Alias for `loadData()` used by pull-to-refresh handlers.
    func refresh() {
        loadData()
    }
}
