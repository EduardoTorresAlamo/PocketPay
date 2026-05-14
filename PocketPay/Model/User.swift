//
//  User.swift
//  PRPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import Foundation

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

    // Mock current user
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
extension User {
    private static let userDefaultsKey = "prpay_current_user"

    // Save user to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: User.userDefaultsKey)
        }
    }

    // Load user from UserDefaults
    static func load() -> User? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }

    // Clear saved user
    static func clearSaved() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
