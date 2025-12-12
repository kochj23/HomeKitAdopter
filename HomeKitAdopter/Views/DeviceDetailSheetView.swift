//
//  DeviceDetailSheetView.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Full device detail sheet view
struct DeviceDetailSheetView: View {
    let device: NetworkDiscoveryManager.DiscoveredDevice
    let networkDiscovery: NetworkDiscoveryManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        let (confidence, reasons) = networkDiscovery.calculateConfidenceAndRecordHistory(for: device)
        let confidenceColor = confidence >= 70 ? Color.green : confidence >= 40 ? Color.yellow : Color.red

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Device Header
                    HStack {
                        Image(systemName: device.serviceType.icon)
                            .font(.system(size: 60))
                            .foregroundColor(confidenceColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.title)
                                .bold()

                            if let manufacturer = device.manufacturer {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                    Text(manufacturer)
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }

                            Text(device.serviceType.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)

                    // Key Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Device Information")
                            .font(.headline)

                        if let host = device.host {
                            DetailRow(label: "IP Address", value: host, icon: "network")
                        }

                        if let macAddress = device.macAddress {
                            DetailRow(label: "MAC Address", value: macAddress, icon: "rectangle.connected.to.line.below")
                        }

                        if let port = device.port {
                            DetailRow(label: "Port", value: "\(port)", icon: "antenna.radiowaves.left.and.right")
                        }

                        DetailRow(label: "Protocol", value: device.serviceType.displayName, icon: "link.circle")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                    // Confidence Analysis
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detection Analysis")
                            .font(.headline)

                        HStack {
                            Circle()
                                .fill(confidenceColor)
                                .frame(width: 12, height: 12)
                            Text("\(confidence)% Confident Unadopted")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(confidenceColor)
                        }

                        ForEach(Array(reasons.enumerated()), id: \.offset) { _, reason in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(reason)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                    // TXT Records
                    if !device.txtRecords.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TXT Records")
                                .font(.headline)

                            ForEach(Array(device.txtRecords.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                HStack {
                                    Text(key)
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(value.isEmpty ? "(empty)" : value)
                                        .font(.caption)
                                }
                                Divider()
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(40)
            }
            .navigationTitle("Device Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .bold()
                .font(.system(.subheadline, design: .monospaced))
        }
    }
}
