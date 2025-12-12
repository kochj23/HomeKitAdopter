//
//  PingMonitorManager.swift
//  HomeKitAdopter - Continuous Ping Monitor
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import Network

/// Continuous ping monitor for tracking device connectivity and latency
///
/// Monitors network connectivity to specific devices over time, tracking:
/// - Latency (response time)
/// - Packet loss
/// - Jitter (latency variation)
/// - Connection stability
///
/// # Use Cases:
/// - Monitor smart home device responsiveness
/// - Detect network issues
/// - Track Wi-Fi stability
/// - Identify intermittent connectivity problems
@MainActor
final class PingMonitorManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var pingHistory: [PingResult] = []
    @Published private(set) var statistics: PingStatistics?
    @Published var errorMessage: String?

    // MARK: - Ping Result Model

    struct PingResult: Identifiable {
        let id = UUID()
        let timestamp: Date
        let latency: TimeInterval?
        let isSuccess: Bool
        let sequenceNumber: Int

        var latencyMs: Double? {
            latency.map { $0 * 1000 }
        }
    }

    // MARK: - Statistics Model

    struct PingStatistics {
        let totalPings: Int
        let successfulPings: Int
        let failedPings: Int
        let minLatency: TimeInterval?
        let maxLatency: TimeInterval?
        let avgLatency: TimeInterval?
        let jitter: TimeInterval?

        var packetLoss: Double {
            guard totalPings > 0 else { return 0 }
            return Double(failedPings) / Double(totalPings) * 100
        }

        var successRate: Double {
            guard totalPings > 0 else { return 0 }
            return Double(successfulPings) / Double(totalPings) * 100
        }
    }

    // MARK: - Private Properties

    private var monitorTask: Task<Void, Never>?
    private let pingInterval: TimeInterval = 1.0  // Ping every second
    private let timeout: TimeInterval = 2.0
    private let maxHistorySize = 100  // Keep last 100 pings
    private var sequenceNumber = 0

    // MARK: - Initialization

    init() {
        LoggingManager.shared.info("PingMonitorManager initialized")
    }

    deinit {
        monitorTask?.cancel()
        LoggingManager.shared.info("PingMonitorManager deinitialized")
    }

    // MARK: - Public Methods

    /// Start monitoring a host
    func startMonitoring(host: String) {
        guard !isMonitoring else {
            LoggingManager.shared.warning("Monitor already running")
            return
        }

        isMonitoring = true
        pingHistory.removeAll()
        sequenceNumber = 0
        errorMessage = nil

        LoggingManager.shared.info("Starting ping monitor for \(host)")

        monitorTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                let result = await self.performPing(host: host)

                await MainActor.run {
                    self.addPingResult(result)
                }

                // Wait for next ping interval
                try? await Task.sleep(nanoseconds: UInt64(self.pingInterval * 1_000_000_000))
            }

            await MainActor.run {
                self.isMonitoring = false
            }
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        monitorTask?.cancel()
        isMonitoring = false
        LoggingManager.shared.info("Ping monitor stopped")
    }

    /// Clear history
    func clearHistory() {
        pingHistory.removeAll()
        statistics = nil
        sequenceNumber = 0
    }

    // MARK: - Private Methods

    private func performPing(host: String) async -> PingResult {
        let startTime = Date()
        sequenceNumber += 1
        let seq = sequenceNumber

        // Try TCP connection as ping (ICMP not available on tvOS)
        let parameters = NWParameters.tcp
        parameters.serviceClass = .background

        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false

            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: 80)
            )

            let connection = NWConnection(to: endpoint, using: parameters)

            // Set timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()

                let result = PingResult(
                    timestamp: Date(),
                    latency: nil,
                    isSuccess: false,
                    sequenceNumber: seq
                )
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { [weak connection] state in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }

                switch state {
                case .ready:
                    hasResumed = true
                    let latency = Date().timeIntervalSince(startTime)

                    let result = PingResult(
                        timestamp: Date(),
                        latency: latency,
                        isSuccess: true,
                        sequenceNumber: seq
                    )

                    connection?.cancel()
                    continuation.resume(returning: result)

                case .failed:
                    hasResumed = true

                    let result = PingResult(
                        timestamp: Date(),
                        latency: nil,
                        isSuccess: false,
                        sequenceNumber: seq
                    )

                    connection?.cancel()
                    continuation.resume(returning: result)

                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    private func addPingResult(_ result: PingResult) {
        pingHistory.append(result)

        // Keep only recent history
        if pingHistory.count > maxHistorySize {
            pingHistory.removeFirst()
        }

        // Update statistics
        updateStatistics()
    }

    private func updateStatistics() {
        let total = pingHistory.count
        let successful = pingHistory.filter { $0.isSuccess }.count
        let failed = total - successful

        let successfulLatencies = pingHistory.compactMap { $0.latency }

        let min = successfulLatencies.min()
        let max = successfulLatencies.max()
        let avg = successfulLatencies.isEmpty ? nil : successfulLatencies.reduce(0, +) / Double(successfulLatencies.count)

        // Calculate jitter (average deviation from mean)
        var jitter: TimeInterval? = nil
        if let avg = avg, successfulLatencies.count > 1 {
            let deviations = successfulLatencies.map { abs($0 - avg) }
            jitter = deviations.reduce(0, +) / Double(deviations.count)
        }

        statistics = PingStatistics(
            totalPings: total,
            successfulPings: successful,
            failedPings: failed,
            minLatency: min,
            maxLatency: max,
            avgLatency: avg,
            jitter: jitter
        )
    }

    // MARK: - Helper Methods

    /// Get recent latency values for charting
    func getRecentLatencies(count: Int = 50) -> [Double?] {
        return pingHistory.suffix(count).map { $0.latencyMs }
    }

    /// Get connection quality assessment
    func getConnectionQuality() -> ConnectionQuality {
        guard let stats = statistics, stats.totalPings >= 10 else {
            return .unknown
        }

        let packetLoss = stats.packetLoss
        let avgLatency = stats.avgLatency ?? 0

        if packetLoss > 10 || avgLatency > 0.5 {
            return .poor
        } else if packetLoss > 5 || avgLatency > 0.2 {
            return .fair
        } else if packetLoss > 1 || avgLatency > 0.1 {
            return .good
        } else {
            return .excellent
        }
    }

    enum ConnectionQuality: String {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case unknown = "Unknown"

        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "yellow"
            case .poor: return "red"
            case .unknown: return "gray"
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "wifi"
            case .good: return "wifi"
            case .fair: return "wifi.exclamationmark"
            case .poor: return "wifi.slash"
            case .unknown: return "questionmark.circle"
            }
        }
    }
}
