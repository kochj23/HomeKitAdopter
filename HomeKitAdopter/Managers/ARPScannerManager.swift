//
//  ARPScannerManager.swift
//  HomeKitAdopter - ARP Scanner for Complete Network Discovery
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import Network

/// ARP scanner for discovering ALL devices on local network
///
/// Unlike Bonjour/mDNS discovery which only finds devices broadcasting services,
/// ARP scanning discovers every device with an IP address on the local subnet,
/// including silent/hidden devices that don't advertise services.
///
/// # How It Works:
/// 1. Detect local subnet (e.g., 192.168.1.0/24)
/// 2. Ping sweep all IPs in range
/// 3. Extract MAC addresses from ARP table
/// 4. Identify vendors by OUI lookup
///
/// # Use Cases:
/// - Find silent/hidden devices
/// - Discover non-smart home devices (computers, phones)
/// - Detect rogue devices on network
/// - Complete network inventory
@MainActor
final class ARPScannerManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isScanning: Bool = false
    @Published private(set) var scanProgress: Double = 0.0
    @Published private(set) var discoveredDevices: [ARPDevice] = []
    @Published var errorMessage: String?

    // MARK: - ARP Device Model

    struct ARPDevice: Identifiable, Hashable {
        let id = UUID()
        let ipAddress: String
        let macAddress: String?
        let hostname: String?
        let vendor: String?
        let isResponding: Bool
        let responseTime: TimeInterval?
        let lastSeen: Date
        let deviceType: DeviceType

        enum DeviceType {
            case router
            case computer
            case mobile
            case iot
            case printer
            case unknown

            var icon: String {
                switch self {
                case .router: return "wifi.router"
                case .computer: return "desktopcomputer"
                case .mobile: return "iphone"
                case .iot: return "sensor"
                case .printer: return "printer"
                case .unknown: return "questionmark.circle"
                }
            }

            var displayName: String {
                switch self {
                case .router: return "Router/Gateway"
                case .computer: return "Computer"
                case .mobile: return "Mobile Device"
                case .iot: return "IoT Device"
                case .printer: return "Printer"
                case .unknown: return "Unknown"
                }
            }
        }
    }

    // MARK: - Private Properties

    private let pingTimeout: TimeInterval = 1.0
    private let maxConcurrentPings = 50
    private var scanTask: Task<Void, Never>?

    // MARK: - Vendor Database (OUI Lookup)

    private lazy var ouiDatabase: [String: String] = {
        var db: [String: String] = [:]

        // Apple
        db["00:03:93"] = "Apple"
        db["00:05:02"] = "Apple"
        db["00:0A:27"] = "Apple"
        db["00:0A:95"] = "Apple"
        db["00:0D:93"] = "Apple"
        db["00:10:FA"] = "Apple"
        db["00:11:24"] = "Apple"
        db["00:14:51"] = "Apple"
        db["00:16:CB"] = "Apple"
        db["00:17:F2"] = "Apple"
        db["00:19:E3"] = "Apple"
        db["00:1B:63"] = "Apple"
        db["00:1C:B3"] = "Apple"
        db["00:1D:4F"] = "Apple"
        db["00:1E:52"] = "Apple"
        db["00:1F:5B"] = "Apple"
        db["00:1F:F3"] = "Apple"
        db["00:21:E9"] = "Apple"
        db["00:22:41"] = "Apple"
        db["00:23:12"] = "Apple"
        db["00:23:32"] = "Apple"
        db["00:23:6C"] = "Apple"
        db["00:23:DF"] = "Apple"
        db["00:24:36"] = "Apple"
        db["00:25:00"] = "Apple"
        db["00:25:4B"] = "Apple"
        db["00:25:BC"] = "Apple"
        db["00:26:08"] = "Apple"
        db["00:26:4A"] = "Apple"
        db["00:26:B0"] = "Apple"
        db["00:26:BB"] = "Apple"

        // Google/Nest
        db["00:1A:11"] = "Google"
        db["18:B4:30"] = "Nest Labs"
        db["64:16:66"] = "Nest Labs"
        db["F8:8F:CA"] = "Google"
        db["3C:5A:B4"] = "Google"
        db["CC:C5:0A"] = "Google"

        // Amazon (Echo, FireTV)
        db["00:71:47"] = "Amazon Technologies"
        db["44:65:0D"] = "Amazon Technologies"
        db["74:C2:46"] = "Amazon Technologies"
        db["B4:7C:9C"] = "Amazon Technologies"
        db["F0:D2:F1"] = "Amazon Technologies"

        // Philips Hue
        db["00:17:88"] = "Philips"
        db["EC:B5:FA"] = "Philips"

        // Samsung SmartThings
        db["00:1D:25"] = "Samsung"
        db["28:6D:97"] = "Samsung"
        db["D8:57:EF"] = "Samsung"

        // TP-Link
        db["50:C7:BF"] = "TP-Link"
        db["A4:2B:B0"] = "TP-Link"
        db["C0:06:C3"] = "TP-Link"

        // Ubiquiti
        db["04:18:D6"] = "Ubiquiti"
        db["24:A4:3C"] = "Ubiquiti"
        db["74:83:C2"] = "Ubiquiti"
        db["B4:FB:E4"] = "Ubiquiti"

        // Sonos
        db["00:0E:58"] = "Sonos"
        db["5C:AA:FD"] = "Sonos"
        db["B8:E9:37"] = "Sonos"

        // Ring
        db["74:42:7F"] = "Ring"
        db["88:03:55"] = "Ring"

        // Belkin/Wemo
        db["14:91:82"] = "Belkin"
        db["EC:1A:59"] = "Belkin"

        // Lutron
        db["00:18:F8"] = "Lutron"

        return db
    }()

    // MARK: - Initialization

    init() {
        LoggingManager.shared.info("ARPScannerManager initialized")
    }

    deinit {
        scanTask?.cancel()
        LoggingManager.shared.info("ARPScannerManager deinitialized")
    }

    // MARK: - Public Scan Methods

    /// Scan local subnet for all devices
    func scanLocalSubnet() async {
        guard let subnet = detectLocalSubnet() else {
            await MainActor.run {
                errorMessage = "Could not detect local subnet"
            }
            return
        }

        await scan(subnet: subnet)
    }

    /// Scan specific subnet (e.g., "192.168.1.0/24")
    func scanSubnet(_ subnet: String) async {
        await scan(subnet: subnet)
    }

    /// Stop current scan
    func stopScan() {
        scanTask?.cancel()
        isScanning = false
        LoggingManager.shared.info("ARP scan stopped by user")
    }

    // MARK: - Private Scan Implementation

    private func scan(subnet: String) async {
        guard !isScanning else {
            LoggingManager.shared.warning("ARP scan already in progress")
            return
        }

        isScanning = true
        discoveredDevices.removeAll()
        scanProgress = 0.0
        errorMessage = nil

        LoggingManager.shared.info("Starting ARP scan on subnet: \(subnet)")

        // Parse subnet
        guard let ipRange = parseSubnet(subnet) else {
            await MainActor.run {
                errorMessage = "Invalid subnet format"
                isScanning = false
            }
            return
        }

        scanTask = Task { [weak self] in
            guard let self = self else { return }

            let totalIPs = ipRange.count
            var scannedCount = 0

            // Scan in batches
            for batch in ipRange.chunked(into: maxConcurrentPings) {
                guard !Task.isCancelled else {
                    await MainActor.run {
                        self.isScanning = false
                    }
                    return
                }

                await withTaskGroup(of: ARPDevice?.self) { group in
                    for ip in batch {
                        group.addTask {
                            await self.pingAndResolve(ip: ip)
                        }
                    }

                    for await device in group {
                        if let device = device {
                            await MainActor.run {
                                self.discoveredDevices.append(device)
                                self.discoveredDevices.sort { $0.ipAddress < $1.ipAddress }
                            }
                        }

                        scannedCount += 1
                        await MainActor.run {
                            self.scanProgress = Double(scannedCount) / Double(totalIPs)
                        }
                    }
                }
            }

            await MainActor.run {
                self.isScanning = false
                self.scanProgress = 1.0
                LoggingManager.shared.info("ARP scan completed: \(self.discoveredDevices.count) devices found")
            }
        }

        await scanTask?.value
    }

    /// Ping IP and resolve hostname/MAC
    private func pingAndResolve(ip: String) async -> ARPDevice? {
        let startTime = Date()

        // Try TCP connection (since ICMP not available on tvOS)
        let parameters = NWParameters.tcp
        parameters.serviceClass = .background

        // Pre-compute values outside the closure to avoid main actor calls
        let hostname = resolveHostname(ip: ip)
        let macAddress = getMACAddress(for: ip)
        let vendor = macAddress.flatMap { identifyVendor(mac: $0) }
        let deviceType = determineDeviceType(ip: ip, mac: macAddress, vendor: vendor)

        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false

            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(ip),
                port: NWEndpoint.Port(integerLiteral: 80) // Try HTTP port
            )

            let connection = NWConnection(to: endpoint, using: parameters)

            // Set timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + pingTimeout) {
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: nil)
            }

            connection.stateUpdateHandler = { [weak connection] state in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }

                switch state {
                case .ready, .preparing:
                    // Device is alive
                    hasResumed = true
                    let responseTime = Date().timeIntervalSince(startTime)

                    let device = ARPDevice(
                        ipAddress: ip,
                        macAddress: macAddress,
                        hostname: hostname,
                        vendor: vendor,
                        isResponding: true,
                        responseTime: responseTime,
                        lastSeen: Date(),
                        deviceType: deviceType
                    )

                    connection?.cancel()
                    continuation.resume(returning: device)

                case .failed, .cancelled:
                    hasResumed = true
                    connection?.cancel()
                    continuation.resume(returning: nil)

                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    // MARK: - Network Utilities

    /// Detect local subnet from device's IP
    private func detectLocalSubnet() -> String? {
        // Get local IP address
        guard let localIP = getLocalIPAddress() else {
            return nil
        }

        // Parse IP and create /24 subnet
        let components = localIP.split(separator: ".")
        guard components.count == 4 else { return nil }

        return "\(components[0]).\(components[1]).\(components[2]).0/24"
    }

    /// Get device's local IP address
    private func getLocalIPAddress() -> String? {
        var address: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" { // Wi-Fi or Ethernet
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                       &hostname, socklen_t(hostname.count),
                                       nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            address = String(cString: hostname)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }

    /// Parse subnet notation (e.g., "192.168.1.0/24")
    private func parseSubnet(_ subnet: String) -> [String]? {
        let parts = subnet.split(separator: "/")
        guard parts.count == 2,
              let mask = Int(parts[1]),
              mask >= 24, mask <= 30 else { // Support /24 to /30
            return nil
        }

        let ipParts = parts[0].split(separator: ".")
        guard ipParts.count == 4 else { return nil }

        let baseIP = "\(ipParts[0]).\(ipParts[1]).\(ipParts[2])"
        let hostCount = Int(pow(2.0, Double(32 - mask))) - 2 // Exclude network and broadcast

        var ips: [String] = []
        for i in 1...hostCount {
            ips.append("\(baseIP).\(i)")
        }

        return ips
    }

    /// Resolve hostname from IP (reverse DNS)
    private func resolveHostname(ip: String) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        inet_pton(AF_INET, ip, &addr.sin_addr)

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                getnameinfo(ptr, socklen_t(MemoryLayout<sockaddr_in>.size),
                            &hostname, socklen_t(hostname.count),
                            nil, 0, NI_NAMEREQD)
            }
        }

        if result == 0 {
            let name = String(cString: hostname)
            return name != ip ? name : nil
        }

        return nil
    }

    /// Get MAC address for IP from ARP table
    /// Note: This may not work on tvOS due to sandboxing
    private func getMACAddress(for ip: String) -> String? {
        // On iOS/tvOS, direct ARP table access is restricted
        // This would require reading /proc/net/arp which isn't available
        // Alternative: Use NWPathMonitor to get local MAC, but can't get remote MACs
        return nil
    }

    /// Identify vendor from MAC OUI
    private func identifyVendor(mac: String) -> String? {
        let oui = String(mac.prefix(8)).uppercased()
        return ouiDatabase[oui]
    }

    /// Determine device type from available information
    private func determineDeviceType(ip: String, mac: String?, vendor: String?) -> ARPDevice.DeviceType {
        // Check if it's likely the router (typically .1)
        if ip.hasSuffix(".1") {
            return .router
        }

        // Identify by vendor
        if let vendor = vendor {
            let lowerVendor = vendor.lowercased()

            if lowerVendor.contains("apple") {
                return .mobile
            }

            if lowerVendor.contains("google") || lowerVendor.contains("nest") ||
               lowerVendor.contains("amazon") || lowerVendor.contains("ring") ||
               lowerVendor.contains("philips") || lowerVendor.contains("sonos") ||
               lowerVendor.contains("samsung") || lowerVendor.contains("tp-link") {
                return .iot
            }

            if lowerVendor.contains("ubiquiti") || lowerVendor.contains("cisco") {
                return .router
            }

            if lowerVendor.contains("hp") || lowerVendor.contains("canon") ||
               lowerVendor.contains("epson") {
                return .printer
            }
        }

        return .unknown
    }

    // MARK: - Statistics

    func getDeviceTypeCount() -> [ARPDevice.DeviceType: Int] {
        var counts: [ARPDevice.DeviceType: Int] = [:]

        for device in discoveredDevices {
            counts[device.deviceType, default: 0] += 1
        }

        return counts
    }

    func getVendorCount() -> [String: Int] {
        var counts: [String: Int] = [:]

        for device in discoveredDevices {
            if let vendor = device.vendor {
                counts[vendor, default: 0] += 1
            }
        }

        return counts.sorted { $0.value > $1.value }.reduce(into: [:]) { $0[$1.key] = $1.value }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
