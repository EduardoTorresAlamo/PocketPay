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
