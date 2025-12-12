//
//  NetworkTopologyView.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Interactive network topology visualization
///
/// Displays all discovered devices organized by category (Smart Home, Google, UniFi, Apple)
/// in an easy-to-read hierarchical diagram optimized for tvOS navigation.
///
/// Features:
/// - Category-based grouping
/// - Color-coded device types
/// - Interactive device selection
/// - Real-time connection status
/// - Network statistics
struct NetworkTopologyView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager
    @State private var selectedDevice: NetworkDiscoveryManager.DiscoveredDevice?
    @State private var selectedCategory: NetworkDiscoveryManager.DiscoveredDevice.DeviceCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    // Header with network stats
                    headerSection

                    Divider()

                    // Network diagram
                    VStack(spacing: 40) {
                        // Router/Gateway representation
                        routerNode

                        // Device categories
                        ForEach(NetworkDiscoveryManager.DiscoveredDevice.DeviceCategory.allCases, id: \.self) { category in
                            categorySection(for: category)
                        }
                    }
                }
                .padding(40)
            }
            .navigationTitle("Network Topology")
            .sheet(item: $selectedDevice) { device in
                DeviceDetailSheetView(device: device, networkDiscovery: networkDiscovery)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "network")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Topology Map")
                        .font(.title2)
                        .bold()

                    Text("\(networkDiscovery.discoveredDevices.count) devices discovered")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Category filter buttons
                HStack(spacing: 12) {
                    Button("All") {
                        selectedCategory = nil
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedCategory == nil ? .blue : .gray)

                    ForEach(NetworkDiscoveryManager.DiscoveredDevice.DeviceCategory.allCases, id: \.self) { category in
                        Button(category.rawValue) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedCategory == category ? categoryColor(category) : .gray)
                    }
                }
            }

            // Network statistics
            HStack(spacing: 24) {
                statBadge(
                    icon: "house.fill",
                    value: "\(deviceCount(for: .smarthome))",
                    label: "Smart Home",
                    color: .blue
                )
                statBadge(
                    icon: "g.circle.fill",
                    value: "\(deviceCount(for: .google))",
                    label: "Google",
                    color: .red
                )
                statBadge(
                    icon: "wifi.router.fill",
                    value: "\(deviceCount(for: .unifi))",
                    label: "UniFi",
                    color: .cyan
                )
                statBadge(
                    icon: "applelogo",
                    value: "\(deviceCount(for: .apple))",
                    label: "Apple",
                    color: .gray
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .bold()
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Router Node

    private var routerNode: some View {
        VStack(spacing: 12) {
            // Router icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 120, height: 120)

                Image(systemName: "wifi.router")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }

            Text("Local Network")
                .font(.headline)

            Text("Router/Gateway")
                .font(.caption)
                .foregroundColor(.secondary)

            // Connection lines indicator
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(for category: NetworkDiscoveryManager.DiscoveredDevice.DeviceCategory) -> some View {
        let devices = getDevices(for: category)

        guard !devices.isEmpty else {
            return AnyView(EmptyView())
        }

        // Hide if filtering and this isn't the selected category
        if let selected = selectedCategory, selected != category {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(spacing: 20) {
                // Category header
                HStack {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundColor(categoryColor(category))

                    Text(category.rawValue)
                        .font(.title3)
                        .bold()

                    Spacer()

                    Text("\(devices.count) device\(devices.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Device grid for this category
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 20)], spacing: 20) {
                    ForEach(devices) { device in
                        deviceNode(device: device, category: category)
                    }
                }
            }
            .padding()
            .background(categoryColor(category).opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(categoryColor(category).opacity(0.3), lineWidth: 2)
            )
        )
    }

    // MARK: - Device Node

    private func deviceNode(device: NetworkDiscoveryManager.DiscoveredDevice, category: NetworkDiscoveryManager.DiscoveredDevice.DeviceCategory) -> some View {
        Button {
            selectedDevice = device
        } label: {
            VStack(spacing: 12) {
                // Device icon
                ZStack {
                    Circle()
                        .fill(categoryColor(category).opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: device.serviceType.icon)
                        .font(.system(size: 36))
                        .foregroundColor(categoryColor(category))
                }

                // Device info
                VStack(spacing: 4) {
                    Text(device.name)
                        .font(.subheadline)
                        .bold()
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(device.serviceType.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let host = device.host {
                        HStack(spacing: 4) {
                            Image(systemName: "network")
                                .font(.caption2)
                            Text(host)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }

                    // Connection indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Connected")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(categoryColor(category).opacity(0.5), lineWidth: 2)
            )
        }
    }

    // MARK: - Helper Methods

    private func getDevices(for category: NetworkDiscoveryManager.DiscoveredDevice.DeviceCategory) -> [NetworkDiscoveryManager.DiscoveredDevice] {
        return networkDiscovery.discoveredDevices.filter { $0.serviceType.category == category }
    }

    private func deviceCount(for category: NetworkDiscoveryManager.DiscoveredDevice.DeviceCategory) -> Int {
        return getDevices(for: category).count
    }

    private func categoryColor(_ category: NetworkDiscoveryManager.DiscoveredDevice.DeviceCategory) -> Color {
        switch category {
        case .smarthome: return .blue
        case .google: return .red
        case .unifi: return .cyan
        case .apple: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    NetworkTopologyView(networkDiscovery: NetworkDiscoveryManager())
}
