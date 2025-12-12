//
//  PingMonitorView.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Continuous ping monitor interface for tracking device connectivity
struct PingMonitorView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager
    @StateObject private var pingMonitor = PingMonitorManager()
    @State private var selectedDevice: NetworkDiscoveryManager.DiscoveredDevice?
    @State private var customHost: String = ""
    @State private var monitorMode: MonitorMode = .device

    enum MonitorMode {
        case device   // Monitor discovered device
        case custom   // Monitor custom host/IP
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 40))
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ping Monitor")
                                .font(.title)
                                .bold()

                            Text("Monitor connectivity & latency")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Continuous monitoring with packet loss and latency tracking")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 5)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)

                // Monitor Mode Selection
                VStack(alignment: .leading, spacing: 15) {
                    Text("Monitor Target")
                        .font(.headline)

                    HStack(spacing: 15) {
                        Button(action: { monitorMode = .device }) {
                            VStack(spacing: 8) {
                                Image(systemName: monitorMode == .device ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(monitorMode == .device ? .green : .gray)

                                Text("Discovered Device")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(monitorMode == .device ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }

                        Button(action: { monitorMode = .custom }) {
                            VStack(spacing: 8) {
                                Image(systemName: monitorMode == .custom ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(monitorMode == .custom ? .green : .gray)

                                Text("Custom Host")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(monitorMode == .custom ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 40)

                // Device/Host Selection
                if monitorMode == .device {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select Device")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if networkDiscovery.discoveredDevices.isEmpty {
                            Text("No devices discovered. Run network discovery first.")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(10)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(networkDiscovery.discoveredDevices) { device in
                                        Button(action: { selectedDevice = device }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(device.name)
                                                    .font(.body)
                                                    .bold()
                                                if let ip = device.host {
                                                    Text(ip)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .frame(width: 200)
                                            .padding()
                                            .background(selectedDevice?.id == device.id ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                                            .cornerRadius(10)
                                        }
                                                }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Host or IP Address")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("192.168.1.1 or example.com", text: $customHost)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 40)
                }

                // Monitor Button
                Button(action: { toggleMonitoring() }) {
                    HStack {
                        Image(systemName: pingMonitor.isMonitoring ? "stop.fill" : "play.fill")
                        Text(pingMonitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(pingMonitor.isMonitoring ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .disabled(!canStartMonitoring())

                // Connection Quality
                if pingMonitor.isMonitoring {
                    let quality = pingMonitor.getConnectionQuality()

                    HStack(spacing: 15) {
                        Image(systemName: quality.icon)
                            .font(.system(size: 40))
                            .foregroundColor(colorForQuality(quality))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connection Quality")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(quality.rawValue)
                                .font(.title2)
                                .bold()
                                .foregroundColor(colorForQuality(quality))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(colorForQuality(quality).opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
                }

                // Statistics
                if let stats = pingMonitor.statistics {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Statistics")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            StatCard(
                                title: "Total Pings",
                                value: "\(stats.totalPings)",
                                icon: "arrow.up.arrow.down",
                                color: .blue
                            )

                            StatCard(
                                title: "Success Rate",
                                value: String(format: "%.1f%%", stats.successRate),
                                icon: "checkmark.circle.fill",
                                color: .green
                            )

                            StatCard(
                                title: "Packet Loss",
                                value: String(format: "%.1f%%", stats.packetLoss),
                                icon: "xmark.circle.fill",
                                color: stats.packetLoss > 5 ? .red : .orange
                            )

                            if let avgLatency = stats.avgLatency {
                                StatCard(
                                    title: "Avg Latency",
                                    value: String(format: "%.0fms", avgLatency * 1000),
                                    icon: "timer",
                                    color: .purple
                                )
                            }

                            if let minLatency = stats.minLatency {
                                StatCard(
                                    title: "Min Latency",
                                    value: String(format: "%.0fms", minLatency * 1000),
                                    icon: "hare.fill",
                                    color: .green
                                )
                            }

                            if let maxLatency = stats.maxLatency {
                                StatCard(
                                    title: "Max Latency",
                                    value: String(format: "%.0fms", maxLatency * 1000),
                                    icon: "tortoise.fill",
                                    color: .orange
                                )
                            }

                            if let jitter = stats.jitter {
                                StatCard(
                                    title: "Jitter",
                                    value: String(format: "%.0fms", jitter * 1000),
                                    icon: "waveform.path",
                                    color: .cyan
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }

                // Recent Pings
                if !pingMonitor.pingHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Recent Pings")
                                .font(.headline)

                            Spacer()

                            Button(action: { pingMonitor.clearHistory() }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "trash")
                                    Text("Clear")
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(pingMonitor.pingHistory.suffix(20)) { ping in
                                    PingResultBar(result: ping)
                                }
                            }
                        }

                        // Latest pings list
                        VStack(spacing: 8) {
                            ForEach(pingMonitor.pingHistory.suffix(10).reversed()) { ping in
                                PingResultRow(result: ping)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer(minLength: 40)
            }
        }
    }

    private func canStartMonitoring() -> Bool {
        if monitorMode == .device {
            return selectedDevice?.host != nil
        } else {
            return !customHost.isEmpty
        }
    }

    private func toggleMonitoring() {
        if pingMonitor.isMonitoring {
            pingMonitor.stopMonitoring()
        } else {
            let host: String
            if monitorMode == .device {
                host = selectedDevice?.host ?? ""
            } else {
                host = customHost
            }

            if !host.isEmpty {
                pingMonitor.startMonitoring(host: host)
            }
        }
    }

    private func colorForQuality(_ quality: PingMonitorManager.ConnectionQuality) -> Color {
        switch quality {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .yellow
        case .poor:
            return .red
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .bold()
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PingResultBar: View {
    let result: PingMonitorManager.PingResult

    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(result.isSuccess ? Color.green : Color.red)
                .frame(width: 8, height: barHeight())
                .cornerRadius(4)

            if let latency = result.latencyMs {
                Text(String(format: "%.0f", latency))
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            } else {
                Text("✕")
                    .font(.system(size: 8))
                    .foregroundColor(.red)
            }
        }
    }

    private func barHeight() -> CGFloat {
        guard let latency = result.latencyMs else { return 10 }

        // Scale: 0-500ms → 10-60 points
        let normalized = min(latency / 500.0, 1.0)
        return 10 + (normalized * 50)
    }
}

struct PingResultRow: View {
    let result: PingMonitorManager.PingResult

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(result.isSuccess ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            // Sequence number
            Text("#\(result.sequenceNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
                .font(.system(.caption, design: .monospaced))

            // Timestamp
            Text(formatTime(result.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
                .font(.system(.caption, design: .monospaced))

            Spacer()

            // Latency or failure
            if let latency = result.latencyMs {
                Text(String(format: "%.0f ms", latency))
                    .font(.caption)
                    .bold()
                    .foregroundColor(colorForLatency(latency))
                    .frame(width: 60, alignment: .trailing)
                    .font(.system(.caption, design: .monospaced))
            } else {
                Text("Timeout")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func colorForLatency(_ latency: Double) -> Color {
        if latency < 50 {
            return .green
        } else if latency < 100 {
            return .blue
        } else if latency < 200 {
            return .yellow
        } else {
            return .red
        }
    }
}
