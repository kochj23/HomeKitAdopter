//
//  DashboardView.swift
//  HomeKitAdopter - Analytics Dashboard
//
//  Created by Jordan Koch on 2025-11-23.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI
import Charts

/// Data visualization dashboard with charts, timelines, and live activity indicators
struct DashboardView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager
    @StateObject private var homeManager = HomeManagerWrapper.shared
    @StateObject private var firmwareManager = FirmwareManager.shared
    @StateObject private var securityAudit = SecurityAuditManager.shared
    @StateObject private var scanScheduler = ScanSchedulerManager.shared

    @State private var animateRings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Hero Section with Activity Rings
                heroRingsSection

                // Device Distribution Donut Chart
                if !networkDiscovery.discoveredDevices.isEmpty {
                    deviceDistributionChart
                }

                // Security Heat Map
                securityHeatMap

                // Network Activity Timeline
                activityTimeline

                // Live Status Indicators
                liveStatusGrid
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 30)
        }
        .onAppear {
            // Audit all devices
            for device in networkDiscovery.discoveredDevices {
                _ = securityAudit.auditDevice(device)
            }

            // Animate rings
            withAnimation(.easeInOut(duration: 1.5).delay(0.3)) {
                animateRings = true
            }
        }
    }

    // MARK: - Hero Activity Rings Section

    private var heroRingsSection: some View {
        VStack(spacing: 24) {
            Text("Network Overview")
                .font(.system(size: 42, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 40) {
                // Main Activity Ring
                ZStack {
                    // Background rings
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 28)
                        .frame(width: 280, height: 280)

                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 24)
                        .frame(width: 230, height: 230)

                    Circle()
                        .stroke(Color.purple.opacity(0.2), lineWidth: 20)
                        .frame(width: 186, height: 186)

                    // Animated rings
                    Circle()
                        .trim(from: 0, to: animateRings ? deviceProgress() : 0)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 28, lineCap: .round)
                        )
                        .frame(width: 280, height: 280)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .trim(from: 0, to: animateRings ? unadoptedProgress() : 0)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 24, lineCap: .round)
                        )
                        .frame(width: 230, height: 230)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .trim(from: 0, to: animateRings ? adoptedProgress() : 0)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 186, height: 186)
                        .rotationEffect(.degrees(-90))

                    // Center stats
                    VStack(spacing: 8) {
                        Text("\(networkDiscovery.discoveredDevices.count)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                        Text("Devices")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                // Ring Legend
                VStack(alignment: .leading, spacing: 24) {
                    ringLegendItem(
                        color: .blue,
                        title: "Total Discovered",
                        value: "\(networkDiscovery.discoveredDevices.count)",
                        icon: "antenna.radiowaves.left.and.right"
                    )

                    ringLegendItem(
                        color: .green,
                        title: "Unadopted",
                        value: "\(networkDiscovery.getUnadoptedDevices().count)",
                        icon: "exclamationmark.circle.fill"
                    )

                    ringLegendItem(
                        color: .purple,
                        title: "Adopted",
                        value: "\(networkDiscovery.getAdoptedDevices().count)",
                        icon: "checkmark.circle.fill"
                    )
                }
            }
        }
        .padding(32)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
    }

    private func ringLegendItem(color: Color, title: String, value: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Device Distribution Donut Chart

    private var deviceDistributionChart: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Device Distribution")
                .font(.system(size: 32, weight: .bold))

            let manufacturerCounts = Dictionary(grouping: networkDiscovery.discoveredDevices) { device in
                device.manufacturer ?? "Unknown"
            }.mapValues { $0.count }

            HStack(spacing: 40) {
                // Donut Chart
                if #available(tvOS 17.0, *) {
                    Chart {
                        ForEach(Array(manufacturerCounts.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { manufacturer, count in
                            SectorMark(
                                angle: .value("Count", count),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                            )
                            .foregroundStyle(by: .value("Manufacturer", manufacturer))
                            .cornerRadius(8)
                        }
                    }
                    .frame(width: 300, height: 300)
                    .chartLegend(position: .trailing, spacing: 16)
                } else {
                    // Fallback for older tvOS
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 300, height: 300)

                        VStack(spacing: 8) {
                            Text("\(manufacturerCounts.count)")
                                .font(.system(size: 48, weight: .bold))
                            Text("Manufacturers")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Top Manufacturers List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Manufacturers")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)

                    ForEach(Array(manufacturerCounts.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { manufacturer, count in
                        HStack {
                            Circle()
                                .fill(colorForManufacturer(manufacturer))
                                .frame(width: 12, height: 12)

                            Text(manufacturer)
                                .font(.system(size: 18))

                            Spacer()

                            Text("\(count)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(colorForManufacturer(manufacturer))
                        }
                    }
                }
            }
        }
        .padding(32)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(24)
    }

    // MARK: - Security Heat Map

    private var securityHeatMap: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Security Status")
                    .font(.system(size: 32, weight: .bold))

                Spacer()

                let stats = securityAudit.getStatistics()
                let totalIssues = stats.criticalRisk + stats.highRisk + stats.mediumRisk + stats.lowRisk

                if totalIssues > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(totalIssues) issues detected")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(12)
                }
            }

            let stats = securityAudit.getStatistics()

            HStack(spacing: 16) {
                securityHeatTile(
                    title: "Critical",
                    count: stats.criticalRisk,
                    color: .red,
                    icon: "exclamationmark.octagon.fill"
                )
                .focusable()

                securityHeatTile(
                    title: "High",
                    count: stats.highRisk,
                    color: .orange,
                    icon: "exclamationmark.triangle.fill"
                )
                .focusable()

                securityHeatTile(
                    title: "Medium",
                    count: stats.mediumRisk,
                    color: .yellow,
                    icon: "exclamationmark.circle.fill"
                )
                .focusable()

                securityHeatTile(
                    title: "Low",
                    count: stats.lowRisk,
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                .focusable()
            }
        }
        .padding(32)
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.05), Color.orange.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(24)
    }

    private func securityHeatTile(title: String, count: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)

                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(color)

                    Text("\(count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
            }

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(color.opacity(0.08))
        .cornerRadius(20)
    }

    // MARK: - Activity Timeline

    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recent Activity")
                .font(.system(size: 32, weight: .bold))

            let recentScans = scanScheduler.schedule.scanHistory.suffix(8).reversed()

            if recentScans.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No scan history yet")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    Text("Run your first network scan to see activity")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentScans.enumerated()), id: \.element.id) { index, scan in
                        timelineItem(scan: scan, isLast: index == recentScans.count - 1)
                    }
                }
            }
        }
        .padding(32)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(24)
    }

    private func timelineItem(scan: ScanSchedulerManager.ScanRecord, isLast: Bool) -> some View {
        HStack(spacing: 20) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(scan.newDevicesSinceLastScan > 0 ? Color.green : Color.blue)
                    .frame(width: 16, height: 16)

                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 60)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(formatDate(scan.timestamp))
                        .font(.system(size: 18, weight: .semibold))

                    Spacer()

                    if scan.newDevicesSinceLastScan > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("\(scan.newDevicesSinceLastScan) new")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(10)
                    }
                }

                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                        Text("\(scan.devicesFound) found")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.orange)
                        Text("\(scan.unadoptedCount) unadopted")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                        Text("\(Int(scan.scanDuration))s")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
    }

    // MARK: - Live Status Grid

    private var liveStatusGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            // Firmware Status
            liveStatusCard(
                title: "Firmware",
                icon: "arrow.triangle.2.circlepath",
                gradient: [.orange, .red],
                stats: firmwareStats()
            )
            .focusable()

            // Scan Schedule
            liveStatusCard(
                title: "Scan Schedule",
                icon: "calendar.badge.clock",
                gradient: [.blue, .purple],
                stats: scanScheduleStats()
            )
            .focusable()
        }
    }

    private func liveStatusCard(title: String, icon: String, gradient: [Color], stats: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(gradient[0])

                Text(title)
                    .font(.system(size: 24, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(stats, id: \.0) { stat in
                    HStack {
                        Text(stat.0)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(stat.1)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: gradient.map { $0.opacity(0.1) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: gradient.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }

    // MARK: - Helper Functions

    private func deviceProgress() -> CGFloat {
        let total = max(networkDiscovery.discoveredDevices.count, 1)
        return CGFloat(total) / CGFloat(total)
    }

    private func unadoptedProgress() -> CGFloat {
        let total = max(networkDiscovery.discoveredDevices.count, 1)
        let unadopted = networkDiscovery.getUnadoptedDevices().count
        return CGFloat(unadopted) / CGFloat(total)
    }

    private func adoptedProgress() -> CGFloat {
        let total = max(networkDiscovery.discoveredDevices.count, 1)
        let adopted = networkDiscovery.getAdoptedDevices().count
        return CGFloat(adopted) / CGFloat(total)
    }

    private func colorForManufacturer(_ manufacturer: String) -> Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .cyan, .indigo, .mint]
        let hash = abs(manufacturer.hashValue)
        return colors[hash % colors.count]
    }

    private func firmwareStats() -> [(String, String)] {
        let stats = firmwareManager.getStatistics()
        return [
            ("Outdated", "\(stats.outdatedCount)"),
            ("Up to Date", "\(stats.upToDateCount)"),
            ("Status", stats.outdatedCount > 0 ? "Action Needed" : "All Current")
        ]
    }

    private func scanScheduleStats() -> [(String, String)] {
        let stats = scanScheduler.getScanStatistics()
        var result: [(String, String)] = [
            ("Status", scanScheduler.schedule.isEnabled ? "Active" : "Inactive"),
            ("Total Scans", "\(stats.totalScans)")
        ]

        if let nextScan = scanScheduler.nextScheduledScan {
            result.append(("Next Scan", timeUntil(nextScan)))
        }

        return result
    }

    private func timeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval < 60 { return "< 1m" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
