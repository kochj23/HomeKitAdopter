//
//  FirmwareManager.swift
//  HomeKitAdopter - Firmware Detection and Tracking
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation

/// Manager for firmware detection and version tracking
///
/// Extracts firmware versions from TXT records and tracks updates
@MainActor
final class FirmwareManager: ObservableObject {
    static let shared = FirmwareManager()

    struct FirmwareInfo: Codable, Identifiable {
        let id: UUID
        let deviceKey: String
        let version: String
        let detectedAt: Date
        let source: Source
        var isOutdated: Bool
        var latestVersion: String?
        var updateNotes: String?

        enum Source: String, Codable {
            case txtRecord = "TXT Record"
            case manual = "Manual Entry"
            case database = "Known Database"
        }

        init(deviceKey: String, version: String, source: Source) {
            self.id = UUID()
            self.deviceKey = deviceKey
            self.version = version
            self.detectedAt = Date()
            self.source = source
            self.isOutdated = false
            self.latestVersion = nil
            self.updateNotes = nil
        }
    }

    @Published private(set) var firmwareRecords: [String: FirmwareInfo] = [:]

    // Known latest firmware versions (would be updated from online database in production)
    private let latestVersions: [String: [String: String]] = [
        "Philips": ["Hue Bridge": "1.64.1964031050", "Hue Bulb": "1.104.2"],
        "Ikea": ["TRÅDFRI Gateway": "1.21.29", "TRÅDFRI Bulb": "2.3.093"],
        "Eve": ["Eve Energy": "4.1.1", "Eve Motion": "2.1.2"],
        "Nanoleaf": ["Shapes": "9.2.0", "Essentials": "4.0.4"],
        "Lifx": ["A19 Bulb": "3.90", "Beam": "3.90"],
        "Aqara": ["Hub M2": "4.0.5", "Hub M1S": "3.5.1"],
        "Meross": ["MSS110": "4.5.23", "MSL120": "4.5.18"],
        "Ecobee": ["SmartThermostat": "4.8.10.247"]
    ]

    private let secureStorage = SecureStorageManager.shared
    private let storageKey = "firmwareRecords"

    private init() {
        loadFirmwareRecords()
        LoggingManager.shared.info("FirmwareManager initialized with \(firmwareRecords.count) records")
    }

    /// Extract firmware version from device
    func extractFirmware(from device: NetworkDiscoveryManager.DiscoveredDevice) -> FirmwareInfo? {
        let deviceKey = "\(device.name)-\(device.serviceType.rawValue)"

        // Try firmware version field (fv)
        if let fv = device.txtRecords["fv"] {
            let info = FirmwareInfo(deviceKey: deviceKey, version: fv, source: .txtRecord)
            return checkForUpdates(info, device: device)
        }

        // Try version field (v)
        if let v = device.txtRecords["v"] {
            let info = FirmwareInfo(deviceKey: deviceKey, version: v, source: .txtRecord)
            return checkForUpdates(info, device: device)
        }

        // Try protocol version (pv)
        if let pv = device.txtRecords["pv"] {
            let info = FirmwareInfo(deviceKey: deviceKey, version: "Protocol \(pv)", source: .txtRecord)
            return checkForUpdates(info, device: device)
        }

        // Try model descriptor parsing
        if let md = device.txtRecords["md"] {
            if let version = extractVersionFromString(md) {
                let info = FirmwareInfo(deviceKey: deviceKey, version: version, source: .txtRecord)
                return checkForUpdates(info, device: device)
            }
        }

        return nil
    }

    /// Record firmware for device
    func recordFirmware(_ info: FirmwareInfo) {
        firmwareRecords[info.deviceKey] = info
        saveFirmwareRecords()
        LoggingManager.shared.info("Recorded firmware: \(info.version) for \(info.deviceKey)")
    }

    /// Get firmware info for device
    func getFirmware(for deviceKey: String) -> FirmwareInfo? {
        return firmwareRecords[deviceKey]
    }

    /// Get all outdated firmware
    func getOutdatedFirmware() -> [FirmwareInfo] {
        return firmwareRecords.values.filter { $0.isOutdated }
    }

    /// Check if firmware is outdated
    func checkForUpdates(_ info: FirmwareInfo, device: NetworkDiscoveryManager.DiscoveredDevice) -> FirmwareInfo {
        var updatedInfo = info

        // Check against known latest versions
        if let manufacturer = device.manufacturer,
           let manufacturerVersions = latestVersions[manufacturer] {

            // Try to find matching device type
            for (deviceType, latestVersion) in manufacturerVersions {
                if device.name.localizedCaseInsensitiveContains(deviceType) ||
                   device.txtRecords["md"]?.localizedCaseInsensitiveContains(deviceType) == true {

                    updatedInfo.latestVersion = latestVersion

                    // Compare versions
                    if compareVersions(info.version, latestVersion) == .orderedAscending {
                        updatedInfo.isOutdated = true
                        updatedInfo.updateNotes = "Update available: \(latestVersion)"
                    }
                    break
                }
            }
        }

        return updatedInfo
    }

    /// Get firmware statistics
    func getStatistics() -> FirmwareStatistics {
        let total = firmwareRecords.count
        let outdated = firmwareRecords.values.filter { $0.isOutdated }.count
        let upToDate = total - outdated

        return FirmwareStatistics(
            totalDevices: total,
            outdatedCount: outdated,
            upToDateCount: upToDate,
            unknownCount: 0
        )
    }

    struct FirmwareStatistics {
        let totalDevices: Int
        let outdatedCount: Int
        let upToDateCount: Int
        let unknownCount: Int

        var outdatedPercentage: Double {
            guard totalDevices > 0 else { return 0 }
            return Double(outdatedCount) / Double(totalDevices) * 100
        }
    }

    /// Clear all firmware records
    func clearRecords() {
        firmwareRecords.removeAll()
        saveFirmwareRecords()
        LoggingManager.shared.info("Cleared all firmware records")
    }

    // MARK: - Private Methods

    private func extractVersionFromString(_ string: String) -> String? {
        // Try to extract version number like "v1.2.3" or "1.2.3"
        let pattern = #"v?(\d+\.\d+(?:\.\d+)*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range(at: 1), in: string) else {
            return nil
        }

        return String(string[range])
    }

    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1Components = version1.components(separatedBy: ".").compactMap { Int($0) }
        let v2Components = version2.components(separatedBy: ".").compactMap { Int($0) }

        let maxLength = max(v1Components.count, v2Components.count)

        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0

            if v1 < v2 { return .orderedAscending }
            if v1 > v2 { return .orderedDescending }
        }

        return .orderedSame
    }

    private func saveFirmwareRecords() {
        do {
            try secureStorage.store(firmwareRecords, forKey: storageKey)
            LoggingManager.shared.info("Firmware records saved")
        } catch {
            LoggingManager.shared.error("Failed to save firmware records: \(error.localizedDescription)")
        }
    }

    private func loadFirmwareRecords() {
        do {
            if let records = try secureStorage.retrieve([String: FirmwareInfo].self, forKey: storageKey) {
                firmwareRecords = records
                LoggingManager.shared.info("Firmware records loaded")
            }
        } catch {
            LoggingManager.shared.error("Failed to load firmware records: \(error.localizedDescription)")
        }
    }
}
