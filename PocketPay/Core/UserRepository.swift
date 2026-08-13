//
//  UserRepository.swift
//  PocketPay
//
//  Created by Eduardo Torres on 8/13/26.
//

import Foundation

/// Abstraction over the persistence layer for the authenticated `User`.
///
/// The domain model (`User`) has no knowledge of how or where it is stored.
/// Collaborators such as `AuthManager` depend on this protocol and receive a
/// concrete implementation via injection, so a test double can be substituted
/// in unit tests and the storage backend can change without touching the model.
protocol UserRepository {
    /// Persists the given user, replacing any previously stored value.
    func save(_ user: User)
    /// Returns the persisted user, or `nil` when none has been stored.
    func load() -> User?
    /// Removes the persisted user, if any.
    func clear()
}

/// `UserRepository` backed by the iOS Keychain via `KeychainManager`.
struct KeychainUserRepository: UserRepository {
    private static let keychainKey = "com.pocketpay.current_user"

    func save(_ user: User) {
        KeychainManager.save(user, key: Self.keychainKey)
    }

    func load() -> User? {
        KeychainManager.load(key: Self.keychainKey)
    }

    func clear() {
        KeychainManager.delete(key: Self.keychainKey)
    }
}
