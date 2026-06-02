//
//  MainTabView.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

/// Root tab container shown after the user authenticates.
///
/// Provides three top-level destinations: Home (balance and recent transactions),
/// Wallet (saved cards), and Profile (user settings and logout).
/// The accent color matches the app's primary purple brand color.
struct MainTabView: View {
    /// Tracks the currently visible tab (0 = Home, 1 = Wallet, 2 = Profile).
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            // Wallet Tab
            WalletView()
                .tabItem {
                    Label("Wallet", systemImage: "creditcard.fill")
                }
                .tag(1)

            // Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
        }
        .accentColor(AppConstants.Colors.primaryPurple)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
