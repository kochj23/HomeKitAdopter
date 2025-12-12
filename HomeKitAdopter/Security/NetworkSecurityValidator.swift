//
//  NetworkSecurityValidator.swift
//  HomeKitAdopter - Network Security Validation
//
//  Created by Jordan Koch on 2025-11-21.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import Network

/// Network security validation for Bonjour/mDNS services
///
/// Validates network data to prevent:
/// - DNS poisoning attacks
/// - Spoofed Bonjour advertisements
/// - Man-in-the-middle attacks
/// - Rogue device impersonation
enum NetworkSecurityValidator {

    // MARK: - Service Validation

    /// Validate Bonjour service discovery result
    static func isValidService(_ result: NWBrowser.Result) -> Bool {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            LoggingManager.shared.warning("Invalid endpoint type")
            return false
        }

        // Validate domain (prevent DNS poisoning)
        guard InputValidator.isValidDomain(domain) else {
            LoggingManager.shared.warning("Non-local domain rejected: \(domain)")
            return false
        }

        // Validate service type
        guard InputValidator.isValidServiceType(type) else {
            LoggingManager.shared.warning("Invalid service type: \(type)")
            return false
        }

        // Validate name length
        guard name.count > 0 && name.count <= InputValidator.maxDeviceNameLength else {
            LoggingManager.shared.warning("Invalid service name length: \(name.count)")
            return false
        }

        return true
    }

    // MARK: - TXT Record Validation

    /// Validate HomeKit TXT records for suspicious patterns
    static func validateHomeKitTXTRecords(_ records: [String: String]) -> Bool {
        // Check collection size
        guard InputValidator.validateTXTRecords(records) else {
            return false
        }

        // Check for required HomeKit fields
        let requiredKeys = ["id", "md", "pv", "s#", "sf", "ci"]
        var foundKeys = 0

        for key in requiredKeys {
            if records.keys.contains(key) {
                foundKeys += 1
            }
        }

        // Should have at least some required fields
        if foundKeys == 0 {
            LoggingManager.shared.warning("No required HomeKit TXT fields found")
            // Don't reject - might be Matter device
        }

        // Validate specific fields if present
        if let sf = records["sf"] {
            guard InputValidator.isValidStatusFlag(sf) else {
                return false
            }
        }

        if let ci = records["ci"] {
            guard InputValidator.isValidCategoryIdentifier(ci) else {
                return false
            }
        }

        if let id = records["id"] {
            if !InputValidator.isValidDeviceID(id) {
                // Don't reject - ID format varies
                LoggingManager.shared.info("Non-standard device ID format: \(id)")
            }
        }

        // Check for anomalies
        if let pv = records["pv"], let version = Float(pv) {
            // Protocol version should be reasonable
            if version < 0 || version > 100 {
                LoggingManager.shared.warning("Suspicious protocol version: \(version)")
                return false
            }
        }

        if let configNumber = records["c#"], let num = Int(configNumber) {
            // Config number should be reasonable
            if num < 0 || num > 1000000 {
                LoggingManager.shared.warning("Suspicious config number: \(num)")
                return false
            }
        }

        return true
    }

    // MARK: - Rate Limiting

    /// Rate limiter for device discoveries
    actor RateLimiter {
        private var discoveryCount: [String: (count: Int, resetTime: Date)] = [:]
        private let maxDiscoveriesPerMinute = 100
        private let windowDuration: TimeInterval = 60.0

        func checkRateLimit(for deviceKey: String) -> Bool {
            let now = Date()

            // Get or create entry
            if var entry = discoveryCount[deviceKey] {
                // Check if window expired
                if now.timeIntervalSince(entry.resetTime) > windowDuration {
                    // Reset counter
                    entry = (count: 1, resetTime: now)
                    discoveryCount[deviceKey] = entry
                    return true
                }

                // Check limit
                if entry.count >= maxDiscoveriesPerMinute {
                    LoggingManager.shared.warning("Rate limit exceeded for device: \(deviceKey)")
                    return false
                }

                // Increment counter
                entry.count += 1
                discoveryCount[deviceKey] = entry
                return true

            } else {
                // First discovery
                discoveryCount[deviceKey] = (count: 1, resetTime: now)
                return true
            }
        }

        func reset() {
            discoveryCount.removeAll()
        }
    }

    // MARK: - Anomaly Detection

    /// Detect suspicious device behavior
    static func detectAnomalies(in device: DiscoveredDevice, history: [DiscoveredDevice]) -> [String] {
        var anomalies: [String] = []

        // Check for rapid name changes
        let sameIPDevices = history.filter { $0.host == device.host && $0.name != device.name }
        if sameIPDevices.count > 5 {
            anomalies.append("Device changed name \(sameIPDevices.count) times from same IP")
        }

        // Check for IP hopping
        let sameNameDevices = history.filter { $0.name == device.name && $0.host != device.host }
        if sameNameDevices.count > 3 {
            anomalies.append("Device appeared on \(sameNameDevices.count) different IPs")
        }

        // Check for suspicious ports
        if let port = device.port {
            let suspiciousPorts: Set<UInt16> = [22, 23, 3389, 5900] // SSH, Telnet, RDP, VNC
            if suspiciousPorts.contains(port) {
                anomalies.append("Device using suspicious port: \(port)")
            }

            // HomeKit typically uses ports 80, 443, or high ports
            if port < 1024 && port != 80 && port != 443 {
                anomalies.append("Device using low privileged port: \(port)")
            }
        }

        // Check for empty/minimal TXT records (suspicious)
        if device.serviceType == .homekit && device.txtRecords.count < 3 {
            anomalies.append("HomeKit device with unusually few TXT records")
        }

        return anomalies
    }

    // MARK: - Helper Types

    struct DiscoveredDevice {
        let name: String
        let host: String?
        let port: UInt16?
        let serviceType: ServiceType
        let txtRecords: [String: String]

        enum ServiceType {
            case homekit
            case matterCommissioning
            case matterOperational
        }
    }
}
