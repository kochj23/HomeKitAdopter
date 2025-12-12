//
//  ScannerView.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI
import HomeKit

/// Main network scanning view - discovers unadopted HomeKit and Matter devices
struct ScannerView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager
    @StateObject private var homeManager = HomeManagerWrapper.shared
    
    @State private var showAllDevices = false
    @State private var selectedDevice: NetworkDiscoveryManager.DiscoveredDevice?
    @State private var filterType: NetworkDiscoveryManager.DiscoveredDevice.ServiceType?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Main content
                if networkDiscovery.isScanning {
                    scanningView
                } else if filteredDevices.isEmpty && !networkDiscovery.isScanning {
                    emptyStateView
                } else {
                    deviceListView
                }

                // Floating header with blur
                VStack(spacing: 0) {
                    headerView
                        .background(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)

                    Spacer()
                }
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailSheetView(device: device, networkDiscovery: networkDiscovery)
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 24) {
            // Title and scan button
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scanner")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Discover HomeKit & Matter devices")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Floating scan button
                Button(action: {
                    if networkDiscovery.isScanning {
                        networkDiscovery.stopDiscovery()
                    } else {
                        networkDiscovery.startDiscovery()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: networkDiscovery.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                            .font(.system(size: 24))
                            .imageScale(.large)
                        Text(networkDiscovery.isScanning ? "Stop" : "Scan")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 18)
                    .background(networkDiscovery.isScanning ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: (networkDiscovery.isScanning ? Color.red : Color.blue).opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }

            // Stats cards
            if !networkDiscovery.discoveredDevices.isEmpty {
                HStack(spacing: 20) {
                    modernStatCard(
                        icon: "wifi",
                        value: "\(networkDiscovery.discoveredDevices.count)",
                        label: "Total Devices",
                        gradient: [Color.blue, Color.cyan]
                    )

                    modernStatCard(
                        icon: "exclamationmark.triangle.fill",
                        value: "\(networkDiscovery.getUnadoptedDevices().count)",
                        label: "Unadopted",
                        gradient: [Color.orange, Color.yellow]
                    )

                    modernStatCard(
                        icon: "checkmark.circle.fill",
                        value: "\(homeManager.homes.flatMap { $0.accessories }.count)",
                        label: "Adopted",
                        gradient: [Color.green, Color.mint]
                    )
                }
            }

            // Filter and toggle row
            HStack(spacing: 16) {
                // Show all toggle
                Button(action: { showAllDevices.toggle() }) {
                    HStack(spacing: 10) {
                        Image(systemName: showAllDevices ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 18))
                        Text(showAllDevices ? "All Devices" : "Unadopted Only")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(showAllDevices ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 30)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(NetworkDiscoveryManager.DiscoveredDevice.ServiceType.allCases, id: \.self) { type in
                            FilterChip(
                                type: type,
                                isSelected: filterType == type,
                                action: { filterType = (filterType == type) ? nil : type }
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 28)
    }

    private func modernStatCard(icon: String, value: String, label: String, gradient: [Color]) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: gradient.map { $0.opacity(0.1) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: gradient.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Filter Chip Component

struct FilterChip: View {
    let type: NetworkDiscoveryManager.DiscoveredDevice.ServiceType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                Text(type.displayName)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scanner View Extension

extension ScannerView {
    // MARK: - Device List View

    private var filteredDevices: [NetworkDiscoveryManager.DiscoveredDevice] {
        var devices = showAllDevices ? networkDiscovery.discoveredDevices : networkDiscovery.getUnadoptedDevices()

        if let filterType = filterType {
            devices = devices.filter { $0.serviceType == filterType }
        }

        return devices.sorted { $0.discoveredAt > $1.discoveredAt }
    }

    private var deviceListView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 30)], spacing: 30) {
                ForEach(filteredDevices) { device in
                    DeviceCardView(device: device, networkDiscovery: networkDiscovery) {
                        selectedDevice = device
                    }
                    .focusable()
                }
            }
            .padding(.top, 320) // Space for floating header
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 100))
                .foregroundColor(.blue)

            Text("No Unadopted Devices Found")
                .font(.largeTitle)
                .bold()

            Text("Tap 'Start Scan' to search for HomeKit and Matter devices")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                networkDiscovery.startDiscovery()
            }) {
                Label("Start Scanning Network", systemImage: "antenna.radiowaves.left.and.right")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(2.0)

            Text("Scanning Network...")
                .font(.title)
                .bold()

            Text("Searching for HomeKit and Matter devices")
                .font(.body)
                .foregroundColor(.secondary)

            if !networkDiscovery.discoveredDevices.isEmpty {
                Text("Found \(networkDiscovery.discoveredDevices.count) device(s)...")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }

            Button("Stop Scanning") {
                networkDiscovery.stopDiscovery()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }
}
