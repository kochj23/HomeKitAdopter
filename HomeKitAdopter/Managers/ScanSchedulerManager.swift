//
//  ScanSchedulerManager.swift
//  HomeKitAdopter - Automated Scanning Scheduler
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation

/// Manager for scheduling automatic network scans
///
/// Allows users to configure recurring scans and tracks scan history
@MainActor
final class ScanSchedulerManager: ObservableObject {
    static let shared = ScanSchedulerManager()

    /// Scan schedule configuration
    struct ScanSchedule: Codable {
        var isEnabled: Bool
        var interval: ScanInterval
        var lastScan: Date?
        var scanHistory: [ScanRecord]

        enum ScanInterval: String, Codable, CaseIterable {
            case every15Minutes = "Every 15 Minutes"
            case every30Minutes = "Every 30 Minutes"
            case hourly = "Hourly"
            case every6Hours = "Every 6 Hours"
            case daily = "Daily"
            case manual = "Manual Only"

            var seconds: TimeInterval {
                switch self {
                case .every15Minutes: return 15 * 60
                case .every30Minutes: return 30 * 60
                case .hourly: return 60 * 60
                case .every6Hours: return 6 * 60 * 60
                case .daily: return 24 * 60 * 60
                case .manual: return 0
                }
            }
        }

        init() {
            self.isEnabled = false
            self.interval = .manual
            self.lastScan = nil
            self.scanHistory = []
        }
    }

    /// Record of a completed scan
    struct ScanRecord: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let devicesFound: Int
        let unadoptedCount: Int
        let newDevicesSinceLastScan: Int
        let scanDuration: TimeInterval

        init(devicesFound: Int, unadoptedCount: Int, newDevicesSinceLastScan: Int, scanDuration: TimeInterval) {
            self.id = UUID()
            self.timestamp = Date()
            self.devicesFound = devicesFound
            self.unadoptedCount = unadoptedCount
            self.newDevicesSinceLastScan = newDevicesSinceLastScan
            self.scanDuration = scanDuration
        }
    }

    @Published var schedule: ScanSchedule = ScanSchedule()
    @Published private(set) var nextScheduledScan: Date?

    private var scanTimer: Timer?
    private let secureStorage = SecureStorageManager.shared
    private let storageKey = "scanSchedule"
    private weak var networkDiscovery: NetworkDiscoveryManager?

    private init() {
        loadSchedule()
        startSchedulerIfNeeded()
        LoggingManager.shared.info("ScanSchedulerManager initialized")
    }

    deinit {
        scanTimer?.invalidate()
        LoggingManager.shared.info("ScanSchedulerManager deinitialized")
    }

    /// Set the network discovery manager reference
    func setNetworkDiscoveryManager(_ manager: NetworkDiscoveryManager) {
        self.networkDiscovery = manager
    }

    /// Enable or disable scheduled scanning
    func setScheduleEnabled(_ enabled: Bool) {
        schedule.isEnabled = enabled
        saveSchedule()

        if enabled {
            startScheduler()
        } else {
            stopScheduler()
        }

        LoggingManager.shared.info("Scan schedule \(enabled ? "enabled" : "disabled")")
    }

    /// Set scan interval
    func setInterval(_ interval: ScanSchedule.ScanInterval) {
        schedule.interval = interval
        saveSchedule()

        if schedule.isEnabled {
            restartScheduler()
        }

        LoggingManager.shared.info("Scan interval set to: \(interval.rawValue)")
    }

    /// Record a completed scan
    func recordScan(devicesFound: Int, unadoptedCount: Int, newDevicesSinceLastScan: Int, duration: TimeInterval) {
        let record = ScanRecord(
            devicesFound: devicesFound,
            unadoptedCount: unadoptedCount,
            newDevicesSinceLastScan: newDevicesSinceLastScan,
            scanDuration: duration
        )

        schedule.scanHistory.append(record)
        schedule.lastScan = Date()

        // Keep only last 100 scans
        if schedule.scanHistory.count > 100 {
            schedule.scanHistory.removeFirst(schedule.scanHistory.count - 100)
        }

        saveSchedule()
        LoggingManager.shared.info("Recorded scan: \(devicesFound) devices found")
    }

    /// Get scan statistics
    func getScanStatistics() -> ScanStatistics {
        let history = schedule.scanHistory

        guard !history.isEmpty else {
            return ScanStatistics(
                totalScans: 0,
                averageDevicesFound: 0,
                averageUnadopted: 0,
                averageScanDuration: 0,
                lastScanDate: nil
            )
        }

        let totalScans = history.count
        let avgDevices = Double(history.map { $0.devicesFound }.reduce(0, +)) / Double(totalScans)
        let avgUnadopted = Double(history.map { $0.unadoptedCount }.reduce(0, +)) / Double(totalScans)
        let avgDuration = history.map { $0.scanDuration }.reduce(0, +) / Double(totalScans)

        return ScanStatistics(
            totalScans: totalScans,
            averageDevicesFound: avgDevices,
            averageUnadopted: avgUnadopted,
            averageScanDuration: avgDuration,
            lastScanDate: schedule.lastScan
        )
    }

    struct ScanStatistics {
        let totalScans: Int
        let averageDevicesFound: Double
        let averageUnadopted: Double
        let averageScanDuration: TimeInterval
        let lastScanDate: Date?
    }

    /// Clear scan history
    func clearHistory() {
        schedule.scanHistory.removeAll()
        saveSchedule()
        LoggingManager.shared.info("Cleared scan history")
    }

    // MARK: - Private Methods

    private func startSchedulerIfNeeded() {
        if schedule.isEnabled {
            startScheduler()
        }
    }

    private func startScheduler() {
        guard schedule.interval != .manual else { return }

        stopScheduler()

        calculateNextScanTime()

        scanTimer = Timer.scheduledTimer(withTimeInterval: schedule.interval.seconds, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performScheduledScan()
            }
        }

        // Trigger immediate scan if no recent scan
        if let lastScan = schedule.lastScan {
            let timeSinceLastScan = Date().timeIntervalSince(lastScan)
            if timeSinceLastScan > schedule.interval.seconds {
                Task { @MainActor [weak self] in
                    await self?.performScheduledScan()
                }
            }
        } else {
            // No previous scan, do one now
            Task { @MainActor [weak self] in
                await self?.performScheduledScan()
            }
        }

        LoggingManager.shared.info("Scan scheduler started with interval: \(schedule.interval.rawValue)")
    }

    private func stopScheduler() {
        scanTimer?.invalidate()
        scanTimer = nil
        nextScheduledScan = nil
        LoggingManager.shared.info("Scan scheduler stopped")
    }

    private func restartScheduler() {
        stopScheduler()
        startScheduler()
    }

    private func calculateNextScanTime() {
        if let lastScan = schedule.lastScan {
            nextScheduledScan = lastScan.addingTimeInterval(schedule.interval.seconds)
        } else {
            nextScheduledScan = Date()
        }
    }

    private func performScheduledScan() async {
        guard let networkDiscovery = networkDiscovery else {
            LoggingManager.shared.warning("NetworkDiscoveryManager not set, skipping scheduled scan")
            return
        }

        guard !networkDiscovery.isScanning else {
            LoggingManager.shared.warning("Scan already in progress, skipping scheduled scan")
            return
        }

        LoggingManager.shared.info("Performing scheduled scan")

        let startTime = Date()
        let previousDeviceCount = networkDiscovery.discoveredDevices.count

        networkDiscovery.startDiscovery()

        // Wait for scan to complete (30 seconds timeout)
        try? await Task.sleep(nanoseconds: 31_000_000_000)

        let duration = Date().timeIntervalSince(startTime)
        let devicesFound = networkDiscovery.discoveredDevices.count
        let unadoptedCount = networkDiscovery.getUnadoptedDevices().count
        let newDevices = max(0, devicesFound - previousDeviceCount)

        recordScan(
            devicesFound: devicesFound,
            unadoptedCount: unadoptedCount,
            newDevicesSinceLastScan: newDevices,
            duration: duration
        )

        calculateNextScanTime()
    }

    private func saveSchedule() {
        do {
            try secureStorage.store(schedule, forKey: storageKey)
            LoggingManager.shared.info("Scan schedule saved")
        } catch {
            LoggingManager.shared.error("Failed to save scan schedule: \(error.localizedDescription)")
        }
    }

    private func loadSchedule() {
        do {
            if let loadedSchedule = try secureStorage.retrieve(ScanSchedule.self, forKey: storageKey) {
                schedule = loadedSchedule
                LoggingManager.shared.info("Scan schedule loaded")
            }
        } catch {
            LoggingManager.shared.error("Failed to load scan schedule: \(error.localizedDescription)")
        }
    }
}
