//
//  PortScannerView.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Port scanner interface with device selection and results
struct PortScannerView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager
    @StateObject private var portScanner = PortScannerManager()

    @State private var selectedDevice: NetworkDiscoveryManager.DiscoveredDevice?
    @State private var scanType: ScanType = .common
    @State private var customStartPort: String = "1"
    @State private var customEndPort: String = "1000"
    @State private var showingDeviceSelector = false
    @State private var selectedPort: PortScannerManager.OpenPort?

    enum ScanType: String, CaseIterable {
        case common = "Common Ports (Quick)"
        case top1000 = "Top 1000 Ports"
        case full = "Full Scan (1-65535)"
        case custom = "Custom Range"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "network.badge.shield.half.filled")
                            .font(.system(size: 56))
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Port Scanner")
                                .font(.system(size: 44, weight: .bold))

                            Text("Discover open ports & services")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                // Device Selection
                VStack(alignment: .leading, spacing: 15) {
                    Text("Target Device")
                        .font(.headline)

                    Button(action: { showingDeviceSelector = true }) {
                        HStack {
                            if let device = selectedDevice {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name)
                                        .font(.body)
                                        .foregroundColor(.primary)

                                    if let host = device.host {
                                        Text(host)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                Text("Select a device to scan...")
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 40)

                // Scan Type Selection
                if selectedDevice != nil {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Scan Type")
                            .font(.headline)

                        ForEach(ScanType.allCases, id: \.self) { type in
                            Button(action: { scanType = type }) {
                                HStack {
                                    Image(systemName: scanType == type ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(scanType == type ? .blue : .gray)

                                    Text(type.rawValue)
                                        .foregroundColor(.primary)

                                    Spacer()
                                }
                                .padding()
                                .background(scanType == type ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }

                        // Custom Range Inputs
                        if scanType == .custom {
                            HStack(spacing: 15) {
                                VStack(alignment: .leading) {
                                    Text("Start Port")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("1", text: $customStartPort)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.numberPad)
                                }

                                VStack(alignment: .leading) {
                                    Text("End Port")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("1000", text: $customEndPort)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.numberPad)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }

                // Scan Button
                if selectedDevice != nil {
                    Button(action: { startScan() }) {
                        HStack {
                            Image(systemName: portScanner.isScanning ? "stop.fill" : "play.fill")
                            Text(portScanner.isScanning ? "Stop Scan" : "Start Scan")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(portScanner.isScanning ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                }

                // Progress
                if portScanner.isScanning {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Scanning...")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(portScanner.scanProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ProgressView(value: portScanner.scanProgress)

                        Text("Current Port: \(portScanner.currentPort)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 40)
                }

                // Results Summary
                if !portScanner.openPorts.isEmpty {
                    let summary = portScanner.getScanSummary()

                    VStack(alignment: .leading, spacing: 15) {
                        Text("Scan Summary")
                            .font(.headline)

                        HStack(spacing: 20) {
                            PortScanSummaryCard(
                                title: "Open Ports",
                                value: "\(summary.totalOpenPorts)",
                                color: .blue
                            )

                            if summary.criticalRiskCount > 0 {
                                PortScanSummaryCard(
                                    title: "Critical",
                                    value: "\(summary.criticalRiskCount)",
                                    color: .red
                                )
                            }

                            if summary.highRiskCount > 0 {
                                PortScanSummaryCard(
                                    title: "High Risk",
                                    value: "\(summary.highRiskCount)",
                                    color: .orange
                                )
                            }

                            if summary.insecureServiceCount > 0 {
                                PortScanSummaryCard(
                                    title: "Insecure",
                                    value: "\(summary.insecureServiceCount)",
                                    color: .yellow
                                )
                            }
                        }

                        // Overall Risk Assessment
                        HStack {
                            Text("Overall Risk:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(summary.overallRisk)
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(riskColor(summary.overallRisk))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                }

                // Results List
                if !portScanner.openPorts.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Open Ports (\(portScanner.openPorts.count))")
                            .font(.headline)

                        ForEach(portScanner.openPorts) { openPort in
                            Button(action: { selectedPort = openPort }) {
                                OpenPortCard(openPort: openPort)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer(minLength: 40)
            }
            .padding(.bottom, 50)
        }
        .sheet(isPresented: $showingDeviceSelector) {
            DeviceSelectorSheet(
                devices: networkDiscovery.discoveredDevices,
                selectedDevice: $selectedDevice,
                isPresented: $showingDeviceSelector
            )
        }
        .sheet(item: $selectedPort) { port in
            PortDetailSheet(openPort: port, scanner: portScanner)
        }
    }

    private func startScan() {
        guard let device = selectedDevice, let host = device.host else { return }

        if portScanner.isScanning {
            portScanner.stopScan()
            return
        }

        Task {
            switch scanType {
            case .common:
                await portScanner.scanCommonPorts(host: host)
            case .top1000:
                await portScanner.scanPortRange(host: host, startPort: 1, endPort: 1000)
            case .full:
                await portScanner.scanAllPorts(host: host)
            case .custom:
                if let start = Int(customStartPort), let end = Int(customEndPort) {
                    await portScanner.scanPortRange(host: host, startPort: start, endPort: end)
                }
            }
        }
    }

    private func riskColor(_ risk: String) -> Color {
        switch risk {
        case "Critical": return .red
        case "High": return .orange
        case "Medium": return .yellow
        default: return .blue
        }
    }
}

// MARK: - Supporting Views

struct OpenPortCard: View {
    let openPort: PortScannerManager.OpenPort

    var body: some View {
        HStack(spacing: 15) {
            // Risk Indicator
            Circle()
                .fill(riskColor)
                .frame(width: 12, height: 12)

            // Port Number
            Text("\(openPort.port)")
                .font(.title3)
                .bold()
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)

            // Service Info
            VStack(alignment: .leading, spacing: 4) {
                Text(openPort.service.name)
                    .font(.body)
                    .bold()
                    .foregroundColor(.primary)

                Text(openPort.service.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Risk Level
            Text(openPort.riskLevel.rawValue)
                .font(.caption)
                .bold()
                .foregroundColor(riskColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(riskColor.opacity(0.2))
                .cornerRadius(8)

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    private var riskColor: Color {
        switch openPort.riskLevel {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

private struct PortScanSummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
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

struct DeviceSelectorSheet: View {
    let devices: [NetworkDiscoveryManager.DiscoveredDevice]
    @Binding var selectedDevice: NetworkDiscoveryManager.DiscoveredDevice?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(devices.filter { $0.host != nil }) { device in
                    Button(action: {
                        selectedDevice = device
                        isPresented = false
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.body)

                                if let host = device.host {
                                    Text(host)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if selectedDevice?.id == device.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Device")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct PortDetailSheet: View {
    let openPort: PortScannerManager.OpenPort
    let scanner: PortScannerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Port \(openPort.port)")
                                .font(.largeTitle)
                                .bold()

                            Text(openPort.service.name)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Risk Badge
                        VStack(spacing: 4) {
                            Circle()
                                .fill(riskColor)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(openPort.riskLevel.rawValue)
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // Service Details
                    VStack(alignment: .leading, spacing: 15) {
                        PortScanDetailRow(label: "Service", value: openPort.service.name)
                        PortScanDetailRow(label: "Description", value: openPort.service.description)
                        PortScanDetailRow(label: "Protocol", value: openPort.service.transportProtocol)
                        PortScanDetailRow(label: "Security", value: openPort.service.isSecure ? "Encrypted" : "Unencrypted")
                        PortScanDetailRow(label: "State", value: openPort.state.rawValue)
                        PortScanDetailRow(label: "Response Time", value: String(format: "%.0f ms", openPort.responseTime * 1000))
                    }
                    .padding(.horizontal)

                    // Vulnerabilities
                    if !openPort.service.commonVulnerabilities.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Common Vulnerabilities")
                                .font(.headline)

                            ForEach(openPort.service.commonVulnerabilities, id: \.self) { vuln in
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(vuln)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Security Recommendations
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Security Recommendations")
                            .font(.headline)

                        ForEach(scanner.getSecurityRecommendations(for: openPort), id: \.self) { recommendation in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "shield.checkered")
                                    .foregroundColor(.blue)
                                Text(recommendation)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Port Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var riskColor: Color {
        switch openPort.riskLevel {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
}

private struct PortScanDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .bold()
        }
    }
}
