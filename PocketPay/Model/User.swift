//
//  User.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation

/// The authenticated user's profile and financial state.
///
/// `User` is a value type so mutations (e.g., balance updates) are explicit.
/// The `AuthManager` holds the canonical instance; `PaymentManager` reads it
/// for balance validation and deducts from it on successful payments.
struct User: Identifiable, Codable {
    /// Stable UUID used as the primary key in any future backend integration.
    let id: UUID
    /// Login handle; lowercased for comparison during authentication.
    var username: String
    /// Full display name shown in `ProfileView` and the home screen greeting.
    var fullName: String
    /// Contact email address, editable from `ProfileView`.
    var email: String
    /// Phone number used for P2P transfers and contact lookup.
    var phoneNumber: String
    /// Physical mailing address, editable from `ProfileView`.
    var mailingAddress: String
    /// Available wallet balance in USD. Decremented locally on successful payments.
    var balance: Double
    /// Remote URL to a profile avatar image. Currently unused; reserved for future use.
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

    /// Pre-built demo user used when no saved user exists and the demo login succeeds.
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

// MARK: - User Persistence

/// `UserDefaults`-backed persistence for the current user's profile.
///
/// In production this should be replaced with Keychain storage (for sensitive
/// fields) and a remote profile API. `UserDefaults` is acceptable here because
/// only non-sensitive profile information is stored.
extension User {
    /// `UserDefaults` key under which the encoded `User` blob is stored.
    private static let userDefaultsKey = "prpay_current_user"

    /// Encodes and persists the user to `UserDefaults`.
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: User.userDefaultsKey)
        }
    }

    /// Decodes and returns the previously saved user, or `nil` if none exists.
    static func load() -> User? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }

    /// Removes the saved user from `UserDefaults`, effectively clearing the profile cache.
    static func clearSaved() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
