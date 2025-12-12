//
//  ToolsView.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Tools view with grid menu of utility features
struct ToolsView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager
    @State private var showingExport = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 20) {
                    Text("Tools")
                        .font(.system(size: 52, weight: .bold))
                        .padding(.horizontal, 40)
                        .padding(.top, 30)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: 4), spacing: 30) {
                        // Port Scanner (NEW - HIGH PRIORITY)
                        NavigationLink(destination: PortScannerView(networkDiscovery: networkDiscovery)) {
                            ToolMenuItem(
                                title: "Port Scanner",
                                icon: "network.badge.shield.half.filled",
                                description: "Scan for open ports & services",
                                color: .red
                            )
                        }
                        .buttonStyle(.plain)

                        // ARP Scanner (NEW - HIGH PRIORITY)
                        NavigationLink(destination: ARPScannerView()) {
                            ToolMenuItem(
                                title: "ARP Scanner",
                                icon: "wifi.router",
                                description: "Discover all network devices",
                                color: .cyan
                            )
                        }
                        .buttonStyle(.plain)

                        // Ping Monitor (NEW)
                        NavigationLink(destination: PingMonitorView(networkDiscovery: networkDiscovery)) {
                            ToolMenuItem(
                                title: "Ping Monitor",
                                icon: "waveform.path.ecg",
                                description: "Monitor connectivity & latency",
                                color: .green
                            )
                        }
                        .buttonStyle(.plain)

                        // Network Topology
                        NavigationLink(destination: NetworkTopologyView(networkDiscovery: networkDiscovery)) {
                            ToolMenuItem(
                                title: "Network Topology",
                                icon: "network",
                                description: "Visualize network diagram",
                                color: .blue
                            )
                        }
                        .buttonStyle(.plain)

                        // Export Data
                        Button(action: { showingExport = true }) {
                            ToolMenuItem(
                                title: "Export Data",
                                icon: "square.and.arrow.up.fill",
                                description: "Export devices to CSV or JSON",
                                color: .indigo
                            )
                        }
                        .buttonStyle(.plain)

                        // Security Audit
                        NavigationLink(destination: SecurityAuditListView(networkDiscovery: networkDiscovery)) {
                            ToolMenuItem(
                                title: "Security Audit",
                                icon: "shield.fill",
                                description: "Check for vulnerabilities",
                                color: .red
                            )
                        }
                        .buttonStyle(.plain)

                        // Network Diagnostics
                        NavigationLink(destination: NetworkDiagnosticsListView(networkDiscovery: networkDiscovery)) {
                            ToolMenuItem(
                                title: "Network Diagnostics",
                                icon: "stethoscope",
                                description: "Test connectivity & latency",
                                color: .green
                            )
                        }
                        .buttonStyle(.plain)

                        // Firmware Check
                        NavigationLink(destination: FirmwareCheckView(networkDiscovery: networkDiscovery)) {
                            ToolMenuItem(
                                title: "Firmware Check",
                                icon: "arrow.triangle.2.circlepath",
                                description: "Check for outdated firmware",
                                color: .orange
                            )
                        }
                        .buttonStyle(.plain)

                        // Device History
                        NavigationLink(destination: DeviceHistoryListView()) {
                            ToolMenuItem(
                                title: "Device History",
                                icon: "clock.arrow.circlepath",
                                description: "View tracking history",
                                color: .purple
                            )
                        }
                        .buttonStyle(.plain)

                        // Device Comparison
                        NavigationLink(destination: DeviceComparisonListView(networkDiscovery: networkDiscovery)) {
                            ToolMenuItem(
                                title: "Device Comparison",
                                icon: "rectangle.2.swap",
                                description: "Compare discovered vs adopted",
                                color: .cyan
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportSheetView(networkDiscovery: networkDiscovery)
        }
    }
}

/// Reusable tool menu item card
struct ToolMenuItem: View {
    let title: String
    let icon: String
    let description: String
    let color: Color

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 53))
                .foregroundColor(color)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 21, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(27)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(0.4), lineWidth: 2)
        )
        .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
