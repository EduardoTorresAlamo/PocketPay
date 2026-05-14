//
//  PRPayApp.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

@main
struct PRPayApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var paymentManager = PaymentManager.shared

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
