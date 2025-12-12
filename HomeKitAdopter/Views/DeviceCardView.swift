//
//  DeviceCardView.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Reusable device card component
struct DeviceCardView: View {
    let device: NetworkDiscoveryManager.DiscoveredDevice
    let networkDiscovery: NetworkDiscoveryManager
    let onTap: () -> Void

    var body: some View {
        // PERFORMANCE FIX: Use cached confidence instead of recalculating on every render
        let (confidence, _) = networkDiscovery.getCachedConfidence(for: device)
        let confidenceColor = confidence >= 70 ? Color.green : confidence >= 40 ? Color.yellow : Color.red

        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 9) {
                // Header
                HStack {
                    Image(systemName: device.serviceType.icon)
                        .font(.system(size: 24))
                        .foregroundColor(confidenceColor)
                        .frame(width: 38, height: 38)
                        .background(confidenceColor.opacity(0.2))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        if let manufacturer = device.manufacturer {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(.caption2)
                                Text(manufacturer)
                                    .font(.caption)
                                    .bold()
                            }
                            .foregroundColor(.blue)
                        }

                        Text(device.serviceType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if confidence >= 50 {
                        VStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(confidenceColor)
                            Text("UNADOPTED")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(confidenceColor)
                        }
                    }
                }

                Divider()

                // Key Info
                VStack(alignment: .leading, spacing: 8) {
                    if let host = device.host {
                        InfoRow(icon: "network", label: "IP", value: host, color: .blue)
                    }

                    if let macAddress = device.macAddress {
                        InfoRow(icon: "rectangle.connected.to.line.below", label: "MAC", value: macAddress, color: .purple)
                    }
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(9)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(confidence >= 50 ? confidenceColor : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .bold()
                    .font(.system(.subheadline, design: .monospaced))
            }
        }
    }
}
