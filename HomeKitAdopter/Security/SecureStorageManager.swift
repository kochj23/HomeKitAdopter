//
//  SecureStorageManager.swift
//  HomeKitAdopter - Secure Storage with Keychain
//
//  Created by Jordan Koch on 2025-11-21.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import Security

/// Secure storage manager using iOS/tvOS Keychain
///
/// Stores sensitive data (device history, network information) in the Keychain
/// instead of UserDefaults to provide encryption at rest. The Keychain provides:
/// - Hardware-backed encryption on supported devices
/// - Automatic encryption at rest
/// - Access control and sandboxing
/// - Secure backup and restore
///
/// This prevents:
/// - Unencrypted data exposure in UserDefaults
/// - Backup files leaking network topology
/// - Physical access attacks on device
class SecureStorageManager {

    static let shared = SecureStorageManager()

    private let keychainService = "com.digitalnoise.homekitadopter.secure"

    // MARK: - Error Types

    enum StorageError: LocalizedError {
        case encodingFailed
        case decodingFailed
        case keychainOperationFailed(OSStatus)
        case itemNotFound
        case duplicateItem
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "Failed to encode data for storage"
            case .decodingFailed:
                return "Failed to decode data from storage"
            case .keychainOperationFailed(let status):
                return "Keychain operation failed with status: \(status)"
            case .itemNotFound:
                return "Item not found in secure storage"
            case .duplicateItem:
                return "Item already exists in secure storage"
            case .accessDenied:
                return "Access denied to secure storage"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        LoggingManager.shared.info("SecureStorageManager initialized")
    }

    // MARK: - Generic Storage Methods

    /// Securely store any Codable data in Keychain
    func store<T: Codable>(_ data: T, forKey key: String) throws {
        // Encode data to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(data) else {
            LoggingManager.shared.error("Failed to encode data for key: \(key)")
            throw StorageError.encodingFailed
        }

        // Create query for Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: jsonData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete existing item (if any)
        SecItemDelete(query as CFDictionary)

        // Add new item to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            LoggingManager.shared.error("Keychain store failed for key '\(key)' with status: \(status)")
            throw StorageError.keychainOperationFailed(status)
        }

        LoggingManager.shared.info("Successfully stored data for key: \(key)")
    }

    /// Retrieve and decode data from Keychain
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        // Create query for Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        // Item not found is not an error - return nil
        guard status != errSecItemNotFound else {
            LoggingManager.shared.info("No data found for key: \(key)")
            return nil
        }

        // Other errors are failures
        guard status == errSecSuccess else {
            LoggingManager.shared.error("Keychain retrieve failed for key '\(key)' with status: \(status)")
            throw StorageError.keychainOperationFailed(status)
        }

        // Get data from result
        guard let jsonData = result as? Data else {
            LoggingManager.shared.error("Invalid data format for key: \(key)")
            throw StorageError.decodingFailed
        }

        // Decode JSON data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let decodedData = try? decoder.decode(T.self, from: jsonData) else {
            LoggingManager.shared.error("Failed to decode data for key: \(key)")
            throw StorageError.decodingFailed
        }

        LoggingManager.shared.info("Successfully retrieved data for key: \(key)")
        return decodedData
    }

    /// Delete data from Keychain
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Item not found is not an error
        guard status == errSecSuccess || status == errSecItemNotFound else {
            LoggingManager.shared.error("Keychain delete failed for key '\(key)' with status: \(status)")
            throw StorageError.keychainOperationFailed(status)
        }

        LoggingManager.shared.info("Successfully deleted data for key: \(key)")
    }

    /// Delete all data for this app from Keychain
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Item not found is not an error
        guard status == errSecSuccess || status == errSecItemNotFound else {
            LoggingManager.shared.error("Keychain deleteAll failed with status: \(status)")
            throw StorageError.keychainOperationFailed(status)
        }

        LoggingManager.shared.info("Successfully deleted all secure storage data")
    }

    // MARK: - Migration from UserDefaults

    /// Migrate data from UserDefaults to Keychain
    func migrateFromUserDefaults(key: String, userDefaultsKey: String) throws {
        // Check if already migrated
        if let _: Data = try? retrieve(Data.self, forKey: key) {
            LoggingManager.shared.info("Data already migrated for key: \(key)")
            return
        }

        // Get data from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            LoggingManager.shared.info("No UserDefaults data to migrate for key: \(userDefaultsKey)")
            return
        }

        // Store in Keychain
        try store(data, forKey: key)

        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()

        LoggingManager.shared.info("Successfully migrated data from UserDefaults to Keychain")
    }

    // MARK: - Convenience Methods for Common Data Types

    /// Store string securely
    func storeString(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw StorageError.encodingFailed
        }
        try store(data, forKey: key)
    }

    /// Retrieve string securely
    func retrieveString(forKey key: String) throws -> String? {
        guard let data: Data = try retrieve(Data.self, forKey: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Check if key exists
    func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Diagnostic Methods

    /// Get list of all stored keys (for debugging)
    func getAllKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    /// Get storage statistics
    func getStorageStats() -> (itemCount: Int, totalSize: Int) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return (0, 0)
        }

        let totalSize = items.reduce(0) { total, item in
            if let data = item[kSecValueData as String] as? Data {
                return total + data.count
            }
            return total
        }

        return (items.count, totalSize)
    }
}

// MARK: - OSStatus Extensions

extension OSStatus {
    /// Human-readable description of Keychain error status
    var keychainErrorDescription: String {
        switch self {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecParam:
            return "Invalid parameter"
        case errSecAllocate:
            return "Memory allocation failed"
        case errSecNotAvailable:
            return "Service not available"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecDecode:
            return "Decoding failed"
        case errSecInteractionNotAllowed:
            return "User interaction not allowed"
        default:
            return "Unknown error: \(self)"
        }
    }
}
