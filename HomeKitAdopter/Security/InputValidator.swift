//
//  InputValidator.swift
//  HomeKitAdopter - Input Validation & Sanitization
//
//  Created by Jordan Koch on 2025-11-21.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation

/// Input validation and sanitization for all network data
///
/// This validator prevents security vulnerabilities by validating and sanitizing
/// all data received from the network (Bonjour/mDNS). It protects against:
/// - Buffer overflows (oversized data)
/// - XSS attacks (script injection)
/// - SQL injection (command injection)
/// - Control character attacks
/// - Memory exhaustion attacks
enum InputValidator {

    // MARK: - Validation Limits

    static let maxDeviceNameLength = 255
    static let maxTXTKeyLength = 255
    static let maxTXTValueLength = 1024
    static let maxTXTDataSize = 2048
    static let maxTXTRecordsCount = 50

    // MARK: - Device Name Validation

    /// Validate and sanitize device name
    static func sanitizeDeviceName(_ name: String) -> String {
        // Check length
        guard name.count > 0 else {
            LoggingManager.shared.warning("Empty device name rejected")
            return "Unknown Device"
        }

        var sanitized = name

        // Trim to max length
        if sanitized.count > maxDeviceNameLength {
            LoggingManager.shared.warning("Device name too long: \(sanitized.count) chars, truncating")
            sanitized = String(sanitized.prefix(maxDeviceNameLength))
        }

        // Remove control characters (keep whitespace, newlines)
        sanitized = sanitized.filter { !$0.isControlCharacter || $0.isWhitespace || $0.isNewline }

        // Remove potentially dangerous characters
        let dangerousPatterns = [
            "<script", "</script>", "javascript:", "onerror=", "onclick=",
            "<?php", "<?=", "<%", "%>",
            "${", "$(", "`"
        ]

        for pattern in dangerousPatterns {
            if sanitized.lowercased().contains(pattern) {
                LoggingManager.shared.warning("Dangerous pattern detected in device name: \(pattern)")
                sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
            }
        }

        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        // Final check
        if sanitized.isEmpty {
            return "Unknown Device"
        }

        return sanitized
    }

    // MARK: - Network Address Validation

    /// Validate IP address format
    static func isValidIPAddress(_ ip: String) -> Bool {
        // IPv4 pattern
        let ipv4Pattern = #"^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#

        if ip.range(of: ipv4Pattern, options: .regularExpression) != nil {
            return true
        }

        // IPv6 pattern (simplified)
        let ipv6Pattern = #"^([0-9a-fA-F]{0,4}:){7}[0-9a-fA-F]{0,4}$"#

        if ip.range(of: ipv6Pattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    /// Validate port number
    static func isValidPort(_ port: UInt16) -> Bool {
        // Port 0 is invalid, 65535 is max
        return port > 0 && port <= 65535
    }

    /// Validate and sanitize host address
    static func sanitizeHostAddress(_ host: String) -> String? {
        // Check length
        guard host.count > 0 && host.count <= 255 else {
            LoggingManager.shared.warning("Invalid host address length: \(host.count)")
            return nil
        }

        // Validate format
        guard isValidIPAddress(host) else {
            LoggingManager.shared.warning("Invalid IP address format: \(host)")
            return nil
        }

        return host
    }

    // MARK: - TXT Record Validation

    /// Validate TXT record key
    static func isValidTXTKey(_ key: String) -> Bool {
        // Check length
        guard key.count > 0 && key.count <= maxTXTKeyLength else {
            LoggingManager.shared.warning("Invalid TXT key length: \(key.count)")
            return false
        }

        // Only allow alphanumeric, underscore, hyphen
        let validPattern = #"^[a-zA-Z0-9_-]+$"#
        guard key.range(of: validPattern, options: .regularExpression) != nil else {
            LoggingManager.shared.warning("Invalid TXT key characters: \(key)")
            return false
        }

        return true
    }

    /// Sanitize TXT record value
    static func sanitizeTXTValue(_ value: String) -> String {
        var sanitized = value

        // Trim to max length
        if sanitized.count > maxTXTValueLength {
            LoggingManager.shared.warning("TXT value too long: \(sanitized.count) chars, truncating")
            sanitized = String(sanitized.prefix(maxTXTValueLength))
        }

        // Remove control characters
        sanitized = sanitized.filter { !$0.isControlCharacter || $0.isNewline }

        // Check for SQL injection patterns
        let sqlPatterns = [
            "'; DROP", "'; DELETE", "'; INSERT", "'; UPDATE",
            "' OR '1'='1", "' OR 1=1", "--", "/*", "*/"
        ]

        for pattern in sqlPatterns {
            if sanitized.contains(pattern) {
                LoggingManager.shared.warning("SQL injection pattern detected: \(pattern)")
                sanitized = sanitized.replacingOccurrences(of: pattern, with: "")
            }
        }

        // Check for XSS patterns
        let xssPatterns = [
            "<script", "</script>", "javascript:", "onerror=", "onclick=",
            "onload=", "eval(", "alert("
        ]

        for pattern in xssPatterns {
            if sanitized.lowercased().contains(pattern) {
                LoggingManager.shared.warning("XSS pattern detected: \(pattern)")
                sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
            }
        }

        // Check for command injection
        let commandPatterns = ["$(", "`", "|", ";", "&&", "||"]

        for pattern in commandPatterns {
            if sanitized.contains(pattern) {
                LoggingManager.shared.warning("Command injection pattern detected: \(pattern)")
                sanitized = sanitized.replacingOccurrences(of: pattern, with: "")
            }
        }

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sanitize binary TXT data
    static func sanitizeTXTData(_ data: Data) -> String {
        // Check size
        guard data.count <= maxTXTDataSize else {
            LoggingManager.shared.warning("TXT data too large: \(data.count) bytes, truncating")
            return sanitizeTXTData(data.prefix(maxTXTDataSize))
        }

        // Try to convert to string
        if let stringValue = String(data: data, encoding: .utf8) {
            return sanitizeTXTValue(stringValue)
        } else if let stringValue = String(data: data, encoding: .ascii) {
            return sanitizeTXTValue(stringValue)
        } else {
            // Binary data - represent safely
            return "<binary:\(data.count)bytes>"
        }
    }

    // MARK: - Service Type Validation

    /// Validate Bonjour service type
    static func isValidServiceType(_ type: String) -> Bool {
        let validTypes = ["_hap._tcp", "_matterc._udp", "_matter._tcp"]
        return validTypes.contains(type)
    }

    /// Validate Bonjour domain
    static func isValidDomain(_ domain: String) -> Bool {
        // Only allow .local domain (prevents DNS poisoning)
        return domain == "local."
    }

    // MARK: - HomeKit Specific Validation

    /// Validate HomeKit status flag
    static func isValidStatusFlag(_ sf: String) -> Bool {
        // sf should be a small integer (0-255)
        guard let intValue = Int(sf), intValue >= 0, intValue <= 255 else {
            LoggingManager.shared.warning("Invalid status flag: \(sf)")
            return false
        }
        return true
    }

    /// Validate HomeKit category identifier
    static func isValidCategoryIdentifier(_ ci: String) -> Bool {
        // ci should be 1-32
        guard let intValue = Int(ci), intValue >= 1, intValue <= 32 else {
            LoggingManager.shared.warning("Invalid category identifier: \(ci)")
            return false
        }
        return true
    }

    /// Validate HomeKit device ID
    static func isValidDeviceID(_ id: String) -> Bool {
        // Device ID should be MAC address format or UUID
        let macPattern = #"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"#
        let uuidPattern = #"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"#

        let isMac = id.range(of: macPattern, options: .regularExpression) != nil
        let isUUID = id.range(of: uuidPattern, options: .regularExpression) != nil

        if !isMac && !isUUID {
            LoggingManager.shared.warning("Invalid device ID format: \(id)")
            return false
        }

        return true
    }

    // MARK: - Collection Validation

    /// Validate TXT records collection
    static func validateTXTRecords(_ records: [String: String]) -> Bool {
        // Check count
        guard records.count <= maxTXTRecordsCount else {
            LoggingManager.shared.warning("Too many TXT records: \(records.count), max: \(maxTXTRecordsCount)")
            return false
        }

        // Validate each record
        for (key, value) in records {
            guard isValidTXTKey(key) else {
                return false
            }

            // Check for null bytes
            if key.contains("\0") || value.contains("\0") {
                LoggingManager.shared.warning("Null byte detected in TXT record")
                return false
            }
        }

        return true
    }
}

// MARK: - Character Extensions

extension Character {
    /// Check if character is a control character
    var isControlCharacter: Bool {
        return self.unicodeScalars.first?.properties.generalCategory == .control
    }
}
