//
//  User.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation

/// The authenticated user's profile and financial state.
///
/// `User` is a value type so mutations (e.g., balance updates) are explicit.
struct User: Identifiable, Codable {
    let id: UUID
    var username: String
    var fullName: String
    var email: String
    var phoneNumber: String
    var mailingAddress: String
    var balance: Double
    var profileImageUrl: String?

    init(
        id: UUID = UUID(),
        username: String,
        fullName: String,
        email: String,
        phoneNumber: String,
        mailingAddress: String = "",
        balance: Double,
        profileImageUrl: String? = nil
    ) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.email = email
        self.phoneNumber = phoneNumber
        self.mailingAddress = mailingAddress
        self.balance = balance
        self.profileImageUrl = profileImageUrl
    }

    static var mockUser: User {
        User(
            username: "johndoe",
            fullName: "John Doe",
            email: "john.doe@example.com",
            phoneNumber: "+1 787 555 0123",
            mailingAddress: "123 Main St, San Juan, PR 00901",
            balance: 1250.00
        )
    }
}

// MARK: - Keychain Persistence

extension User {
    private static let keychainKey = "com.pocketpay.current_user"

    /// Encodes and persists the user to Keychain.
    func save() {
        KeychainManager.save(self, key: User.keychainKey)
    }

    /// Decodes and returns the user from Keychain, or `nil` if none exists.
    static func load() -> User? {
        let user: User? = KeychainManager.load(key: keychainKey)
        return user
    }

    /// Removes the saved user from Keychain.
    static func clearSaved() {
        KeychainManager.delete(key: keychainKey)
    }
}
