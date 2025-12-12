//
//  SecurityAuditManager.swift
//  HomeKitAdopter - Security Audit Features
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation

/// Manager for security auditing of discovered devices
///
/// Checks for known vulnerabilities, weak configurations, and security issues
@MainActor
final class SecurityAuditManager: ObservableObject {
    static let shared = SecurityAuditManager()

    struct SecurityIssue: Identifiable {
        let id = UUID()
        let deviceKey: String
        let severity: Severity
        let category: Category
        let title: String
        let description: String
        let recommendation: String
        let cveID: String?  // Common Vulnerabilities and Exposures ID

        enum Severity: String, CaseIterable {
            case critical = "Critical"
            case high = "High"
            case medium = "Medium"
            case low = "Low"
            case info = "Info"

            var color: String {
                switch self {
                case .critical: return "red"
                case .high: return "orange"
                case .medium: return "yellow"
                case .low: return "blue"
                case .info: return "gray"
                }
            }
        }

        enum Category: String, CaseIterable {
            case encryption = "Encryption"
            case authentication = "Authentication"
            case firmware = "Firmware"
            case network = "Network"
            case privacy = "Privacy"
            case configuration = "Configuration"
        }
    }

    struct SecurityReport {
        let deviceKey: String
        let deviceName: String
        let issues: [SecurityIssue]
        let overallRisk: RiskLevel
        let generatedAt: Date

        enum RiskLevel: String {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"

            var color: String {
                switch self {
                case .low: return "green"
                case .medium: return "yellow"
                case .high: return "orange"
                case .critical: return "red"
                }
            }
        }

        var criticalCount: Int { issues.filter { $0.severity == .critical }.count }
        var highCount: Int { issues.filter { $0.severity == .high }.count }
        var mediumCount: Int { issues.filter { $0.severity == .medium }.count }
        var lowCount: Int { issues.filter { $0.severity == .low }.count }
    }

    @Published private(set) var auditReports: [String: SecurityReport] = [:]

    // Known vulnerabilities database (would be updated from CVE database in production)
    private let knownVulnerabilities: [String: [(version: String, cve: String, severity: SecurityIssue.Severity, description: String)]] = [
        "Philips": [
            (version: "1.50", cve: "CVE-2020-6007", severity: .high, description: "Hue Bridge authentication bypass vulnerability")
        ],
        "Tp-Link": [
            (version: "1.0.0", cve: "CVE-2021-4043", severity: .critical, description: "Remote code execution in older Kasa devices")
        ]
    ]

    private init() {
        LoggingManager.shared.info("SecurityAuditManager initialized")
    }

    /// Perform security audit on device
    func auditDevice(_ device: NetworkDiscoveryManager.DiscoveredDevice) -> SecurityReport {
        let deviceKey = "\(device.name)-\(device.serviceType.rawValue)"
        var issues: [SecurityIssue] = []

        // Check encryption support
        issues.append(contentsOf: checkEncryption(device, deviceKey: deviceKey))

        // Check authentication
        issues.append(contentsOf: checkAuthentication(device, deviceKey: deviceKey))

        // Check for known vulnerabilities
        issues.append(contentsOf: checkKnownVulnerabilities(device, deviceKey: deviceKey))

        // Check network security
        issues.append(contentsOf: checkNetworkSecurity(device, deviceKey: deviceKey))

        // Check privacy concerns
        issues.append(contentsOf: checkPrivacy(device, deviceKey: deviceKey))

        // Check configuration
        issues.append(contentsOf: checkConfiguration(device, deviceKey: deviceKey))

        // Determine overall risk level
        let riskLevel = calculateRiskLevel(issues: issues)

        let report = SecurityReport(
            deviceKey: deviceKey,
            deviceName: device.name,
            issues: issues,
            overallRisk: riskLevel,
            generatedAt: Date()
        )

        auditReports[deviceKey] = report
        LoggingManager.shared.info("Security audit completed for \(device.name): \(issues.count) issues found")

        return report
    }

    /// Get audit report for device
    func getReport(for deviceKey: String) -> SecurityReport? {
        return auditReports[deviceKey]
    }

    /// Get all devices with critical issues
    func getCriticalDevices() -> [SecurityReport] {
        return auditReports.values.filter { $0.overallRisk == .critical || $0.criticalCount > 0 }
    }

    /// Get security statistics
    func getStatistics() -> SecurityStatistics {
        let total = auditReports.count
        let critical = auditReports.values.filter { $0.overallRisk == .critical }.count
        let high = auditReports.values.filter { $0.overallRisk == .high }.count
        let medium = auditReports.values.filter { $0.overallRisk == .medium }.count
        let low = auditReports.values.filter { $0.overallRisk == .low }.count

        let totalIssues = auditReports.values.flatMap { $0.issues }.count

        return SecurityStatistics(
            totalDevices: total,
            criticalRisk: critical,
            highRisk: high,
            mediumRisk: medium,
            lowRisk: low,
            totalIssues: totalIssues
        )
    }

    struct SecurityStatistics {
        let totalDevices: Int
        let criticalRisk: Int
        let highRisk: Int
        let mediumRisk: Int
        let lowRisk: Int
        let totalIssues: Int
    }

    // MARK: - Security Checks

    private func checkEncryption(_ device: NetworkDiscoveryManager.DiscoveredDevice, deviceKey: String) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []

        // Check if device supports encryption (HomeKit should always have this)
        if device.serviceType == .homekit {
            // Check for protocol version - older versions may have weaker encryption
            if let pv = device.txtRecords["pv"], let protocolVersion = Double(pv) {
                if protocolVersion < 1.1 {
                    issues.append(SecurityIssue(
                        deviceKey: deviceKey,
                        severity: .medium,
                        category: .encryption,
                        title: "Outdated Protocol Version",
                        description: "Device uses HomeKit protocol version \(pv), which may have weaker encryption.",
                        recommendation: "Update device firmware to support latest HomeKit protocol (1.1+)",
                        cveID: nil
                    ))
                }
            }
        }

        // Check Matter encryption
        if device.serviceType == .matterCommissioning {
            // Matter devices should always use strong encryption
            issues.append(SecurityIssue(
                deviceKey: deviceKey,
                severity: .info,
                category: .encryption,
                title: "Matter Encryption",
                description: "Matter devices use strong AES-128-CCM encryption by default.",
                recommendation: "No action needed",
                cveID: nil
            ))
        }

        return issues
    }

    private func checkAuthentication(_ device: NetworkDiscoveryManager.DiscoveredDevice, deviceKey: String) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []

        // Check if setup hash is present (indicates device is not yet paired)
        if let _ = device.txtRecords["sh"] {
            issues.append(SecurityIssue(
                deviceKey: deviceKey,
                severity: .high,
                category: .authentication,
                title: "Unauthenticated Device",
                description: "Device is broadcasting setup information and is not yet authenticated to HomeKit.",
                recommendation: "Pair device immediately to secure it. Unauthenticated devices can be a security risk.",
                cveID: nil
            ))
        }

        return issues
    }

    private func checkKnownVulnerabilities(_ device: NetworkDiscoveryManager.DiscoveredDevice, deviceKey: String) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []

        guard let manufacturer = device.manufacturer else { return issues }

        // Check against known vulnerabilities database
        if let vulns = knownVulnerabilities[manufacturer] {
            // Get device firmware version
            if let firmwareInfo = FirmwareManager.shared.extractFirmware(from: device) {
                for vuln in vulns {
                    // Check if device version matches vulnerable version
                    if firmwareInfo.version.contains(vuln.version) {
                        issues.append(SecurityIssue(
                            deviceKey: deviceKey,
                            severity: vuln.severity,
                            category: .firmware,
                            title: "Known Vulnerability: \(vuln.cve)",
                            description: vuln.description,
                            recommendation: "Update device firmware immediately to patch this vulnerability.",
                            cveID: vuln.cve
                        ))
                    }
                }
            }
        }

        return issues
    }

    private func checkNetworkSecurity(_ device: NetworkDiscoveryManager.DiscoveredDevice, deviceKey: String) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []

        // Check if device is on expected network
        if let host = device.host {
            let components = host.components(separatedBy: ".")
            if components.count == 4 {
                // Check for public IP ranges (should be on private network)
                if let firstOctet = Int(components[0]) {
                    let isPrivate = firstOctet == 10 ||
                                  (firstOctet == 172 && (16...31).contains(Int(components[1]) ?? 0)) ||
                                  (firstOctet == 192 && components[1] == "168")

                    if !isPrivate {
                        issues.append(SecurityIssue(
                            deviceKey: deviceKey,
                            severity: .critical,
                            category: .network,
                            title: "Device on Public Network",
                            description: "Device appears to be on a public IP address range, which is a serious security risk.",
                            recommendation: "Ensure device is on a private network (10.x.x.x, 172.16-31.x.x, or 192.168.x.x)",
                            cveID: nil
                        ))
                    }
                }
            }
        }

        return issues
    }

    private func checkPrivacy(_ device: NetworkDiscoveryManager.DiscoveredDevice, deviceKey: String) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []

        // Check if device exposes too much information in TXT records
        let sensitiveKeys = ["id", "mac", "hwaddr", "serial"]
        let exposedKeys = device.txtRecords.keys.filter { sensitiveKeys.contains($0.lowercased()) }

        if !exposedKeys.isEmpty {
            issues.append(SecurityIssue(
                deviceKey: deviceKey,
                severity: .low,
                category: .privacy,
                title: "Device Information Exposure",
                description: "Device broadcasts sensitive information: \(exposedKeys.joined(separator: ", "))",
                recommendation: "This is normal for HomeKit devices but be aware of privacy implications.",
                cveID: nil
            ))
        }

        return issues
    }

    private func checkConfiguration(_ device: NetworkDiscoveryManager.DiscoveredDevice, deviceKey: String) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []

        // Check for configuration flags that might indicate weak security
        if let ci = device.txtRecords["ci"], ci == "1" {
            // Category 1 is "Other" - might indicate generic/weak implementation
            issues.append(SecurityIssue(
                deviceKey: deviceKey,
                severity: .info,
                category: .configuration,
                title: "Generic Device Category",
                description: "Device uses generic category identifier, which may indicate non-certified implementation.",
                recommendation: "Verify device is officially HomeKit certified.",
                cveID: nil
            ))
        }

        return issues
    }

    private func calculateRiskLevel(issues: [SecurityIssue]) -> SecurityReport.RiskLevel {
        if issues.contains(where: { $0.severity == .critical }) {
            return .critical
        }
        if issues.filter({ $0.severity == .high }).count >= 2 {
            return .high
        }
        if issues.contains(where: { $0.severity == .high }) {
            return .medium
        }
        if issues.contains(where: { $0.severity == .medium }) {
            return .medium
        }
        return .low
    }
}
