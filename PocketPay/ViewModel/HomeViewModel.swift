//
//  HomeViewModel.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var recentTransactions: [Transaction] = []
    @Published var isBalanceHidden = false
    @Published var showingTransferView = false
    @Published var showingHistoryView = false
    @Published var showingScanQRView = false

    private let authManager = AuthManager.shared
    private let paymentManager = PaymentManager.shared

    init() {
        loadData()
    }

    func loadData() {
        currentUser = authManager.currentUser
        recentTransactions = paymentManager.getRecentTransactions(limit: 5)
    }

    func toggleBalanceVisibility() {
        isBalanceHidden.toggle()
    }

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

    func getFormattedBalance() -> String {
        guard let balance = currentUser?.balance else { return "$0.00" }
        return String(format: "$%.2f", balance)
    }

    func refresh() {
        loadData()
    }
}
