//
//  NetworkDiscoveryManager.swift
//  HomeKitAdopter - tvOS Network Scanner
//
//  Created by Jordan Koch on 2025-11-21.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import Network
import Combine
import HomeKit

/// Network-based discovery of HomeKit and Matter devices using Bonjour/mDNS
///
/// Since HMAccessoryBrowser is unavailable on tvOS, this manager uses
/// Network.framework to discover devices via Bonjour service discovery.
///
/// DISCOVERED SERVICES:
/// - `_hap._tcp.` - HomeKit Accessory Protocol (HAP)
/// - `_matterc._udp.` - Matter commissioning
/// - `_matter._tcp.` - Matter operational
///
/// LIMITATIONS:
/// - Cannot determine if device is already paired (no HMAccessoryBrowser)
/// - Cannot pair devices (addAccessory unavailable on tvOS)
/// - Shows all broadcasting devices, not just unadopted ones
///
/// WORKAROUND:
/// Cross-reference discovered devices with existing HMHome accessories
/// to filter out already-adopted devices.
@MainActor
final class NetworkDiscoveryManager: ObservableObject {

    // MARK: - Discovered Device Model

    struct DiscoveredDevice: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let serviceType: ServiceType
        let host: String?
        let port: UInt16?
        let macAddress: String?
        let manufacturer: String?
        let txtRecords: [String: String]
        let discoveredAt: Date

        enum ServiceType: String, CaseIterable {
            case homekit = "_hap._tcp"
            case matterCommissioning = "_matterc._udp"
            case matterOperational = "_matter._tcp"
            case googlecast = "_googlecast._tcp"
            case googleremoter = "_googleremoter._tcp"
            case googlezone = "_googlezone._tcp"
            case nest = "_nest._tcp"
            case unifi = "_ubnt-disc._udp"
            case unifiProtect = "_nvr._tcp"
            case airplay = "_airplay._tcp"
            case raop = "_raop._tcp"

            var displayName: String {
                switch self {
                case .homekit: return "HomeKit (HAP)"
                case .matterCommissioning: return "Matter (Commissioning)"
                case .matterOperational: return "Matter (Operational)"
                case .googlecast: return "Google Chromecast"
                case .googleremoter: return "Google Remote"
                case .googlezone: return "Google Home"
                case .nest: return "Nest Device"
                case .unifi: return "Ubiquiti/UniFi"
                case .unifiProtect: return "UniFi Protect"
                case .airplay: return "AirPlay Device"
                case .raop: return "AirPlay Audio"
                }
            }

            var icon: String {
                switch self {
                case .homekit: return "house.fill"
                case .matterCommissioning: return "link.circle.fill"
                case .matterOperational: return "network"
                case .googlecast: return "tv.fill"
                case .googleremoter: return "remote.fill"
                case .googlezone: return "hifispeaker.fill"
                case .nest: return "sensor.fill"
                case .unifi: return "wifi.router.fill"
                case .unifiProtect: return "video.fill"
                case .airplay: return "airplayvideo"
                case .raop: return "airplayaudio"
                }
            }

            var category: DeviceCategory {
                switch self {
                case .homekit, .matterCommissioning, .matterOperational:
                    return .smarthome
                case .googlecast, .googleremoter, .googlezone, .nest:
                    return .google
                case .unifi, .unifiProtect:
                    return .unifi
                case .airplay, .raop:
                    return .apple
                }
            }
        }

        enum DeviceCategory: String, CaseIterable {
            case smarthome = "Smart Home"
            case google = "Google"
            case unifi = "UniFi"
            case apple = "Apple"

            var color: String {
                switch self {
                case .smarthome: return "blue"
                case .google: return "red"
                case .unifi: return "cyan"
                case .apple: return "gray"
                }
            }

            var icon: String {
                switch self {
                case .smarthome: return "house.fill"
                case .google: return "g.circle.fill"
                case .unifi: return "wifi.router.fill"
                case .apple: return "applelogo"
                }
            }
        }

        // MARK: - Device Status

        enum DeviceStatus {
            case definitelyUnadopted(reason: String)
            case likelyUnadopted(reason: String)
            case possiblyUnadopted(reason: String)
            case likelyAdopted(reason: String)
            case unknown

            var isUnadopted: Bool {
                switch self {
                case .definitelyUnadopted, .likelyUnadopted, .possiblyUnadopted:
                    return true
                case .likelyAdopted, .unknown:
                    return false
                }
            }

            var color: String {
                switch self {
                case .definitelyUnadopted: return "green"
                case .likelyUnadopted: return "green"
                case .possiblyUnadopted: return "yellow"
                case .likelyAdopted: return "red"
                case .unknown: return "gray"
                }
            }
        }

        // MARK: - Advanced Detection

        /// Get detailed device status with reason
        var detailedStatus: DeviceStatus {
            guard serviceType == .homekit else {
                if serviceType == .matterCommissioning {
                    return .definitelyUnadopted(reason: "Broadcasting Matter commissioning service")
                }
                return .unknown
            }

            // Parse HomeKit status flags (sf)
            // Bit 0: Not paired (1 = unpaired, 0 = paired)
            // Bit 1: Not configured for WiFi
            // Bit 2: Problem detected
            if let sf = txtRecords["sf"], let sfInt = Int(sf) {
                let notPaired = (sfInt & 0x01) != 0
                let notConfigured = (sfInt & 0x02) != 0
                let problemDetected = (sfInt & 0x04) != 0

                if notPaired {
                    return .definitelyUnadopted(reason: "Status flag: Not paired (sf=\(sf))")
                }
                if notConfigured {
                    return .likelyUnadopted(reason: "Status flag: Not configured (sf=\(sf))")
                }
                if problemDetected {
                    return .possiblyUnadopted(reason: "Status flag: Problem detected (sf=\(sf))")
                }
                return .likelyAdopted(reason: "Status flag: Paired and configured (sf=\(sf))")
            }

            // Check for setup hash presence
            if txtRecords.keys.contains("sh") {
                return .likelyUnadopted(reason: "Setup hash present in TXT records")
            }

            return .unknown
        }

        /// Calculate confidence score for unadopted detection (0-100)
        func calculateConfidenceScore(adoptedAccessories: [String]) -> (score: Int, reasons: [String]) {
            var score = 0
            var reasons: [String] = []

            // Check against adopted accessory names FIRST (most reliable signal)
            let normalizedName = name.normalizedForMatching()
            let bestMatch = adoptedAccessories
                .map { ($0, normalizedName.similarityScore(to: $0.normalizedForMatching())) }
                .max(by: { $0.1 < $1.1 })

            if let (matchName, similarity) = bestMatch {
                if similarity > 0.85 {
                    // Very high similarity - almost certainly adopted
                    score -= 80  // Was -40, now much stronger
                    reasons.append("Name \(Int(similarity * 100))% similar to adopted accessory '\(matchName)' - LIKELY ADOPTED")

                    // If name matches strongly, treat as adopted regardless of other signals
                    return (max(0, min(100, score)), reasons)
                } else if similarity > 0.7 {
                    // High similarity - probably adopted
                    score -= 60  // Was -20
                    reasons.append("Name \(Int(similarity * 100))% similar to adopted accessory '\(matchName)' - PROBABLY ADOPTED")

                    // Still check other signals but with reduced weight
                } else if similarity > 0.5 {
                    // Moderate similarity - might be adopted
                    score -= 30
                    reasons.append("Name \(Int(similarity * 100))% similar to adopted accessory '\(matchName)' - POSSIBLY ADOPTED")
                } else {
                    score += 25
                    reasons.append("Name doesn't closely match any adopted accessories")
                }
            } else {
                score += 25
                reasons.append("Name doesn't match any adopted accessories")
            }

            // Only check these signals if name similarity wasn't conclusive (> 85%)

            // Check TXT record status flags (strong signal for HomeKit)
            if serviceType == .homekit, let sf = txtRecords["sf"], let sfInt = Int(sf) {
                let notPaired = (sfInt & 0x01) != 0
                if notPaired {
                    score += 40  // Was 50
                    reasons.append("HomeKit status flag indicates unpaired")
                } else {
                    // Paired flag means adopted - but only if name didn't already indicate this
                    score -= 30  // Was -50
                    reasons.append("HomeKit status flag indicates paired")
                }
            }

            // Matter commissioning service (strong signal for unadopted)
            if serviceType == .matterCommissioning {
                score += 35  // Was 45
                reasons.append("Broadcasting Matter commissioning service")
            }

            // Setup hash present (moderate signal - can be present even when adopted)
            if txtRecords.keys.contains("sh") {
                score += 20  // Was 35 - reduced because setup hash alone isn't reliable
                reasons.append("Setup hash present in TXT records")
            }

            // Category identifier (provides device type context)
            if let ci = txtRecords["ci"] {
                reasons.append("Device category: \(categoryName(for: ci))")
            }

            // Feature flags (additional context)
            if let ff = txtRecords["ff"] {
                reasons.append("Feature flags: \(ff)")
            }

            // Model information (helps identify device)
            if let md = txtRecords["md"] {
                reasons.append("Model: \(md)")
                if let manufacturer = md.extractManufacturer() {
                    reasons.append("Manufacturer: \(manufacturer)")
                }
            }

            // Clamp score to 0-100
            score = max(0, min(100, score))

            return (score, reasons)
        }

        /// Get HomeKit device category name from category identifier
        private func categoryName(for ci: String) -> String {
            guard let categoryInt = Int(ci) else { return "Unknown" }

            let categories: [Int: String] = [
                1: "Other", 2: "Bridge", 3: "Fan", 4: "Garage Door Opener",
                5: "Lightbulb", 6: "Door Lock", 7: "Outlet", 8: "Switch",
                9: "Thermostat", 10: "Sensor", 11: "Security System",
                12: "Door", 13: "Window", 14: "Window Covering",
                15: "Programmable Switch", 16: "Range Extender",
                17: "IP Camera", 18: "Video Doorbell", 19: "Air Purifier",
                20: "Heater", 21: "Air Conditioner", 22: "Humidifier",
                23: "Dehumidifier", 28: "Sprinkler", 29: "Faucet",
                30: "Shower System", 31: "Television", 32: "Target Remote"
            ]

            return categories[categoryInt] ?? "Unknown (\(ci))"
        }

        /// Legacy simple detection (for backward compatibility)
        var isLikelyUnadopted: Bool {
            return detailedStatus.isUnadopted
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(serviceType)
            hasher.combine(host)
            hasher.combine(macAddress)
        }

        static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
            return lhs.name == rhs.name &&
                   lhs.serviceType == rhs.serviceType &&
                   lhs.host == rhs.host &&
                   lhs.macAddress == rhs.macAddress
        }

        /// Extract manufacturer from device name or TXT records
        private func extractManufacturer() -> String? {
            // Try device name first
            if let mfg = name.extractManufacturer() {
                return mfg
            }

            // Try model descriptor (md) from TXT records
            if let md = txtRecords["md"], let mfg = md.extractManufacturer() {
                return mfg
            }

            // Try manufacturer field from TXT records
            if let mfg = txtRecords["mfg"] {
                return mfg
            }

            if let mfg = txtRecords["manufacturer"] {
                return mfg
            }

            return nil
        }
    }

    // MARK: - Published Properties

    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var isScanning: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    /// Cached confidence scores for devices to avoid recalculation in views
    @Published private(set) var deviceConfidenceCache: [UUID: (confidence: Int, reasons: [String])] = [:]

    // MARK: - Private Properties

    private var browsers: [NWBrowser] = []
    private var discoveryTimer: Timer?
    private let discoveryTimeout: TimeInterval = 30.0
    private let maxDevices: Int = 500 // Prevent unbounded growth

    // Reference to home manager to cross-check adopted devices
    private let homeManager = HomeManagerWrapper.shared

    // Reference to device history manager
    private let historyManager = DeviceHistoryManager.shared

    // MARK: - Initialization

    init() {
        LoggingManager.shared.info("NetworkDiscoveryManager initialized")
    }

    deinit {
        // Cancel browsers synchronously
        for browser in browsers {
            browser.cancel()
        }
        discoveryTimer?.invalidate()
        LoggingManager.shared.info("NetworkDiscoveryManager deinitialized")
    }

    // MARK: - Discovery Methods

    /// Start discovering devices on the network
    ///
    /// Scans for HomeKit (HAP) and Matter devices using Bonjour/mDNS.
    /// Runs for 30 seconds by default.
    func startDiscovery() {
        guard !isScanning else {
            LoggingManager.shared.warning("Discovery already in progress")
            return
        }

        LoggingManager.shared.info("Starting network discovery for HomeKit and Matter devices")

        // Clear previous results
        discoveredDevices.removeAll()
        errorMessage = nil
        successMessage = nil
        isScanning = true

        // Start browsing for each service type
        for serviceType in DiscoveredDevice.ServiceType.allCases {
            startBrowsing(for: serviceType)
        }

        // Set timeout
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: discoveryTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.stopDiscovery()

                if self.discoveredDevices.isEmpty {
                    self.errorMessage = "No devices found on network"
                    LoggingManager.shared.warning("Discovery timeout - no devices found")
                } else {
                    let unadoptedCount = self.discoveredDevices.filter { $0.isLikelyUnadopted }.count
                    self.successMessage = "Found \(self.discoveredDevices.count) device(s), \(unadoptedCount) likely unadopted"
                    LoggingManager.shared.info("Discovery completed - found \(self.discoveredDevices.count) devices")
                }
            }
        }
    }

    /// Stop discovering devices
    func stopDiscovery() {
        guard isScanning else { return }

        LoggingManager.shared.info("Stopping network discovery")

        // Stop all browsers
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()

        discoveryTimer?.invalidate()
        discoveryTimer = nil

        isScanning = false

        LoggingManager.shared.info("Discovery stopped")
    }

    // MARK: - Private Methods

    /// Start browsing for a specific service type
    private func startBrowsing(for serviceType: DiscoveredDevice.ServiceType) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        // Create browser for this service type
        let browser = NWBrowser(for: .bonjour(type: serviceType.rawValue, domain: "local."), using: parameters)

        // Handle state changes
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch state {
                case .ready:
                    LoggingManager.shared.info("Browser ready for \(serviceType.rawValue)")
                case .failed(let error):
                    LoggingManager.shared.error("Browser failed for \(serviceType.rawValue): \(error.localizedDescription)")
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                case .cancelled:
                    LoggingManager.shared.info("Browser cancelled for \(serviceType.rawValue)")
                default:
                    break
                }
            }
        }

        // Handle discovered results
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                for change in changes {
                    switch change {
                    case .added(let result):
                        self.handleDiscoveredDevice(result, serviceType: serviceType)
                    case .removed(let result):
                        self.handleRemovedDevice(result, serviceType: serviceType)
                    default:
                        break
                    }
                }
            }
        }

        // Start browsing
        browser.start(queue: .main)
        browsers.append(browser)

        LoggingManager.shared.info("Started browsing for \(serviceType.rawValue)")
    }

    /// Handle a discovered device
    private func handleDiscoveredDevice(_ result: NWBrowser.Result, serviceType: DiscoveredDevice.ServiceType) {
        switch result.endpoint {
        case .service(let name, _, _, _):
            LoggingManager.shared.info("Discovered: \(name) [\(serviceType.rawValue)]")

            // Extract metadata
            var txtRecords: [String: String] = [:]
            if case .bonjour(let txtRecord) = result.metadata {
                txtRecords = parseTXTRecords(txtRecord)
            }

            // Try to resolve host and port
            let connection = NWConnection(to: result.endpoint, using: .tcp)

            connection.stateUpdateHandler = { [weak self, weak connection] state in
                guard let self = self, let connection = connection else { return }

                if case .ready = state {
                    // Get host and port from connection
                    if let remoteEndpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = remoteEndpoint {

                        let hostString = "\(host)"
                        let portValue = UInt16(port.rawValue)

                        Task { @MainActor [weak self] in
                            guard let self = self else { return }

                            let macAddress = self.extractMACAddress(from: txtRecords, deviceName: name)
                            let manufacturer = self.extractManufacturer(from: txtRecords, deviceName: name)

                            let device = DiscoveredDevice(
                                name: name,
                                serviceType: serviceType,
                                host: hostString,
                                port: portValue,
                                macAddress: macAddress,
                                manufacturer: manufacturer,
                                txtRecords: txtRecords,
                                discoveredAt: Date()
                            )

                            // Add device using helper method (with caching and bounds checking)
                            self.addDevice(device)
                        }
                    }
                }
                connection.cancel() // We only needed to resolve the address
            }

            connection.start(queue: .main)

            // Also add device even if resolution fails (just without host/port)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }

                let macAddress = self.extractMACAddress(from: txtRecords, deviceName: name)
                let manufacturer = self.extractManufacturer(from: txtRecords, deviceName: name)

                let device = DiscoveredDevice(
                    name: name,
                    serviceType: serviceType,
                    host: nil,
                    port: nil,
                    macAddress: macAddress,
                    manufacturer: manufacturer,
                    txtRecords: txtRecords,
                    discoveredAt: Date()
                )

                // Add device using helper method (with caching and bounds checking)
                self.addDevice(device)
            }

        default:
            break
        }
    }

    /// Handle a removed device
    private func handleRemovedDevice(_ result: NWBrowser.Result, serviceType: DiscoveredDevice.ServiceType) {
        if case .service(let name, _, _, _) = result.endpoint {
            LoggingManager.shared.info("Device disappeared: \(name)")

            discoveredDevices.removeAll { device in
                device.name == name && device.serviceType == serviceType
            }
        }
    }

    /// Parse TXT records from Bonjour metadata
    private func parseTXTRecords(_ txtRecord: NWTXTRecord) -> [String: String] {
        var records: [String: String] = [:]

        for (key, value) in txtRecord {
            let keyString = key
            switch value {
            case .string(let stringValue):
                records[keyString] = stringValue
            case .data(let dataValue):
                if let valueString = String(data: dataValue, encoding: .utf8) {
                    records[keyString] = valueString
                } else {
                    records[keyString] = "" // Data exists but not UTF-8
                }
            case .none:
                records[keyString] = "" // Empty value
            @unknown default:
                records[keyString] = "" // Unknown type
            }
        }

        return records
    }

    /// Extract MAC address from TXT records or device ID
    ///
    /// HomeKit devices often include a device ID (id) in TXT records
    /// which can be used as a MAC-like identifier. Format: XX:XX:XX:XX:XX:XX
    private func extractMACAddress(from txtRecords: [String: String], deviceName: String) -> String? {
        // Try the "id" field in TXT records (HomeKit device ID)
        if let deviceID = txtRecords["id"] {
            // HomeKit device IDs are typically in format XX:XX:XX:XX:XX:XX
            if deviceID.contains(":") && deviceID.count >= 17 {
                return deviceID.uppercased()
            }
        }

        // Try "mac" field in TXT records
        if let mac = txtRecords["mac"] {
            return formatMACAddress(mac)
        }

        // Try "hwaddr" field in TXT records
        if let hwaddr = txtRecords["hwaddr"] {
            return formatMACAddress(hwaddr)
        }

        // Try extracting from model descriptor (some devices include it)
        if let md = txtRecords["md"] {
            if let extracted = extractMACFromString(md) {
                return extracted
            }
        }

        return nil
    }

    /// Format MAC address to standard format XX:XX:XX:XX:XX:XX
    private func formatMACAddress(_ address: String) -> String {
        let cleaned = address.uppercased().replacingOccurrences(of: "[^0-9A-F]", with: "", options: .regularExpression)

        guard cleaned.count == 12 else { return address.uppercased() }

        var formatted = ""
        for (index, char) in cleaned.enumerated() {
            if index > 0 && index % 2 == 0 {
                formatted += ":"
            }
            formatted.append(char)
        }

        return formatted
    }

    /// Extract MAC address from a string using regex pattern
    private func extractMACFromString(_ string: String) -> String? {
        let pattern = "([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) else {
            return nil
        }

        let range = Range(match.range, in: string)!
        return formatMACAddress(String(string[range]))
    }

    /// Extract manufacturer from TXT records and device name
    private func extractManufacturer(from txtRecords: [String: String], deviceName: String) -> String? {
        // Try device name first
        if let mfg = deviceName.extractManufacturer() {
            return mfg
        }

        // Try model descriptor (md) from TXT records
        if let md = txtRecords["md"], let mfg = md.extractManufacturer() {
            return mfg
        }

        // Try explicit manufacturer fields
        if let mfg = txtRecords["mfg"] {
            return mfg
        }

        if let mfg = txtRecords["manufacturer"] {
            return mfg
        }

        // Try vendor name
        if let vendor = txtRecords["vendor"] {
            return vendor
        }

        return nil
    }

    // MARK: - Filtering Methods

    /// Get only unadopted devices
    func getUnadoptedDevices() -> [DiscoveredDevice] {
        return discoveredDevices.filter { device in
            // First check heuristics (TXT records)
            if device.isLikelyUnadopted {
                return true
            }

            // Cross-reference with adopted HomeKit accessories
            let adoptedNames = Set(homeManager.homes.flatMap { $0.accessories.map { $0.name } })

            // If device name doesn't match any adopted accessory, it's likely unadopted
            return !adoptedNames.contains(device.name)
        }
    }

    /// Get devices by service type
    func getDevices(ofType serviceType: DiscoveredDevice.ServiceType) -> [DiscoveredDevice] {
        return discoveredDevices.filter { $0.serviceType == serviceType }
    }

    /// Clear messages
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    // MARK: - Advanced Matching Methods

    /// Find best matching adopted accessory for a discovered device using fuzzy matching
    func getBestMatchingAccessory(for device: DiscoveredDevice) -> (accessory: HMAccessory, similarity: Double)? {
        let normalizedDeviceName = device.name.normalizedForMatching()

        let allAccessories = homeManager.homes.flatMap { $0.accessories }

        let matches = allAccessories.map { accessory in
            let normalizedAccessoryName = accessory.name.normalizedForMatching()
            let similarity = normalizedDeviceName.similarityScore(to: normalizedAccessoryName)
            return (accessory, similarity)
        }

        return matches.max(by: { $0.1 < $1.1 })
    }

    /// Get adopted accessory names for confidence calculation
    func getAdoptedAccessoryNames() -> [String] {
        let names = homeManager.homes.flatMap { $0.accessories.map { $0.name } }
        LoggingManager.shared.info("HomeKit accessories found: \(names.count) - \(names.prefix(5).joined(separator: ", "))")
        return names
    }

    /// Calculate confidence score and update device history
    func calculateConfidenceAndRecordHistory(for device: DiscoveredDevice) -> (score: Int, reasons: [String]) {
        let adoptedNames = getAdoptedAccessoryNames()
        let (score, reasons) = device.calculateConfidenceScore(adoptedAccessories: adoptedNames)

        // Record in device history
        let isAdopted = score < 30 // Below 30% confidence = likely adopted
        historyManager.recordDevice(device, isAdopted: isAdopted, confidenceScore: score)

        return (score, reasons)
    }

    /// Get devices with confidence scores
    func getDevicesWithConfidence() -> [(device: DiscoveredDevice, score: Int, reasons: [String])] {
        let adoptedNames = getAdoptedAccessoryNames()

        return discoveredDevices.map { device in
            let (score, reasons) = device.calculateConfidenceScore(adoptedAccessories: adoptedNames)
            return (device, score, reasons)
        }
    }

    /// Get unadopted devices with minimum confidence threshold
    func getUnadoptedDevices(minimumConfidence: Int = 50) -> [DiscoveredDevice] {
        let adoptedNames = getAdoptedAccessoryNames()

        return discoveredDevices.filter { device in
            // Use cached confidence if available
            if let cached = deviceConfidenceCache[device.id] {
                return cached.confidence >= minimumConfidence
            }

            // Fallback to calculation (shouldn't happen if addDevice used properly)
            let (score, _) = device.calculateConfidenceScore(adoptedAccessories: adoptedNames)
            return score >= minimumConfidence
        }
    }

    /// Get adopted devices using multi-factor matching
    /// Matches devices against HomeKit accessories using:
    /// - Device ID (MAC address)
    /// - Name similarity
    /// - Model information
    func getAdoptedDevices() -> [DiscoveredDevice] {
        let allAccessories = homeManager.homes.flatMap { $0.accessories }

        // If no HomeKit accessories, no devices can be adopted
        guard !allAccessories.isEmpty else {
            LoggingManager.shared.info("No HomeKit accessories found - all devices considered unadopted")
            return []
        }

        LoggingManager.shared.info("Matching \(discoveredDevices.count) discovered devices against \(allAccessories.count) HomeKit accessories")

        return discoveredDevices.filter { device in
            return isDeviceAdopted(device: device, accessories: allAccessories)
        }
    }

    /// Check if a discovered device matches any HomeKit accessory
    private func isDeviceAdopted(device: DiscoveredDevice, accessories: [HMAccessory]) -> Bool {
        let normalizedDeviceName = device.name.normalizedForMatching()

        for accessory in accessories {
            var matchScore = 0

            // 1. Check Device ID / MAC Address (strongest signal)
            if let deviceMAC = device.macAddress {
                let accessoryID = accessory.uniqueIdentifier.uuidString
                // HomeKit device IDs are UUIDs, but we can check if the MAC is in the identifier
                if accessoryID.contains(deviceMAC.replacingOccurrences(of: ":", with: "")) {
                    LoggingManager.shared.info("MATCH: Device '\(device.name)' matched accessory '\(accessory.name)' by MAC/ID")
                    return true
                }
            }

            // 2. Check Name Similarity (moderate-high signal)
            let normalizedAccessoryName = accessory.name.normalizedForMatching()
            let nameSimilarity = normalizedDeviceName.similarityScore(to: normalizedAccessoryName)

            if nameSimilarity > 0.85 {
                // Very high similarity - almost certainly a match
                LoggingManager.shared.info("MATCH: Device '\(device.name)' matched accessory '\(accessory.name)' by name (similarity: \(Int(nameSimilarity * 100))%)")
                return true
            } else if nameSimilarity > 0.7 {
                matchScore += 3 // High similarity contributes to match
            } else if nameSimilarity > 0.5 {
                matchScore += 1 // Moderate similarity
            }

            // 3. Check Manufacturer (weak signal, but helps)
            if let deviceManufacturer = device.manufacturer {
                let accessoryManufacturer = accessory.manufacturer ?? ""
                if !accessoryManufacturer.isEmpty {
                    let mfgSimilarity = deviceManufacturer.normalizedForMatching()
                        .similarityScore(to: accessoryManufacturer.normalizedForMatching())
                    if mfgSimilarity > 0.8 {
                        matchScore += 1
                    }
                }
            }

            // 4. Check Model (weak signal)
            if let deviceModel = device.txtRecords["md"] {
                let accessoryModel = accessory.model ?? ""
                if !accessoryModel.isEmpty {
                    let modelSimilarity = deviceModel.normalizedForMatching()
                        .similarityScore(to: accessoryModel.normalizedForMatching())
                    if modelSimilarity > 0.8 {
                        matchScore += 1
                    }
                }
            }

            // If cumulative score is high enough, consider it adopted
            if matchScore >= 3 {
                LoggingManager.shared.info("MATCH: Device '\(device.name)' matched accessory '\(accessory.name)' by combined factors (score: \(matchScore))")
                return true
            }
        }

        return false
    }

    // MARK: - Performance Optimized Helper Methods

    /// Add device with confidence caching and bounded array management
    /// - Parameter device: Device to add
    private func addDevice(_ device: DiscoveredDevice) {
        // Check if device already exists
        guard !discoveredDevices.contains(device) else {
            LoggingManager.shared.debug("Device already exists: \(device.name)")
            return
        }

        // Enforce maximum device limit with LRU eviction
        if discoveredDevices.count >= maxDevices {
            evictOldestDevice()
        }

        // Add device to array
        discoveredDevices.append(device)

        // Calculate and cache confidence score
        let adoptedNames = getAdoptedAccessoryNames()
        let (confidence, reasons) = device.calculateConfidenceScore(adoptedAccessories: adoptedNames)
        deviceConfidenceCache[device.id] = (confidence, reasons)

        // Record in history (only once, not on every calculation)
        let isAdopted = confidence < 30
        historyManager.recordDevice(device, isAdopted: isAdopted, confidenceScore: confidence)

        LoggingManager.shared.info("Added device: \(device.name) with \(confidence)% confidence")
    }

    /// Evict oldest discovered device when array is full (LRU eviction)
    private func evictOldestDevice() {
        guard let oldestIndex = discoveredDevices.indices.min(by: {
            discoveredDevices[$0].discoveredAt < discoveredDevices[$1].discoveredAt
        }) else {
            return
        }

        let removed = discoveredDevices.remove(at: oldestIndex)
        deviceConfidenceCache.removeValue(forKey: removed.id)
        LoggingManager.shared.info("Evicted oldest device (LRU): \(removed.name)")
    }

    /// Get cached confidence for a device (performance optimized)
    /// - Parameter device: Device to get confidence for
    /// - Returns: Tuple of confidence score and reasons
    func getCachedConfidence(for device: DiscoveredDevice) -> (confidence: Int, reasons: [String]) {
        if let cached = deviceConfidenceCache[device.id] {
            return cached
        }

        // Calculate if not cached (shouldn't happen)
        let adoptedNames = getAdoptedAccessoryNames()
        let (score, reasons) = device.calculateConfidenceScore(adoptedAccessories: adoptedNames)
        let result = (confidence: score, reasons: reasons)
        deviceConfidenceCache[device.id] = result
        return result
    }
}
