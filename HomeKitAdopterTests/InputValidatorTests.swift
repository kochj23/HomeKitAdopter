//
//  InputValidatorTests.swift
//  HomeKitAdopterTests
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomeKitAdopter

final class InputValidatorTests: XCTestCase {

    // MARK: - Device Name Validation Tests

    func testSanitizeDeviceName_ValidName_ReturnsUnchanged() {
        // Given
        let validName = "Living Room Light"

        // When
        let sanitized = InputValidator.sanitizeDeviceName(validName)

        // Then
        XCTAssertEqual(sanitized, validName, "Valid device name should be unchanged")
    }

    func testSanitizeDeviceName_EmptyString_ReturnsUnknownDevice() {
        // Given
        let emptyName = ""

        // When
        let sanitized = InputValidator.sanitizeDeviceName(emptyName)

        // Then
        XCTAssertEqual(sanitized, "Unknown Device", "Empty name should return 'Unknown Device'")
    }

    func testSanitizeDeviceName_TooLong_TruncatesToMaxLength() {
        // Given - String longer than maxDeviceNameLength (255)
        let longName = String(repeating: "A", count: 300)

        // When
        let sanitized = InputValidator.sanitizeDeviceName(longName)

        // Then
        XCTAssertEqual(sanitized.count, InputValidator.maxDeviceNameLength,
                       "Name should be truncated to max length")
    }

    func testSanitizeDeviceName_ContainsScriptTag_RemovesScriptTag() {
        // Given
        let maliciousName = "Device<script>alert('XSS')</script>"

        // When
        let sanitized = InputValidator.sanitizeDeviceName(maliciousName)

        // Then
        XCTAssertFalse(sanitized.lowercased().contains("<script"),
                       "Should remove <script> tags")
        XCTAssertFalse(sanitized.lowercased().contains("</script>"),
                       "Should remove </script> tags")
    }

    func testSanitizeDeviceName_ContainsJavaScript_RemovesJavaScript() {
        // Given
        let maliciousName = "Device javascript:alert('XSS')"

        // When
        let sanitized = InputValidator.sanitizeDeviceName(maliciousName)

        // Then
        XCTAssertFalse(sanitized.lowercased().contains("javascript:"),
                       "Should remove javascript: protocol")
    }

    func testSanitizeDeviceName_ContainsPHP_RemovesPHP() {
        // Given
        let maliciousName = "Device<?php echo 'test'; ?>"

        // When
        let sanitized = InputValidator.sanitizeDeviceName(maliciousName)

        // Then
        XCTAssertFalse(sanitized.contains("<?php"),
                       "Should remove PHP tags")
    }

    func testSanitizeDeviceName_ContainsCommandInjection_RemovesCommandChars() {
        // Given
        let maliciousName = "Device$(whoami)"

        // When
        let sanitized = InputValidator.sanitizeDeviceName(maliciousName)

        // Then
        XCTAssertFalse(sanitized.contains("$("),
                       "Should remove command substitution")
    }

    func testSanitizeDeviceName_ContainsControlCharacters_RemovesControlChars() {
        // Given
        let nameWithControlChars = "Device\u{0001}Name\u{0002}Test"

        // When
        let sanitized = InputValidator.sanitizeDeviceName(nameWithControlChars)

        // Then
        XCTAssertFalse(sanitized.contains("\u{0001}"),
                       "Should remove control characters")
        XCTAssertFalse(sanitized.contains("\u{0002}"),
                       "Should remove control characters")
    }

    func testSanitizeDeviceName_WhitespaceOnly_ReturnsUnknownDevice() {
        // Given
        let whitespace = "   \t\n   "

        // When
        let sanitized = InputValidator.sanitizeDeviceName(whitespace)

        // Then
        XCTAssertEqual(sanitized, "Unknown Device",
                       "Whitespace-only names should return 'Unknown Device'")
    }

    // MARK: - IP Address Validation Tests

    func testIsValidIPAddress_ValidIPv4_ReturnsTrue() {
        // Given
        let validIPs = [
            "192.168.1.1",
            "10.0.0.1",
            "172.16.0.1",
            "255.255.255.255",
            "0.0.0.0"
        ]

        // When/Then
        for ip in validIPs {
            XCTAssertTrue(InputValidator.isValidIPAddress(ip),
                          "\(ip) should be valid IPv4")
        }
    }

    func testIsValidIPAddress_InvalidIPv4_ReturnsFalse() {
        // Given
        let invalidIPs = [
            "256.1.1.1",      // Value too high
            "192.168.1",      // Missing octet
            "192.168.1.1.1",  // Too many octets
            "192.168.-1.1",   // Negative value
            "abc.def.ghi.jkl", // Non-numeric
            "192.168.1.1/24"  // CIDR notation not supported
        ]

        // When/Then
        for ip in invalidIPs {
            XCTAssertFalse(InputValidator.isValidIPAddress(ip),
                           "\(ip) should be invalid IPv4")
        }
    }

    func testIsValidIPAddress_ValidIPv6_ReturnsTrue() {
        // Given
        let validIPv6 = [
            "2001:0db8:85a3:0000:0000:8a2e:0370:7334",
            "fe80:0000:0000:0000:0204:61ff:fe9d:f156"
        ]

        // When/Then
        for ip in validIPv6 {
            XCTAssertTrue(InputValidator.isValidIPAddress(ip),
                          "\(ip) should be valid IPv6")
        }
    }

    func testIsValidIPAddress_EmptyString_ReturnsFalse() {
        // Given
        let emptyIP = ""

        // When
        let isValid = InputValidator.isValidIPAddress(emptyIP)

        // Then
        XCTAssertFalse(isValid, "Empty string should be invalid")
    }

    // MARK: - Port Validation Tests

    func testIsValidPort_ValidPorts_ReturnsTrue() {
        // Given
        let validPorts: [UInt16] = [1, 80, 443, 8080, 65535]

        // When/Then
        for port in validPorts {
            XCTAssertTrue(InputValidator.isValidPort(port),
                          "Port \(port) should be valid")
        }
    }

    func testIsValidPort_ZeroPort_ReturnsFalse() {
        // Given
        let zeroPort: UInt16 = 0

        // When
        let isValid = InputValidator.isValidPort(zeroPort)

        // Then
        XCTAssertFalse(isValid, "Port 0 should be invalid")
    }

    // MARK: - Host Address Sanitization Tests

    func testSanitizeHostAddress_ValidIP_ReturnsIP() {
        // Given
        let validIP = "192.168.1.100"

        // When
        let sanitized = InputValidator.sanitizeHostAddress(validIP)

        // Then
        XCTAssertEqual(sanitized, validIP, "Valid IP should be returned unchanged")
    }

    func testSanitizeHostAddress_InvalidIP_ReturnsNil() {
        // Given
        let invalidIP = "999.999.999.999"

        // When
        let sanitized = InputValidator.sanitizeHostAddress(invalidIP)

        // Then
        XCTAssertNil(sanitized, "Invalid IP should return nil")
    }

    func testSanitizeHostAddress_EmptyString_ReturnsNil() {
        // Given
        let empty = ""

        // When
        let sanitized = InputValidator.sanitizeHostAddress(empty)

        // Then
        XCTAssertNil(sanitized, "Empty string should return nil")
    }

    func testSanitizeHostAddress_TooLong_ReturnsNil() {
        // Given - String longer than 255 characters
        let tooLong = String(repeating: "1", count: 300)

        // When
        let sanitized = InputValidator.sanitizeHostAddress(tooLong)

        // Then
        XCTAssertNil(sanitized, "Too long address should return nil")
    }

    // MARK: - TXT Key Validation Tests

    func testIsValidTXTKey_ValidKeys_ReturnsTrue() {
        // Given
        let validKeys = ["sf", "ci", "md", "test_key", "key-123", "KEY"]

        // When/Then
        for key in validKeys {
            XCTAssertTrue(InputValidator.isValidTXTKey(key),
                          "\(key) should be valid TXT key")
        }
    }

    func testIsValidTXTKey_InvalidCharacters_ReturnsFalse() {
        // Given
        let invalidKeys = [
            "key.with.dots",
            "key with spaces",
            "key@email",
            "key=value",
            "key;",
            "key'quote"
        ]

        // When/Then
        for key in invalidKeys {
            XCTAssertFalse(InputValidator.isValidTXTKey(key),
                           "\(key) should be invalid TXT key")
        }
    }

    func testIsValidTXTKey_EmptyString_ReturnsFalse() {
        // Given
        let emptyKey = ""

        // When
        let isValid = InputValidator.isValidTXTKey(emptyKey)

        // Then
        XCTAssertFalse(isValid, "Empty key should be invalid")
    }

    func testIsValidTXTKey_TooLong_ReturnsFalse() {
        // Given - Key longer than maxTXTKeyLength (255)
        let longKey = String(repeating: "A", count: 300)

        // When
        let isValid = InputValidator.isValidTXTKey(longKey)

        // Then
        XCTAssertFalse(isValid, "Too long key should be invalid")
    }

    // MARK: - TXT Value Sanitization Tests

    func testSanitizeTXTValue_ValidValue_ReturnsUnchanged() {
        // Given
        let validValue = "Simple value 123"

        // When
        let sanitized = InputValidator.sanitizeTXTValue(validValue)

        // Then
        XCTAssertEqual(sanitized, validValue, "Valid value should be unchanged")
    }

    func testSanitizeTXTValue_TooLong_Truncates() {
        // Given - Value longer than maxTXTValueLength (1024)
        let longValue = String(repeating: "A", count: 1500)

        // When
        let sanitized = InputValidator.sanitizeTXTValue(longValue)

        // Then
        XCTAssertEqual(sanitized.count, InputValidator.maxTXTValueLength,
                       "Value should be truncated to max length")
    }

    func testSanitizeTXTValue_SQLInjection_RemovesPattern() {
        // Given
        let sqlInjection = "value'; DROP TABLE users; --"

        // When
        let sanitized = InputValidator.sanitizeTXTValue(sqlInjection)

        // Then
        XCTAssertFalse(sanitized.contains("'; DROP"),
                       "Should remove SQL injection pattern")
        XCTAssertFalse(sanitized.contains("--"),
                       "Should remove SQL comment marker")
    }

    func testSanitizeTXTValue_XSSAttack_RemovesScripts() {
        // Given
        let xssAttack = "<script>alert('XSS')</script>"

        // When
        let sanitized = InputValidator.sanitizeTXTValue(xssAttack)

        // Then
        XCTAssertFalse(sanitized.lowercased().contains("<script"),
                       "Should remove script tags")
    }

    func testSanitizeTXTValue_CommandInjection_RemovesCommands() {
        // Given
        let commandInjection = "value$(rm -rf /)"

        // When
        let sanitized = InputValidator.sanitizeTXTValue(commandInjection)

        // Then
        XCTAssertFalse(sanitized.contains("$("),
                       "Should remove command substitution")
    }

    func testSanitizeTXTValue_ControlCharacters_RemovesControlChars() {
        // Given
        let valueWithControl = "Value\u{0001}With\u{0002}Control"

        // When
        let sanitized = InputValidator.sanitizeTXTValue(valueWithControl)

        // Then
        XCTAssertFalse(sanitized.contains("\u{0001}"),
                       "Should remove control characters")
    }

    // MARK: - TXT Data Sanitization Tests

    func testSanitizeTXTData_ValidUTF8_ReturnsString() {
        // Given
        let validData = "Test Data".data(using: .utf8)!

        // When
        let sanitized = InputValidator.sanitizeTXTData(validData)

        // Then
        XCTAssertEqual(sanitized, "Test Data", "Valid UTF-8 should be converted to string")
    }

    func testSanitizeTXTData_TooLarge_Truncates() {
        // Given - Data larger than maxTXTDataSize (2048)
        let largeData = String(repeating: "A", count: 3000).data(using: .utf8)!

        // When
        let sanitized = InputValidator.sanitizeTXTData(largeData)

        // Then
        XCTAssertLessThanOrEqual(sanitized.count, InputValidator.maxTXTDataSize,
                                 "Should truncate to max size")
    }

    func testSanitizeTXTData_BinaryData_ReturnsPlaceholder() {
        // Given - Non-UTF8 binary data
        let binaryData = Data([0xFF, 0xFE, 0xFD, 0xFC])

        // When
        let sanitized = InputValidator.sanitizeTXTData(binaryData)

        // Then
        XCTAssertTrue(sanitized.contains("<binary:"),
                      "Binary data should be represented as placeholder")
        XCTAssertTrue(sanitized.contains("bytes>"),
                      "Binary data should include byte count")
    }

    // MARK: - HomeKit Validation Tests

    func testIsValidStatusFlag_ValidFlags_ReturnsTrue() {
        // Given
        let validFlags = ["0", "1", "2", "3", "255"]

        // When/Then
        for flag in validFlags {
            XCTAssertTrue(InputValidator.isValidStatusFlag(flag),
                          "\(flag) should be valid status flag")
        }
    }

    func testIsValidStatusFlag_InvalidFlags_ReturnsFalse() {
        // Given
        let invalidFlags = ["-1", "256", "abc", ""]

        // When/Then
        for flag in invalidFlags {
            XCTAssertFalse(InputValidator.isValidStatusFlag(flag),
                           "\(flag) should be invalid status flag")
        }
    }

    func testIsValidCategoryIdentifier_ValidCategories_ReturnsTrue() {
        // Given
        let validCategories = ["1", "5", "10", "32"]

        // When/Then
        for category in validCategories {
            XCTAssertTrue(InputValidator.isValidCategoryIdentifier(category),
                          "\(category) should be valid category identifier")
        }
    }

    func testIsValidCategoryIdentifier_InvalidCategories_ReturnsFalse() {
        // Given
        let invalidCategories = ["0", "33", "-1", "abc"]

        // When/Then
        for category in invalidCategories {
            XCTAssertFalse(InputValidator.isValidCategoryIdentifier(category),
                           "\(category) should be invalid category identifier")
        }
    }

    func testIsValidDeviceID_ValidMACAddress_ReturnsTrue() {
        // Given
        let validMACs = [
            "AA:BB:CC:DD:EE:FF",
            "00:11:22:33:44:55",
            "ab:cd:ef:12:34:56"
        ]

        // When/Then
        for mac in validMACs {
            XCTAssertTrue(InputValidator.isValidDeviceID(mac),
                          "\(mac) should be valid device ID")
        }
    }

    func testIsValidDeviceID_ValidUUID_ReturnsTrue() {
        // Given
        let validUUID = "12345678-1234-1234-1234-123456789012"

        // When
        let isValid = InputValidator.isValidDeviceID(validUUID)

        // Then
        XCTAssertTrue(isValid, "Valid UUID should be accepted as device ID")
    }

    func testIsValidDeviceID_InvalidFormat_ReturnsFalse() {
        // Given
        let invalidIDs = [
            "AABBCCDDEEFF",        // No colons
            "AA:BB:CC:DD:EE",      // Missing octet
            "invalid-id",
            "12345",
            ""
        ]

        // When/Then
        for id in invalidIDs {
            XCTAssertFalse(InputValidator.isValidDeviceID(id),
                           "\(id) should be invalid device ID")
        }
    }

    // MARK: - TXT Records Collection Validation Tests

    func testValidateTXTRecords_ValidCollection_ReturnsTrue() {
        // Given
        let validRecords = [
            "sf": "1",
            "ci": "5",
            "md": "Device Model"
        ]

        // When
        let isValid = InputValidator.validateTXTRecords(validRecords)

        // Then
        XCTAssertTrue(isValid, "Valid TXT records should pass validation")
    }

    func testValidateTXTRecords_TooManyRecords_ReturnsFalse() {
        // Given - More than maxTXTRecordsCount (50)
        var tooManyRecords: [String: String] = [:]
        for i in 0...60 {
            tooManyRecords["key\(i)"] = "value\(i)"
        }

        // When
        let isValid = InputValidator.validateTXTRecords(tooManyRecords)

        // Then
        XCTAssertFalse(isValid, "Too many TXT records should fail validation")
    }

    func testValidateTXTRecords_InvalidKey_ReturnsFalse() {
        // Given
        let recordsWithInvalidKey = [
            "valid_key": "value",
            "invalid key": "value"  // Space in key
        ]

        // When
        let isValid = InputValidator.validateTXTRecords(recordsWithInvalidKey)

        // Then
        XCTAssertFalse(isValid, "Invalid key should fail validation")
    }

    func testValidateTXTRecords_NullByte_ReturnsFalse() {
        // Given
        let recordsWithNullByte = [
            "key": "value\0withNull"
        ]

        // When
        let isValid = InputValidator.validateTXTRecords(recordsWithNullByte)

        // Then
        XCTAssertFalse(isValid, "Null byte in value should fail validation")
    }

    func testValidateTXTRecords_EmptyCollection_ReturnsTrue() {
        // Given
        let emptyRecords: [String: String] = [:]

        // When
        let isValid = InputValidator.validateTXTRecords(emptyRecords)

        // Then
        XCTAssertTrue(isValid, "Empty collection should pass validation")
    }

    // MARK: - Service Type Validation Tests

    func testIsValidServiceType_ValidTypes_ReturnsTrue() {
        // Given
        let validTypes = ["_hap._tcp", "_matterc._udp", "_matter._tcp"]

        // When/Then
        for type in validTypes {
            XCTAssertTrue(InputValidator.isValidServiceType(type),
                          "\(type) should be valid service type")
        }
    }

    func testIsValidServiceType_InvalidType_ReturnsFalse() {
        // Given
        let invalidTypes = ["_http._tcp", "_ssh._tcp", "invalid"]

        // When/Then
        for type in invalidTypes {
            XCTAssertFalse(InputValidator.isValidServiceType(type),
                           "\(type) should be invalid service type")
        }
    }

    // MARK: - Domain Validation Tests

    func testIsValidDomain_LocalDomain_ReturnsTrue() {
        // Given
        let localDomain = "local."

        // When
        let isValid = InputValidator.isValidDomain(localDomain)

        // Then
        XCTAssertTrue(isValid, "local. domain should be valid")
    }

    func testIsValidDomain_OtherDomains_ReturnsFalse() {
        // Given
        let invalidDomains = ["example.com", "google.com", "local", ""]

        // When/Then
        for domain in invalidDomains {
            XCTAssertFalse(InputValidator.isValidDomain(domain),
                           "\(domain) should be invalid domain")
        }
    }

    // MARK: - Character Extension Tests

    func testCharacterIsControlCharacter_ControlChars_ReturnsTrue() {
        // Given
        let controlChars: [Character] = ["\u{0001}", "\u{0002}", "\u{001F}"]

        // When/Then
        for char in controlChars {
            XCTAssertTrue(char.isControlCharacter,
                          "Character should be identified as control character")
        }
    }

    func testCharacterIsControlCharacter_RegularChars_ReturnsFalse() {
        // Given
        let regularChars: [Character] = ["A", "b", "1", " "]

        // When/Then
        for char in regularChars {
            XCTAssertFalse(char.isControlCharacter,
                           "Character should not be identified as control character")
        }
    }
}
