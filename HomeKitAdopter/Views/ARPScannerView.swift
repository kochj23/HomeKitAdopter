//
//  ARPScannerView.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// ARP Scanner interface for discovering all network devices
struct ARPScannerView: View {
    @StateObject private var arpScanner = ARPScannerManager()
    @State private var selectedDevice: ARPScannerManager.ARPDevice?
    @State private var customSubnet: String = ""
    @State private var scanMode: ScanMode = .auto

    enum ScanMode {
        case auto    // Auto-detect subnet
        case custom  // Manual subnet entry
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                // Header
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "wifi.router")
                            .font(.system(size: 40))
                            .foregroundColor(.cyan)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("ARP Scanner")
                                .font(.title)
                                .bold()

                            Text("Discover all devices on network")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Unlike Bonjour, ARP scanning finds ALL devices including silent/hidden ones")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 5)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)

                // Scan Mode Selection
                VStack(alignment: .leading, spacing: 15) {
                    Text("Scan Mode")
                        .font(.headline)

                    HStack(spacing: 15) {
                        Button(action: { scanMode = .auto }) {
                            VStack(spacing: 8) {
                                Image(systemName: scanMode == .auto ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(scanMode == .auto ? .cyan : .gray)

                                Text("Auto-Detect")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(scanMode == .auto ? Color.cyan.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }

                        Button(action: { scanMode = .custom }) {
                            VStack(spacing: 8) {
                                Image(systemName: scanMode == .custom ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(scanMode == .custom ? .cyan : .gray)

                                Text("Custom Subnet")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(scanMode == .custom ? Color.cyan.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }

                    // Custom Subnet Input
                    if scanMode == .custom {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subnet (CIDR notation)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("192.168.1.0/24", text: $customSubnet)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                .padding(.horizontal, 40)

                // Scan Button
                Button(action: { startScan() }) {
                    HStack {
                        Image(systemName: arpScanner.isScanning ? "stop.fill" : "play.fill")
                        Text(arpScanner.isScanning ? "Stop Scan" : "Start Scan")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(arpScanner.isScanning ? Color.red : Color.cyan)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)

                // Progress
                if arpScanner.isScanning {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Scanning network...")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(arpScanner.scanProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ProgressView(value: arpScanner.scanProgress)

                        Text("This may take 1-2 minutes for a /24 subnet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 40)
                }

                // Summary
                if !arpScanner.discoveredDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Scan Summary")
                            .font(.headline)

                        HStack(spacing: 15) {
                            ARPSummaryCard(
                                title: "Total Devices",
                                value: "\(arpScanner.discoveredDevices.count)",
                                color: .cyan,
                                icon: "network"
                            )

                            let typeCounts = arpScanner.getDeviceTypeCount()

                            if let iotCount = typeCounts[.iot], iotCount > 0 {
                                ARPSummaryCard(
                                    title: "IoT Devices",
                                    value: "\(iotCount)",
                                    color: .blue,
                                    icon: "sensor"
                                )
                            }

                            if let mobileCount = typeCounts[.mobile], mobileCount > 0 {
                                ARPSummaryCard(
                                    title: "Mobile",
                                    value: "\(mobileCount)",
                                    color: .green,
                                    icon: "iphone"
                                )
                            }

                            if let computerCount = typeCounts[.computer], computerCount > 0 {
                                ARPSummaryCard(
                                    title: "Computers",
                                    value: "\(computerCount)",
                                    color: .purple,
                                    icon: "desktopcomputer"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 40)

                    // Vendor Statistics
                    let vendorCounts = arpScanner.getVendorCount()
                    if !vendorCounts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Vendors Found")
                                .font(.headline)

                            ForEach(Array(vendorCounts.prefix(5)), id: \.key) { vendor, count in
                                HStack {
                                    Text(vendor)
                                        .font(.subheadline)

                                    Spacer()

                                    Text("\(count) device\(count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal, 40)
                    }
                }

                // Devices List
                if !arpScanner.discoveredDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Discovered Devices (\(arpScanner.discoveredDevices.count))")
                            .font(.headline)

                        ForEach(arpScanner.discoveredDevices) { device in
                            Button(action: { selectedDevice = device }) {
                                ARPDeviceCard(device: device)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer(minLength: 40)
            }
            .padding(.bottom, 50)
        }
        .sheet(item: $selectedDevice) { device in
            ARPDeviceDetailSheet(device: device)
        }
    }

    private func startScan() {
        if arpScanner.isScanning {
            arpScanner.stopScan()
            return
        }

        Task {
            switch scanMode {
            case .auto:
                await arpScanner.scanLocalSubnet()
            case .custom:
                if !customSubnet.isEmpty {
                    await arpScanner.scanSubnet(customSubnet)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ARPDeviceCard: View {
    let device: ARPScannerManager.ARPDevice

    var body: some View {
        HStack(spacing: 15) {
            // Device Icon
            Image(systemName: device.deviceType.icon)
                .font(.system(size: 32))
                .foregroundColor(.cyan)
                .frame(width: 50, height: 50)
                .background(Color.cyan.opacity(0.2))
                .cornerRadius(10)

            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                if let hostname = device.hostname {
                    Text(hostname)
                        .font(.body)
                        .bold()
                        .foregroundColor(.primary)
                } else {
                    Text(device.ipAddress)
                        .font(.body)
                        .bold()
                        .foregroundColor(.primary)
                }

                HStack(spacing: 8) {
                    if let vendor = device.vendor {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.fill")
                                .font(.caption2)
                            Text(vendor)
                                .font(.caption)
                                .bold()
                        }
                        .foregroundColor(.blue)
                    }

                    Text(device.deviceType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if device.hostname != nil {
                    Text(device.ipAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }
            }

            Spacer()

            // Status Indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(device.isResponding ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                if let responseTime = device.responseTime {
                    Text(String(format: "%.0fms", responseTime * 1000))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

private struct ARPSummaryCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
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

struct ARPDeviceDetailSheet: View {
    let device: ARPScannerManager.ARPDevice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Header
                    HStack {
                        Image(systemName: device.deviceType.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.cyan)
                            .frame(width: 80, height: 80)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(15)

                        VStack(alignment: .leading, spacing: 8) {
                            if let hostname = device.hostname {
                                Text(hostname)
                                    .font(.title2)
                                    .bold()
                            }

                            Text(device.deviceType.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let vendor = device.vendor {
                                Text(vendor)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    Divider()

                    // Network Details
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Network Information")
                            .font(.headline)

                        ARPDetailRow(label: "IP Address", value: device.ipAddress)

                        if let macAddress = device.macAddress {
                            ARPDetailRow(label: "MAC Address", value: macAddress)
                        } else {
                            ARPDetailRow(label: "MAC Address", value: "Not available (tvOS limitation)")
                        }

                        if let hostname = device.hostname {
                            ARPDetailRow(label: "Hostname", value: hostname)
                        }

                        ARPDetailRow(label: "Status", value: device.isResponding ? "Online" : "Offline")

                        if let responseTime = device.responseTime {
                            ARPDetailRow(label: "Response Time", value: String(format: "%.0f ms", responseTime * 1000))
                        }

                        ARPDetailRow(label: "Last Seen", value: formatDate(device.lastSeen))
                    }
                    .padding(.horizontal)

                    // Vendor Information
                    if let vendor = device.vendor {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Vendor Information")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.blue)
                                    Text("Manufacturer")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text(vendor)
                                        .font(.subheadline)
                                        .bold()
                                }

                                Text("Identified from MAC address OUI lookup")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Device Type Information
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Device Type")
                            .font(.headline)

                        HStack {
                            Image(systemName: device.deviceType.icon)
                                .foregroundColor(.cyan)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.deviceType.displayName)
                                    .font(.subheadline)
                                    .bold()

                                Text(getDeviceTypeDescription(device.deviceType))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Device Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func getDeviceTypeDescription(_ type: ARPScannerManager.ARPDevice.DeviceType) -> String {
        switch type {
        case .router:
            return "Network gateway or router"
        case .computer:
            return "Desktop or laptop computer"
        case .mobile:
            return "Smartphone or tablet"
        case .iot:
            return "Smart home or IoT device"
        case .printer:
            return "Network printer"
        case .unknown:
            return "Unknown device type"
        }
    }
}

private struct ARPDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .bold()
                .font(.system(.subheadline, design: .monospaced))
        }
    }
}
