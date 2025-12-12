//
//  SecureStorageManagerTests.swift
//  HomeKitAdopterTests
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomeKitAdopter

final class SecureStorageManagerTests: XCTestCase {

    var sut: SecureStorageManager!
    let testKey = "test_key_\(UUID().uuidString)"
    let testUserDefaultsKey = "test_userdefaults_\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        sut = SecureStorageManager.shared
    }

    override func tearDown() {
        // Clean up test data
        try? sut.delete(forKey: testKey)
        UserDefaults.standard.removeObject(forKey: testUserDefaultsKey)
        super.tearDown()
    }

    // MARK: - Basic Storage Tests

    func testStoreAndRetrieveString_ValidData_ReturnsCorrectValue() throws {
        // Given
        let testString = "Test String Value"

        // When
        try sut.storeString(testString, forKey: testKey)
        let retrieved = try sut.retrieveString(forKey: testKey)

        // Then
        XCTAssertEqual(retrieved, testString, "Retrieved string should match stored string")
    }

    func testStoreAndRetrieveCodable_ValidData_ReturnsCorrectValue() throws {
        // Given
        struct TestData: Codable, Equatable {
            let name: String
            let value: Int
            let timestamp: Date
        }

        let testData = TestData(name: "Test", value: 42, timestamp: Date())

        // When
        try sut.store(testData, forKey: testKey)
        let retrieved: TestData? = try sut.retrieve(TestData.self, forKey: testKey)

        // Then
        XCTAssertNotNil(retrieved, "Retrieved data should not be nil")
        XCTAssertEqual(retrieved, testData, "Retrieved data should match stored data")
    }

    func testRetrieve_NonExistentKey_ReturnsNil() throws {
        // Given - Non-existent key
        let nonExistentKey = "non_existent_\(UUID().uuidString)"

        // When
        let retrieved: String? = try sut.retrieve(String.self, forKey: nonExistentKey)

        // Then
        XCTAssertNil(retrieved, "Should return nil for non-existent key")
    }

    func testExists_ExistingKey_ReturnsTrue() throws {
        // Given
        try sut.storeString("Test", forKey: testKey)

        // When
        let exists = sut.exists(forKey: testKey)

        // Then
        XCTAssertTrue(exists, "Should return true for existing key")
    }

    func testExists_NonExistentKey_ReturnsFalse() {
        // Given - Non-existent key
        let nonExistentKey = "non_existent_\(UUID().uuidString)"

        // When
        let exists = sut.exists(forKey: nonExistentKey)

        // Then
        XCTAssertFalse(exists, "Should return false for non-existent key")
    }

    // MARK: - Update Tests

    func testStore_OverwriteExistingValue_ReturnsNewValue() throws {
        // Given
        let firstValue = "First Value"
        let secondValue = "Second Value"

        try sut.storeString(firstValue, forKey: testKey)

        // When
        try sut.storeString(secondValue, forKey: testKey)
        let retrieved = try sut.retrieveString(forKey: testKey)

        // Then
        XCTAssertEqual(retrieved, secondValue, "Should return updated value")
        XCTAssertNotEqual(retrieved, firstValue, "Should not return old value")
    }

    // MARK: - Delete Tests

    func testDelete_ExistingKey_RemovesData() throws {
        // Given
        try sut.storeString("Test", forKey: testKey)
        XCTAssertTrue(sut.exists(forKey: testKey), "Key should exist before delete")

        // When
        try sut.delete(forKey: testKey)

        // Then
        XCTAssertFalse(sut.exists(forKey: testKey), "Key should not exist after delete")
    }

    func testDelete_NonExistentKey_DoesNotThrowError() {
        // Given - Non-existent key
        let nonExistentKey = "non_existent_\(UUID().uuidString)"

        // When/Then - Should not throw
        XCTAssertNoThrow(try sut.delete(forKey: nonExistentKey),
                         "Deleting non-existent key should not throw error")
    }

    // MARK: - Migration Tests

    func testMigrateFromUserDefaults_ValidData_MigratesSuccessfully() throws {
        // Given - Store data in UserDefaults
        let testData = "Migration Test Data".data(using: .utf8)!
        UserDefaults.standard.set(testData, forKey: testUserDefaultsKey)

        // When
        try sut.migrateFromUserDefaults(key: testKey, userDefaultsKey: testUserDefaultsKey)

        // Then - Data should be in Keychain
        let retrieved: Data? = try sut.retrieve(Data.self, forKey: testKey)
        XCTAssertNotNil(retrieved, "Data should exist in Keychain after migration")
        XCTAssertEqual(retrieved, testData, "Migrated data should match original")

        // And - Data should be removed from UserDefaults
        let userDefaultsData = UserDefaults.standard.data(forKey: testUserDefaultsKey)
        XCTAssertNil(userDefaultsData, "Data should be removed from UserDefaults after migration")
    }

    func testMigrateFromUserDefaults_AlreadyMigrated_DoesNotOverwrite() throws {
        // Given - Data already in Keychain
        let keychainData = "Keychain Data".data(using: .utf8)!
        try sut.store(keychainData, forKey: testKey)

        // And - Different data in UserDefaults
        let userDefaultsData = "UserDefaults Data".data(using: .utf8)!
        UserDefaults.standard.set(userDefaultsData, forKey: testUserDefaultsKey)

        // When
        try sut.migrateFromUserDefaults(key: testKey, userDefaultsKey: testUserDefaultsKey)

        // Then - Keychain data should remain unchanged
        let retrieved: Data? = try sut.retrieve(Data.self, forKey: testKey)
        XCTAssertEqual(retrieved, keychainData, "Should not overwrite existing Keychain data")
    }

    func testMigrateFromUserDefaults_NoUserDefaultsData_DoesNothing() {
        // Given - No data in UserDefaults
        UserDefaults.standard.removeObject(forKey: testUserDefaultsKey)

        // When/Then - Should not throw
        XCTAssertNoThrow(try sut.migrateFromUserDefaults(key: testKey, userDefaultsKey: testUserDefaultsKey),
                         "Should handle missing UserDefaults data gracefully")
    }

    // MARK: - Complex Data Types Tests

    func testStoreAndRetrieve_ArrayOfStrings_ReturnsCorrectValue() throws {
        // Given
        let testArray = ["Item 1", "Item 2", "Item 3"]

        // When
        try sut.store(testArray, forKey: testKey)
        let retrieved: [String]? = try sut.retrieve([String].self, forKey: testKey)

        // Then
        XCTAssertEqual(retrieved, testArray, "Retrieved array should match stored array")
    }

    func testStoreAndRetrieve_DictionaryData_ReturnsCorrectValue() throws {
        // Given
        let testDictionary = ["key1": "value1", "key2": "value2"]

        // When
        try sut.store(testDictionary, forKey: testKey)
        let retrieved: [String: String]? = try sut.retrieve([String: String].self, forKey: testKey)

        // Then
        XCTAssertEqual(retrieved, testDictionary, "Retrieved dictionary should match stored dictionary")
    }

    func testStoreAndRetrieve_NestedCodableStructure_ReturnsCorrectValue() throws {
        // Given
        struct Address: Codable, Equatable {
            let street: String
            let city: String
        }

        struct Person: Codable, Equatable {
            let name: String
            let age: Int
            let address: Address
        }

        let testPerson = Person(
            name: "John Doe",
            age: 30,
            address: Address(street: "123 Main St", city: "Springfield")
        )

        // When
        try sut.store(testPerson, forKey: testKey)
        let retrieved: Person? = try sut.retrieve(Person.self, forKey: testKey)

        // Then
        XCTAssertEqual(retrieved, testPerson, "Retrieved nested structure should match stored structure")
    }

    // MARK: - Date Encoding Tests

    func testStoreAndRetrieve_DataWithDate_PreservesDatePrecision() throws {
        // Given
        struct TimestampedData: Codable {
            let timestamp: Date
            let value: String
        }

        let now = Date()
        let testData = TimestampedData(timestamp: now, value: "Test")

        // When
        try sut.store(testData, forKey: testKey)
        let retrieved: TimestampedData? = try sut.retrieve(TimestampedData.self, forKey: testKey)

        // Then
        XCTAssertNotNil(retrieved, "Retrieved data should not be nil")
        // ISO8601 encoding may lose sub-millisecond precision, so compare within 1 second
        let timeDifference = abs(retrieved!.timestamp.timeIntervalSince(now))
        XCTAssertLessThan(timeDifference, 1.0, "Date should be preserved with reasonable precision")
    }

    // MARK: - Storage Statistics Tests

    func testGetAllKeys_MultipleItems_ReturnsAllKeys() throws {
        // Given - Store multiple items
        let keys = [
            "test_key_1_\(UUID().uuidString)",
            "test_key_2_\(UUID().uuidString)",
            "test_key_3_\(UUID().uuidString)"
        ]

        for key in keys {
            try sut.storeString("Test", forKey: key)
        }

        // When
        let allKeys = sut.getAllKeys()

        // Then - All test keys should be present
        for key in keys {
            XCTAssertTrue(allKeys.contains(key), "All stored keys should be returned")
        }

        // Cleanup
        for key in keys {
            try? sut.delete(forKey: key)
        }
    }

    func testGetStorageStats_MultipleItems_ReturnsCorrectCounts() throws {
        // Given - Store multiple items
        let keys = [
            "stats_test_1_\(UUID().uuidString)",
            "stats_test_2_\(UUID().uuidString)"
        ]

        for key in keys {
            try sut.storeString("Test Data", forKey: key)
        }

        // When
        let stats = sut.getStorageStats()

        // Then
        XCTAssertGreaterThanOrEqual(stats.itemCount, keys.count, "Item count should include all test items")
        XCTAssertGreaterThan(stats.totalSize, 0, "Total size should be greater than zero")

        // Cleanup
        for key in keys {
            try? sut.delete(forKey: key)
        }
    }

    // MARK: - Error Handling Tests

    func testRetrieve_CorruptedData_ThrowsDecodingError() throws {
        // Given - Store raw data that doesn't match expected type
        struct ComplexType: Codable {
            let name: String
            let value: Int
        }

        // Store simple string
        try sut.storeString("Not a ComplexType", forKey: testKey)

        // When/Then - Retrieving as ComplexType should throw
        XCTAssertThrowsError(try sut.retrieve(ComplexType.self, forKey: testKey)) { error in
            guard let storageError = error as? SecureStorageManager.StorageError else {
                XCTFail("Should throw StorageError")
                return
            }

            if case .decodingFailed = storageError {
                // Expected error
            } else {
                XCTFail("Should throw decodingFailed error, got: \(storageError)")
            }
        }
    }

    // MARK: - OSStatus Extension Tests

    func testOSStatusExtension_KnownErrors_ReturnsReadableDescription() {
        // Given/When/Then
        XCTAssertEqual(errSecSuccess.keychainErrorDescription, "Success")
        XCTAssertEqual(errSecItemNotFound.keychainErrorDescription, "Item not found")
        XCTAssertEqual(errSecDuplicateItem.keychainErrorDescription, "Duplicate item")
        XCTAssertEqual(errSecAuthFailed.keychainErrorDescription, "Authentication failed")
    }

    // MARK: - Performance Tests

    func testStorePerformance_MultipleItems_CompletesQuickly() {
        // Measure performance of storing 100 items
        measure {
            for i in 0..<100 {
                let key = "perf_test_\(i)"
                try? sut.storeString("Test \(i)", forKey: key)
            }
        }

        // Cleanup
        for i in 0..<100 {
            let key = "perf_test_\(i)"
            try? sut.delete(forKey: key)
        }
    }

    func testRetrievePerformance_MultipleItems_CompletesQuickly() throws {
        // Given - Store 100 items
        for i in 0..<100 {
            let key = "perf_retrieve_test_\(i)"
            try sut.storeString("Test \(i)", forKey: key)
        }

        // Measure
        measure {
            for i in 0..<100 {
                let key = "perf_retrieve_test_\(i)"
                _ = try? sut.retrieveString(forKey: key)
            }
        }

        // Cleanup
        for i in 0..<100 {
            let key = "perf_retrieve_test_\(i)"
            try? sut.delete(forKey: key)
        }
    }
}
