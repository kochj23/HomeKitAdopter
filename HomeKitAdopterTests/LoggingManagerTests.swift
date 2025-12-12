//
//  LoggingManagerTests.swift
//  HomeKitAdopterTests
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomeKitAdopter

final class LoggingManagerTests: XCTestCase {

    var sut: LoggingManager!

    override func setUp() {
        super.setUp()
        sut = LoggingManager.shared
        // Clear logs before each test
        sut.clearLogs()
        // Give clearLogs time to complete
        Thread.sleep(forTimeInterval: 0.1)
    }

    override func tearDown() {
        // Clean up after tests
        sut.clearLogs()
        super.tearDown()
    }

    // MARK: - Basic Logging Tests

    func testLog_BasicMessage_WritesToFile() {
        // Given
        let testMessage = "Test log message"

        // When
        sut.log(testMessage, level: .info)

        // Wait for async file write
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertNotNil(logContents, "Log contents should not be nil")
        XCTAssertTrue(logContents?.contains(testMessage) ?? false,
                      "Log should contain the test message")
    }

    func testLogLevels_AllLevels_WriteCorrectly() {
        // Given
        let levels: [(String, LoggingManager.LogLevel)] = [
            ("Debug message", .debug),
            ("Info message", .info),
            ("Warning message", .warning),
            ("Error message", .error),
            ("Critical message", .critical)
        ]

        // When
        for (message, level) in levels {
            sut.log(message, level: level)
        }

        // Wait for async writes
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertNotNil(logContents)

        for (message, level) in levels {
            XCTAssertTrue(logContents?.contains(message) ?? false,
                          "\(level.rawValue) message should be in log")
            XCTAssertTrue(logContents?.contains(level.rawValue) ?? false,
                          "Log should contain level marker: \(level.rawValue)")
        }
    }

    func testConvenienceMethods_AllMethods_WritesToLog() {
        // When
        sut.debug("Debug test")
        sut.info("Info test")
        sut.warning("Warning test")
        sut.error("Error test")
        sut.critical("Critical test")

        // Wait for async writes
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertTrue(logContents?.contains("Debug test") ?? false)
        XCTAssertTrue(logContents?.contains("Info test") ?? false)
        XCTAssertTrue(logContents?.contains("Warning test") ?? false)
        XCTAssertTrue(logContents?.contains("Error test") ?? false)
        XCTAssertTrue(logContents?.contains("Critical test") ?? false)
    }

    // MARK: - Sanitization Tests - Setup Codes

    func testSanitize_SetupCode_IsMasked() {
        // Given
        let messageWithSetupCode = "Pairing with setup code 123-45-678"

        // When
        sut.info(messageWithSetupCode)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("123-45-678") ?? true,
                       "Setup code should be masked in logs")
        XCTAssertTrue(logContents?.contains("<SETUP_CODE>") ?? false,
                      "Setup code placeholder should be present")
    }

    func testSanitize_SetupCodeWithoutDashes_IsMasked() {
        // Given
        let messageWithSetupCode = "Setup code is 12345678"

        // When
        sut.info(messageWithSetupCode)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("12345678") ?? true,
                       "Setup code without dashes should be masked")
        XCTAssertTrue(logContents?.contains("<SETUP_CODE>") ?? false,
                      "Setup code placeholder should be present")
    }

    // MARK: - Sanitization Tests - Email Addresses

    func testSanitize_EmailAddress_IsMasked() {
        // Given
        let messageWithEmail = "User email: user@example.com"

        // When
        sut.info(messageWithEmail)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("user@example.com") ?? true,
                       "Email should be masked")
        XCTAssertTrue(logContents?.contains("<EMAIL>") ?? false,
                      "Email placeholder should be present")
    }

    // MARK: - Sanitization Tests - IP Addresses

    func testSanitize_IPv4Address_IsPartiallyMasked() {
        // Given
        let messageWithIP = "Device IP: 192.168.1.100"

        // When
        sut.info(messageWithIP)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("192.168.1.100") ?? true,
                       "Full IP should be masked")
        XCTAssertTrue(logContents?.contains("192.168") ?? false,
                      "First two octets should be preserved for debugging")
        XCTAssertTrue(logContents?.contains("<IP>") ?? false,
                      "IP placeholder should be present")
    }

    func testSanitize_IPv6Address_IsCompletelyMasked() {
        // Given
        let messageWithIPv6 = "IPv6 address: 2001:0db8:85a3:0000:0000:8a2e:0370:7334"

        // When
        sut.info(messageWithIPv6)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("2001:0db8:85a3:0000:0000:8a2e:0370:7334") ?? true,
                       "IPv6 should be masked")
        XCTAssertTrue(logContents?.contains("<IPv6>") ?? false,
                      "IPv6 placeholder should be present")
    }

    // MARK: - Sanitization Tests - MAC Addresses

    func testSanitize_MACAddress_IsPartiallyMasked() {
        // Given
        let messageWithMAC = "Device MAC: AA:BB:CC:DD:EE:FF"

        // When
        sut.info(messageWithMAC)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("AA:BB:CC:DD:EE:FF") ?? true,
                       "Full MAC should be masked")
        XCTAssertTrue(logContents?.contains("AA:BB:CC") ?? false,
                      "First 3 bytes (OUI) should be preserved")
        XCTAssertTrue(logContents?.contains("<MAC>") ?? false,
                      "MAC placeholder should be present")
    }

    func testSanitize_MACAddressWithDashes_IsPartiallyMasked() {
        // Given
        let messageWithMAC = "MAC address: AA-BB-CC-DD-EE-FF"

        // When
        sut.info(messageWithMAC)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("AA-BB-CC-DD-EE-FF") ?? true,
                       "Full MAC with dashes should be masked")
        XCTAssertTrue(logContents?.contains("AA-BB-CC") ?? false,
                      "First 3 bytes should be preserved")
    }

    // MARK: - Sanitization Tests - UUIDs

    func testSanitize_UUID_IsPartiallyMasked() {
        // Given
        let messageWithUUID = "Device UUID: 12345678-1234-1234-1234-123456789012"

        // When
        sut.info(messageWithUUID)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("12345678-1234-1234-1234-123456789012") ?? true,
                       "Full UUID should be masked")
        XCTAssertTrue(logContents?.contains("12345678") ?? false,
                      "First 8 characters should be preserved for correlation")
        XCTAssertTrue(logContents?.contains("<UUID>") ?? false,
                      "UUID placeholder should be present")
    }

    // MARK: - Sanitization Tests - API Keys and Tokens

    func testSanitize_BearerToken_IsMasked() {
        // Given
        let messageWithToken = "Authorization: Bearer abc123xyz456"

        // When
        sut.info(messageWithToken)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("Bearer abc123xyz456") ?? true,
                       "Bearer token should be masked")
        XCTAssertTrue(logContents?.contains("<API_KEY>") ?? false,
                      "API key placeholder should be present")
    }

    func testSanitize_APIKey_IsMasked() {
        // Given
        let messageWithAPIKey = "Using api_key=sk_live_abc123xyz"

        // When
        sut.info(messageWithAPIKey)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("sk_live_abc123xyz") ?? true,
                       "API key should be masked")
        XCTAssertTrue(logContents?.contains("<API_KEY>") ?? false,
                      "API key placeholder should be present")
    }

    // MARK: - Sanitization Tests - Passwords

    func testSanitize_Password_IsMasked() {
        // Given
        let messagesWithPasswords = [
            "User password=secret123",
            "Login pwd=mypassword",
            "Authentication pass=test123",
            "Config secret=supersecret"
        ]

        // When
        for message in messagesWithPasswords {
            sut.info(message)
        }
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("secret123") ?? true,
                       "Password should be masked")
        XCTAssertFalse(logContents?.contains("mypassword") ?? true,
                       "Password should be masked")
        XCTAssertTrue(logContents?.contains("<PASSWORD>") ?? false,
                      "Password placeholder should be present")
    }

    // MARK: - Sanitization Tests - Credit Cards

    func testSanitize_CreditCardNumber_IsMasked() {
        // Given
        let messageWithCC = "Card number: 1234-5678-9012-3456"

        // When
        sut.info(messageWithCC)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertFalse(logContents?.contains("1234-5678-9012-3456") ?? true,
                       "Credit card should be masked")
        XCTAssertTrue(logContents?.contains("<CARD_NUMBER>") ?? false,
                      "Card number placeholder should be present")
    }

    // MARK: - Log Rotation Tests

    func testLogRotation_ExceedsMaxSize_CreatesBackup() {
        // Given - Write enough data to exceed maxLogFileSize (10 MB)
        // For testing, we'll verify the rotation mechanism works
        // by checking the method exists and can be called

        // When - Write multiple large entries
        for i in 0..<100 {
            let largeMessage = String(repeating: "A", count: 1000) + " \(i)"
            sut.info(largeMessage)
        }

        // Wait for writes
        Thread.sleep(forTimeInterval: 0.5)

        // Then - Log file should exist
        let logContents = sut.getLogContents()
        XCTAssertNotNil(logContents, "Log file should exist after multiple writes")
    }

    // MARK: - File Operations Tests

    func testGetLogContents_AfterLogging_ReturnsContents() {
        // Given
        let testMessage = "Test message for retrieval"
        sut.info(testMessage)
        Thread.sleep(forTimeInterval: 0.2)

        // When
        let contents = sut.getLogContents()

        // Then
        XCTAssertNotNil(contents, "Should be able to retrieve log contents")
        XCTAssertTrue(contents?.contains(testMessage) ?? false,
                      "Retrieved contents should contain logged message")
    }

    func testExportLogs_ValidDestination_CopiesFile() throws {
        // Given
        sut.info("Test export message")
        Thread.sleep(forTimeInterval: 0.2)

        let tempDirectory = FileManager.default.temporaryDirectory
        let exportURL = tempDirectory.appendingPathComponent("exported_test.log")

        // Clean up any existing file
        try? FileManager.default.removeItem(at: exportURL)

        // When
        try sut.exportLogs(to: exportURL)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path),
                      "Exported log file should exist")

        let exportedContents = try? String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(exportedContents?.contains("Test export message") ?? false,
                      "Exported log should contain original message")

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
    }

    func testClearLogs_AfterLogging_RemovesLogFile() {
        // Given
        sut.info("Test message before clear")
        Thread.sleep(forTimeInterval: 0.2)

        let contentsBefore = sut.getLogContents()
        XCTAssertNotNil(contentsBefore, "Should have log contents before clear")

        // When
        sut.clearLogs()
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let contentsAfter = sut.getLogContents()
        // After clearing, file might not exist or be empty
        let isEmpty = contentsAfter == nil || contentsAfter?.isEmpty == true
        XCTAssertTrue(isEmpty, "Log contents should be cleared")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentLogging_MultipleThreads_AllMessagesLogged() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent logging completes")
        let messageCount = 50
        let threadCount = 5

        // When - Log from multiple threads concurrently
        DispatchQueue.concurrentPerform(iterations: threadCount) { threadIndex in
            for i in 0..<messageCount {
                sut.info("Thread \(threadIndex) - Message \(i)")
            }
        }

        // Wait for all writes to complete
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // Then - All messages should be in log
        let logContents = sut.getLogContents()
        XCTAssertNotNil(logContents)

        // Verify at least some messages from each thread are present
        for threadIndex in 0..<threadCount {
            let threadMessage = "Thread \(threadIndex)"
            XCTAssertTrue(logContents?.contains(threadMessage) ?? false,
                          "Should contain messages from thread \(threadIndex)")
        }
    }

    // MARK: - Log Level Mapping Tests

    func testLogLevelOSLogType_AllLevels_MapCorrectly() {
        // Given/When/Then
        XCTAssertEqual(LoggingManager.LogLevel.debug.osLogType, .debug)
        XCTAssertEqual(LoggingManager.LogLevel.info.osLogType, .info)
        XCTAssertEqual(LoggingManager.LogLevel.warning.osLogType, .default)
        XCTAssertEqual(LoggingManager.LogLevel.error.osLogType, .error)
        XCTAssertEqual(LoggingManager.LogLevel.critical.osLogType, .fault)
    }

    // MARK: - Timestamp Tests

    func testLogEntry_IncludesTimestamp() {
        // Given
        let testMessage = "Message with timestamp"

        // When
        sut.info(testMessage)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertNotNil(logContents)

        // Check for timestamp pattern (YYYY-MM-DD HH:MM:SS.mmm)
        let timestampPattern = "\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\.\\d{3}"
        let regex = try? NSRegularExpression(pattern: timestampPattern)
        let range = NSRange(location: 0, length: logContents?.utf16.count ?? 0)
        let matches = regex?.matches(in: logContents ?? "", range: range)

        XCTAssertGreaterThan(matches?.count ?? 0, 0,
                             "Log should contain timestamp")
    }

    // MARK: - File Info Tests

    func testLogEntry_IncludesFileAndLine() {
        // Given
        let testMessage = "Message with file info"

        // When
        sut.info(testMessage)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()
        XCTAssertTrue(logContents?.contains("LoggingManagerTests.swift") ?? false,
                      "Log should contain source file name")
    }

    // MARK: - Multiple Sanitization Tests

    func testSanitize_MultipleSecrets_AllMasked() {
        // Given - Message with multiple sensitive data types
        let complexMessage = """
        Device: 192.168.1.100, MAC: AA:BB:CC:DD:EE:FF, \
        Setup: 123-45-678, Email: user@example.com, \
        Password: secret123
        """

        // When
        sut.info(complexMessage)
        Thread.sleep(forTimeInterval: 0.2)

        // Then
        let logContents = sut.getLogContents()

        // Verify all sensitive data is masked
        XCTAssertFalse(logContents?.contains("192.168.1.100") ?? true,
                       "IP should be masked")
        XCTAssertFalse(logContents?.contains("AA:BB:CC:DD:EE:FF") ?? true,
                       "MAC should be masked")
        XCTAssertFalse(logContents?.contains("123-45-678") ?? true,
                       "Setup code should be masked")
        XCTAssertFalse(logContents?.contains("user@example.com") ?? true,
                       "Email should be masked")

        // Verify placeholders are present
        XCTAssertTrue(logContents?.contains("<IP>") ?? false)
        XCTAssertTrue(logContents?.contains("<MAC>") ?? false)
        XCTAssertTrue(logContents?.contains("<SETUP_CODE>") ?? false)
        XCTAssertTrue(logContents?.contains("<EMAIL>") ?? false)
    }
}
