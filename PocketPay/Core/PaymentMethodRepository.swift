//
//  PaymentMethodRepository.swift
//  PocketPay
//
//  Created by Eduardo Torres on 8/13/26.
//

import Foundation

/// Abstraction over the persistence layer for the user's saved cards.
///
/// The domain model (`PaymentMethod`) has no knowledge of how or where cards are
/// stored. `WalletViewModel` depends on this protocol and receives a concrete
/// implementation via injection, so a test double can be substituted in unit
/// tests and the storage backend can change without touching the model.
protocol PaymentMethodRepository {
    /// Persists the full list of payment methods, replacing any stored value.
    func saveAll(_ methods: [PaymentMethod])
    /// Returns the persisted payment methods, falling back to the mock set when
    /// nothing has been stored yet so a fresh install still shows sample cards.
    func loadAll() -> [PaymentMethod]
    /// Removes all persisted payment methods, if any.
    func clearAll()
}

/// `PaymentMethodRepository` backed by the iOS Keychain via `KeychainManager`.
struct KeychainPaymentMethodRepository: PaymentMethodRepository {
    private static let keychainKey = "com.pocketpay.payment_methods"

    func saveAll(_ methods: [PaymentMethod]) {
        KeychainManager.save(methods, key: Self.keychainKey)
    }

    func loadAll() -> [PaymentMethod] {
        let methods: [PaymentMethod]? = KeychainManager.load(key: Self.keychainKey)
        return methods ?? PaymentMethod.mockPaymentMethods
    }

    func clearAll() {
        KeychainManager.delete(key: Self.keychainKey)
    }
}
