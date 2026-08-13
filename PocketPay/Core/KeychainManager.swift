//
//  KeychainManager.swift
//  PocketPay
//
//  Created by Eduardo Torres on 8/6/26.
//
import Foundation
import Security
import os

/// Wrapper around iOS Keychain Services for secure persistence of sensitive data.
///
/// Use this instead of `UserDefaults` for PII, card metadata, and auth tokens.
/// Data is encrypted at rest and accessible only to this app on this device.
struct KeychainManager {
    private static let service = "com.pocketpay.keychain"
    /// Structured logger; never logs the stored value, only the operation status.
    private static let log = Logger(subsystem: "com.pocketpay", category: "Keychain")

    /// Saves a `Codable` value to the Keychain.
    ///
    /// Both the delete and add `OSStatus` results are validated so a silent
    /// failure (e.g., the device is locked or the Keychain is out of quota) is
    /// surfaced to the log instead of being swallowed.
    ///
    /// - Returns: `true` when the item was written successfully.
    @discardableResult
    static func save<T: Codable>(_ value: T, key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else {
            log.error("Failed to encode value for key \(key, privacy: .public)")
            return false
        }

        // Delete existing item first to avoid duplication. errSecItemNotFound is
        // expected on first write and is not treated as a failure.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            log.error("Keychain delete failed for key \(key, privacy: .public): OSStatus \(deleteStatus)")
            return false
        }

        // Add new item with access control (accessible when unlocked, this device only).
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            log.error("Keychain add failed for key \(key, privacy: .public): OSStatus \(addStatus)")
            return false
        }
        return true
    }

    /// Loads a `Codable` value from the Keychain, or returns `nil` if not found.
    static func load<T: Codable>(key: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Deletes a value from the Keychain.
    ///
    /// - Returns: `true` when the item was removed or did not exist.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            log.error("Keychain delete failed for key \(key, privacy: .public): OSStatus \(status)")
            return false
        }
        return true
    }

    /// Clears all PocketPay Keychain items.
    ///
    /// - Returns: `true` when the items were removed or none existed.
    @discardableResult
    static func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            log.error("Keychain clearAll failed: OSStatus \(status)")
            return false
        }
        return true
    }
}
