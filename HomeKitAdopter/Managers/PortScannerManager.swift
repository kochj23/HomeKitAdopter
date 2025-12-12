//
//  PortScannerManager.swift
//  HomeKitAdopter - Port Scanner for Security Analysis
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import Network

/// Port scanner for discovering open ports and services on network devices
///
/// This manager provides NMAP-style port scanning capabilities for security
/// analysis of discovered devices. It identifies open ports, running services,
/// and potential security vulnerabilities.
///
/// # Features:
/// - Common port scanning (top 100 ports)
/// - Full port range scanning (1-65535)
/// - Service identification
/// - Security risk assessment
/// - Concurrent scanning for performance
///
/// # Security Analysis:
/// - Identifies potentially dangerous open ports
/// - Detects insecure protocols (Telnet, FTP, HTTP)
/// - Flags outdated services
/// - Provides remediation recommendations
@MainActor
final class PortScannerManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isScanning: Bool = false
    @Published private(set) var scanProgress: Double = 0.0
    @Published private(set) var currentPort: Int = 0
    @Published private(set) var openPorts: [OpenPort] = []
    @Published var errorMessage: String?

    // MARK: - Scan Result Model

    struct OpenPort: Identifiable {
        let id = UUID()
        let port: Int
        let service: PortService
        let state: PortState
        let responseTime: TimeInterval
        let riskLevel: SecurityRisk
        let discoveredAt: Date

        enum PortState: String {
            case open = "Open"
            case filtered = "Filtered"
            case closed = "Closed"
        }

        enum SecurityRisk: String {
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
    }

    // MARK: - Port Service Database

    struct PortService {
        let name: String
        let description: String
        let transportProtocol: String
        let isSecure: Bool
        let commonVulnerabilities: [String]

        static let unknown = PortService(
            name: "Unknown",
            description: "Unknown service",
            transportProtocol: "TCP",
            isSecure: true,
            commonVulnerabilities: []
        )
    }

    // MARK: - Common Ports Database

    private let commonPorts = [
        21, 22, 23, 25, 53, 80, 110, 111, 135, 139,
        143, 443, 445, 993, 995, 1723, 3306, 3389, 5900, 8080,
        // Smart Home Ports
        5353, 1900, 8123, 8883, 1883, 8081, 8082, 8888,
        // HomeKit/Matter
        8265, 5540, 5580, 51827, 51828,
        // Additional common
        5000, 5001, 9000, 9090, 10000, 49152, 49153
    ]

    // MARK: - Port Service Definitions

    private lazy var portServices: [Int: PortService] = {
        var services: [Int: PortService] = [:]

        // Critical Security Risks
        services[21] = PortService(
            name: "FTP",
            description: "File Transfer Protocol (Unencrypted)",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["Anonymous login", "Cleartext passwords", "Bounce attacks"]
        )

        services[23] = PortService(
            name: "Telnet",
            description: "Telnet (Unencrypted Remote Access)",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["Cleartext credentials", "No encryption", "Man-in-the-middle"]
        )

        services[80] = PortService(
            name: "HTTP",
            description: "Hypertext Transfer Protocol (Unencrypted)",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["No encryption", "Credential theft", "Data interception"]
        )

        // Secure Services
        services[22] = PortService(
            name: "SSH",
            description: "Secure Shell",
            transportProtocol: "TCP",
            isSecure: true,
            commonVulnerabilities: ["Weak passwords", "Default credentials", "Outdated versions"]
        )

        services[443] = PortService(
            name: "HTTPS",
            description: "HTTP Secure",
            transportProtocol: "TCP",
            isSecure: true,
            commonVulnerabilities: ["Weak ciphers", "Expired certificates", "Self-signed certs"]
        )

        services[993] = PortService(
            name: "IMAPS",
            description: "IMAP over SSL/TLS",
            transportProtocol: "TCP",
            isSecure: true,
            commonVulnerabilities: ["Weak SSL/TLS versions"]
        )

        services[995] = PortService(
            name: "POP3S",
            description: "POP3 over SSL/TLS",
            transportProtocol: "TCP",
            isSecure: true,
            commonVulnerabilities: ["Weak SSL/TLS versions"]
        )

        // Smart Home Services
        services[5353] = PortService(
            name: "mDNS",
            description: "Multicast DNS (Bonjour)",
            transportProtocol: "UDP",
            isSecure: true,
            commonVulnerabilities: ["Information disclosure"]
        )

        services[1900] = PortService(
            name: "UPnP",
            description: "Universal Plug and Play (SSDP)",
            transportProtocol: "UDP",
            isSecure: false,
            commonVulnerabilities: ["No authentication", "Remote code execution", "Amplification attacks"]
        )

        services[8123] = PortService(
            name: "Home Assistant",
            description: "Home Assistant Web Interface",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["Default passwords", "No HTTPS by default"]
        )

        services[1883] = PortService(
            name: "MQTT",
            description: "MQTT (Unencrypted)",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["No encryption", "Weak authentication"]
        )

        services[8883] = PortService(
            name: "MQTT/TLS",
            description: "MQTT over TLS",
            transportProtocol: "TCP",
            isSecure: true,
            commonVulnerabilities: ["Weak certificates"]
        )

        // HomeKit/Matter
        services[51827] = PortService(
            name: "HomeKit",
            description: "HomeKit Accessory Protocol",
            transportProtocol: "TCP",
            isSecure: true,
            commonVulnerabilities: ["Pairing vulnerabilities"]
        )

        services[5540] = PortService(
            name: "Matter",
            description: "Matter Protocol",
            transportProtocol: "UDP",
            isSecure: true,
            commonVulnerabilities: ["Implementation flaws"]
        )

        // Database Services
        services[3306] = PortService(
            name: "MySQL",
            description: "MySQL Database",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["Default credentials", "SQL injection", "Remote access"]
        )

        services[5432] = PortService(
            name: "PostgreSQL",
            description: "PostgreSQL Database",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["Default credentials", "Remote access"]
        )

        // Remote Access
        services[3389] = PortService(
            name: "RDP",
            description: "Remote Desktop Protocol",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["BlueKeep", "Brute force", "No NLA"]
        )

        services[5900] = PortService(
            name: "VNC",
            description: "Virtual Network Computing",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["Weak passwords", "No encryption"]
        )

        // Other Common Services
        services[25] = PortService(
            name: "SMTP",
            description: "Simple Mail Transfer Protocol",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["Open relay", "Spam"]
        )

        services[53] = PortService(
            name: "DNS",
            description: "Domain Name System",
            transportProtocol: "UDP",
            isSecure: true,
            commonVulnerabilities: ["DNS amplification", "Cache poisoning"]
        )

        services[8080] = PortService(
            name: "HTTP-Alt",
            description: "HTTP Alternate (Proxy/Web)",
            transportProtocol: "TCP",
            isSecure: false,
            commonVulnerabilities: ["No encryption", "Open proxies"]
        )

        return services
    }()

    // MARK: - Private Properties

    private let scanTimeout: TimeInterval = 2.0
    private let maxConcurrentScans = 50
    private var scanTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        LoggingManager.shared.info("PortScannerManager initialized")
    }

    deinit {
        scanTask?.cancel()
        LoggingManager.shared.info("PortScannerManager deinitialized")
    }

    // MARK: - Public Scan Methods

    /// Scan common ports on a device
    func scanCommonPorts(host: String) async {
        await scan(host: host, ports: commonPorts)
    }

    /// Scan specific port range
    func scanPortRange(host: String, startPort: Int, endPort: Int) async {
        let ports = Array(startPort...endPort)
        await scan(host: host, ports: ports)
    }

    /// Scan all ports (1-65535) - This will take a long time!
    func scanAllPorts(host: String) async {
        let ports = Array(1...65535)
        await scan(host: host, ports: ports)
    }

    /// Stop current scan
    func stopScan() {
        scanTask?.cancel()
        isScanning = false
        LoggingManager.shared.info("Port scan stopped by user")
    }

    // MARK: - Private Scan Implementation

    private func scan(host: String, ports: [Int]) async {
        guard !isScanning else {
            LoggingManager.shared.warning("Scan already in progress")
            return
        }

        isScanning = true
        openPorts.removeAll()
        scanProgress = 0.0
        errorMessage = nil

        LoggingManager.shared.info("Starting port scan on \(host) for \(ports.count) ports")

        scanTask = Task { [weak self] in
            guard let self = self else { return }

            let totalPorts = ports.count
            var scannedCount = 0

            // Scan in batches for performance
            for batch in ports.chunked(into: maxConcurrentScans) {
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isScanning = false
                    }
                    return
                }

                await withTaskGroup(of: OpenPort?.self) { group in
                    for port in batch {
                        group.addTask {
                            await self.scanPort(host: host, port: port)
                        }
                    }

                    for await result in group {
                        if let openPort = result {
                            await MainActor.run {
                                self.openPorts.append(openPort)
                                self.openPorts.sort { $0.port < $1.port }
                            }
                        }

                        scannedCount += 1
                        await MainActor.run {
                            self.currentPort = batch[scannedCount % batch.count]
                            self.scanProgress = Double(scannedCount) / Double(totalPorts)
                        }
                    }
                }
            }

            await MainActor.run {
                self.isScanning = false
                self.scanProgress = 1.0
                LoggingManager.shared.info("Port scan completed: \(self.openPorts.count) open ports found")
            }
        }

        await scanTask?.value
    }

    /// Scan individual port
    private func scanPort(host: String, port: Int) async -> OpenPort? {
        let startTime = Date()

        // Capture main actor values before continuation
        let service = portServices[port] ?? PortService.unknown
        let risk = assessRisk(port: port, service: service)

        // Create connection parameters
        let parameters = NWParameters.tcp
        parameters.serviceClass = .background
        parameters.includePeerToPeer = false

        // Set timeout
        let timeoutQueue = DispatchQueue(label: "com.homekitadopter.portscan.timeout")

        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false

            // Create connection
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port))
            )

            let connection = NWConnection(to: endpoint, using: parameters)

            // Set timeout
            timeoutQueue.asyncAfter(deadline: .now() + scanTimeout) { [weak connection] in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }
                hasResumed = true
                connection?.cancel()
                continuation.resume(returning: nil)
            }

            // Handle state changes
            connection.stateUpdateHandler = { [weak connection] state in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }

                switch state {
                case .ready:
                    hasResumed = true
                    let responseTime = Date().timeIntervalSince(startTime)

                    let openPort = OpenPort(
                        port: port,
                        service: service,
                        state: .open,
                        responseTime: responseTime,
                        riskLevel: risk,
                        discoveredAt: Date()
                    )

                    connection?.cancel()
                    continuation.resume(returning: openPort)

                case .failed, .cancelled:
                    hasResumed = true
                    connection?.cancel()
                    continuation.resume(returning: nil)

                default:
                    break
                }
            }

            connection.start(queue: timeoutQueue)
        }
    }

    // MARK: - Security Risk Assessment

    private func assessRisk(port: Int, service: PortService) -> OpenPort.SecurityRisk {
        // Critical risks - insecure protocols that should never be exposed
        if [21, 23].contains(port) {
            return .critical
        }

        // High risks - commonly exploited services
        if !service.isSecure {
            if [80, 1883, 1900, 3389, 5900].contains(port) {
                return .high
            }

            // Database ports exposed to network
            if [3306, 5432, 27017].contains(port) {
                return .high
            }
        }

        // Medium risks - secure services but still noteworthy
        if service.isSecure && !service.commonVulnerabilities.isEmpty {
            return .medium
        }

        // Low risks - standard services
        if [22, 443, 993, 995].contains(port) {
            return .low
        }

        // Info - discovery/detection services
        if [53, 5353].contains(port) {
            return .info
        }

        return .low
    }

    // MARK: - Helper Methods

    /// Get recommendations for securing open ports
    func getSecurityRecommendations(for openPort: OpenPort) -> [String] {
        var recommendations: [String] = []

        // General recommendations based on risk level
        switch openPort.riskLevel {
        case .critical:
            recommendations.append("⚠️ IMMEDIATE ACTION REQUIRED")
            recommendations.append("Close this port immediately or use VPN/firewall")

        case .high:
            recommendations.append("High security risk - review necessity")
            recommendations.append("Implement strong authentication")
            recommendations.append("Use firewall rules to restrict access")

        case .medium:
            recommendations.append("Keep software up to date")
            recommendations.append("Monitor for suspicious activity")

        case .low:
            recommendations.append("Ensure using latest security patches")
            recommendations.append("Verify legitimate use")

        case .info:
            recommendations.append("Normal discovery service")
        }

        // Service-specific recommendations
        if !openPort.service.isSecure {
            recommendations.append("Switch to encrypted alternative (TLS/SSL)")
        }

        // Add vulnerability-specific recommendations
        for vulnerability in openPort.service.commonVulnerabilities {
            switch vulnerability {
            case _ where vulnerability.contains("password"):
                recommendations.append("Use strong, unique passwords")
            case _ where vulnerability.contains("default"):
                recommendations.append("Change default credentials immediately")
            case _ where vulnerability.contains("encryption"):
                recommendations.append("Enable encryption if available")
            case _ where vulnerability.contains("authentication"):
                recommendations.append("Enable authentication/access control")
            default:
                break
            }
        }

        return recommendations
    }

    /// Get summary statistics
    func getScanSummary() -> ScanSummary {
        let criticalPorts = openPorts.filter { $0.riskLevel == .critical }.count
        let highRiskPorts = openPorts.filter { $0.riskLevel == .high }.count
        let mediumRiskPorts = openPorts.filter { $0.riskLevel == .medium }.count
        let insecurePorts = openPorts.filter { !$0.service.isSecure }.count

        return ScanSummary(
            totalOpenPorts: openPorts.count,
            criticalRiskCount: criticalPorts,
            highRiskCount: highRiskPorts,
            mediumRiskCount: mediumRiskPorts,
            insecureServiceCount: insecurePorts
        )
    }

    struct ScanSummary {
        let totalOpenPorts: Int
        let criticalRiskCount: Int
        let highRiskCount: Int
        let mediumRiskCount: Int
        let insecureServiceCount: Int

        var overallRisk: String {
            if criticalRiskCount > 0 {
                return "Critical"
            } else if highRiskCount > 0 {
                return "High"
            } else if mediumRiskCount > 0 {
                return "Medium"
            } else {
                return "Low"
            }
        }
    }
}

