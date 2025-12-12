//
//  DeviceHistoryManager.swift
//  HomeKitAdopter - Persistent Device History Tracking
//
//  Created by Jordan Koch on 2025-11-21.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

/// Tracks discovered devices over time to detect adoption events
///
/// This manager maintains a persistent history of all discovered devices,
/// tracking when they were first seen, last seen, IP address changes,
/// and adoption status changes. This helps identify when devices
/// transition from unadopted to adopted state.
@MainActor
final class DeviceHistoryManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var deviceHistory: [String: DeviceRecord] = [:]

    // MARK: - Device Record Model

    struct DeviceRecord: Codable, Identifiable {
        let id: String
        let name: String
        let serviceType: String
        var firstSeen: Date
        var lastSeen: Date
        var ipAddresses: [String]
        var adoptionHistory: [AdoptionEvent]
        var manufacturer: String?
        var modelInfo: String?

        struct AdoptionEvent: Codable {
            let date: Date
            let wasAdopted: Bool
            let confidenceScore: Int
        }

        /// Check if device was recently adopted (within last 24 hours)
        var wasRecentlyAdopted: Bool {
            guard adoptionHistory.count >= 2 else { return false }
            let recent = adoptionHistory.suffix(2)
            guard let prev = recent.first, let current = recent.last else { return false }

            let isNowAdopted = current.wasAdopted && !prev.wasAdopted
            let withinTimeframe = Date().timeIntervalSince(current.date) < 86400 // 24 hours

            return isNowAdopted && withinTimeframe
        }

        /// Get current adoption status
        var currentAdoptionStatus: Bool {
            return adoptionHistory.last?.wasAdopted ?? false
        }

        /// Calculate how long device has been seen
        var durationSeen: TimeInterval {
            return lastSeen.timeIntervalSince(firstSeen)
        }

        /// Get IP address history as formatted string
        var ipAddressHistory: String {
            return ipAddresses.joined(separator: ", ")
        }
    }

    // MARK: - Singleton

    static let shared = DeviceHistoryManager()

    // MARK: - Secure Storage

    private let secureStorage = SecureStorageManager.shared
    private let historyKey = "deviceHistory"
    private let legacyUserDefaultsKey = "com.digitalnoise.homekitadopter.deviceHistory"

    // MARK: - Initialization

    private init() {
        // Migrate from UserDefaults to Keychain if needed
        migrateFromUserDefaults()

        // Load from secure storage
        loadFromSecureStorage()
        LoggingManager.shared.info("DeviceHistoryManager initialized with \(deviceHistory.count) records")
    }

    // MARK: - Public Methods

    /// Record a discovered device with its current adoption status
    func recordDevice(_ device: NetworkDiscoveryManager.DiscoveredDevice,
                     isAdopted: Bool,
                     confidenceScore: Int) {
        let key = makeKey(name: device.name, serviceType: device.serviceType.rawValue)

        if var existing = deviceHistory[key] {
            // Update existing record
            existing.lastSeen = Date()

            // Add new IP if not already tracked
            if let host = device.host, !existing.ipAddresses.contains(host) {
                existing.ipAddresses.append(host)
                LoggingManager.shared.info("Device \(device.name) changed IP to \(host)")
            }

            // Record adoption status if changed
            if let lastEvent = existing.adoptionHistory.last {
                if lastEvent.wasAdopted != isAdopted {
                    existing.adoptionHistory.append(DeviceRecord.AdoptionEvent(
                        date: Date(),
                        wasAdopted: isAdopted,
                        confidenceScore: confidenceScore
                    ))
                    LoggingManager.shared.info("Device \(device.name) adoption status changed: \(isAdopted)")
                }
            } else {
                existing.adoptionHistory.append(DeviceRecord.AdoptionEvent(
                    date: Date(),
                    wasAdopted: isAdopted,
                    confidenceScore: confidenceScore
                ))
            }

            // Extract manufacturer if available
            if existing.manufacturer == nil {
                existing.manufacturer = device.name.extractManufacturer() ??
                                       device.txtRecords["md"]?.extractManufacturer()
            }

            // Extract model info
            if existing.modelInfo == nil {
                existing.modelInfo = device.txtRecords["md"] ?? device.txtRecords["model"]
            }

            deviceHistory[key] = existing

        } else {
            // Create new record
            let record = DeviceRecord(
                id: key,
                name: device.name,
                serviceType: device.serviceType.rawValue,
                firstSeen: Date(),
                lastSeen: Date(),
                ipAddresses: device.host.map { [$0] } ?? [],
                adoptionHistory: [DeviceRecord.AdoptionEvent(
                    date: Date(),
                    wasAdopted: isAdopted,
                    confidenceScore: confidenceScore
                )],
                manufacturer: device.name.extractManufacturer() ??
                            device.txtRecords["md"]?.extractManufacturer(),
                modelInfo: device.txtRecords["md"] ?? device.txtRecords["model"]
            )

            deviceHistory[key] = record
            LoggingManager.shared.info("New device recorded: \(device.name)")
        }

        saveToSecureStorage()
    }

    /// Get history for a specific device
    func getHistory(for device: NetworkDiscoveryManager.DiscoveredDevice) -> DeviceRecord? {
        let key = makeKey(name: device.name, serviceType: device.serviceType.rawValue)
        return deviceHistory[key]
    }

    /// Get all recently adopted devices (within 24 hours)
    func getRecentlyAdoptedDevices() -> [DeviceRecord] {
        return deviceHistory.values.filter { $0.wasRecentlyAdopted }
    }

    /// Get all devices that have been seen but never adopted
    func getNeverAdoptedDevices() -> [DeviceRecord] {
        return deviceHistory.values.filter { record in
            record.adoptionHistory.allSatisfy { !$0.wasAdopted }
        }
    }

    /// Clear all history (for testing/reset)
    func clearHistory() {
        deviceHistory.removeAll()
        saveToSecureStorage()
        LoggingManager.shared.info("Device history cleared")
    }

    /// Clear old device history (before a specific date)
    func clearOldHistory(before date: Date) {
        let initialCount = deviceHistory.count
        deviceHistory = deviceHistory.filter { $0.value.lastSeen >= date }
        let removedCount = initialCount - deviceHistory.count

        if removedCount > 0 {
            saveToSecureStorage()
            LoggingManager.shared.info("Cleared \(removedCount) old device records")
        }
    }

    /// Export history as JSON
    func exportAsJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(deviceHistory),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return json
    }

    // MARK: - Private Methods

    private func makeKey(name: String, serviceType: String) -> String {
        return "\(name)-\(serviceType)"
    }

    /// Save device history to secure Keychain storage
    private func saveToSecureStorage() {
        do {
            try secureStorage.store(deviceHistory, forKey: historyKey)
            LoggingManager.shared.info("Device history securely saved (\(deviceHistory.count) records)")
        } catch {
            LoggingManager.shared.error("Failed to save device history: \(error.localizedDescription)")
        }
    }

    /// Load device history from secure Keychain storage
    private func loadFromSecureStorage() {
        do {
            if let history = try secureStorage.retrieve([String: DeviceRecord].self, forKey: historyKey) {
                deviceHistory = history
                LoggingManager.shared.info("Device history securely loaded (\(deviceHistory.count) records)")
            } else {
                LoggingManager.shared.info("No device history found in secure storage")
            }
        } catch {
            LoggingManager.shared.error("Failed to load device history: \(error.localizedDescription)")
        }
    }

    /// Migrate device history from UserDefaults to Keychain
    private func migrateFromUserDefaults() {
        // Check if already migrated to Keychain
        if secureStorage.exists(forKey: historyKey) {
            LoggingManager.shared.info("Device history already migrated to secure storage")
            return
        }

        // Try to load from legacy UserDefaults location
        guard let data = UserDefaults.standard.data(forKey: legacyUserDefaultsKey) else {
            LoggingManager.shared.info("No legacy device history to migrate")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            // Decode from UserDefaults
            let history = try decoder.decode([String: DeviceRecord].self, from: data)
            LoggingManager.shared.info("Found \(history.count) records in UserDefaults")

            // Store in Keychain
            try secureStorage.store(history, forKey: historyKey)
            LoggingManager.shared.info("Successfully migrated device history to secure storage")

            // Remove from UserDefaults
            UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
            UserDefaults.standard.synchronize()
            LoggingManager.shared.info("Removed legacy device history from UserDefaults")

        } catch {
            LoggingManager.shared.error("Failed to migrate device history: \(error.localizedDescription)")
        }
    }
}
