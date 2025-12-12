//
//  DeviceComparisonView.swift
//  HomeKitAdopter - Side-by-Side Device Comparison
//
//  Created by Jordan Koch on 2025-11-21.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI
import HomeKit

/// Side-by-side comparison of discovered device vs adopted accessory
///
/// Allows user to confirm if a discovered device matches an adopted
/// accessory, helping to train the matching algorithm and reduce
/// false positives in unadopted device detection.
struct DeviceComparisonView: View {
    let discoveredDevice: NetworkDiscoveryManager.DiscoveredDevice
    let possibleMatch: HMAccessory
    let similarity: Double
    let onConfirmSame: () -> Void
    let onConfirmDifferent: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Are These the Same Device?")
                            .font(.title2)
                            .bold()

                        Text("Help us improve device detection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    // Comparison cards
                    HStack(spacing: 20) {
                        // Discovered device
                        deviceCard(
                            title: "Discovered Device",
                            icon: discoveredDevice.serviceType.icon,
                            iconColor: .blue,
                            backgroundColor: .blue,
                            content: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(discoveredDevice.name)
                                        .font(.title3)
                                        .bold()

                                    HStack(spacing: 6) {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .font(.caption)
                                        Text(discoveredDevice.serviceType.displayName)
                                            .font(.caption)
                                    }

                                    if let host = discoveredDevice.host {
                                        HStack(spacing: 6) {
                                            Image(systemName: "network")
                                                .font(.caption)
                                            Text("IP: \(host)")
                                                .font(.caption)
                                        }
                                    }

                                    if let port = discoveredDevice.port {
                                        HStack(spacing: 6) {
                                            Image(systemName: "dot.radiowaves.left.and.right")
                                                .font(.caption)
                                            Text("Port: \(port)")
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        )

                        // Adopted accessory
                        deviceCard(
                            title: "Adopted Accessory",
                            icon: "checkmark.circle.fill",
                            iconColor: .green,
                            backgroundColor: .green,
                            content: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(possibleMatch.name)
                                        .font(.title3)
                                        .bold()

                                    HStack(spacing: 6) {
                                        Image(systemName: "house.fill")
                                            .font(.caption)
                                        Text(possibleMatch.room?.name ?? "No room")
                                            .font(.caption)
                                    }

                                    HStack(spacing: 6) {
                                        Image(systemName: possibleMatch.isReachable ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                            .font(.caption)
                                        Text(possibleMatch.isReachable ? "Reachable" : "Not reachable")
                                            .font(.caption)
                                    }

                                    HStack(spacing: 6) {
                                        Image(systemName: "tag")
                                            .font(.caption)
                                        Text(possibleMatch.category.localizedDescription)
                                            .font(.caption)
                                    }
                                }
                            }
                        )
                    }

                    // Similarity indicator
                    VStack(spacing: 12) {
                        Text("\(Int(similarity * 100))% Name Similarity")
                            .font(.headline)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 20)

                                // Progress
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(similarityColor)
                                    .frame(width: geometry.size.width * similarity, height: 20)
                            }
                        }
                        .frame(height: 20)

                        Text(similarityDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                    // Decision buttons
                    VStack(spacing: 16) {
                        Text("Your Feedback Helps Improve Detection")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 20) {
                            Button(action: {
                                onConfirmDifferent()
                                dismiss()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 40))
                                    Text("Different Devices")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                
                            Button(action: {
                                onConfirmSame()
                                dismiss()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 40))
                                    Text("Same Device")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                            }
                                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Device Comparison")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }

    // MARK: - Helper Views

    private func deviceCard<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        backgroundColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
            }

            Divider()

            // Content
            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(backgroundColor.opacity(0.3), lineWidth: 2)
        )
    }

    private var similarityColor: Color {
        if similarity > 0.85 {
            return .green
        } else if similarity > 0.6 {
            return .yellow
        } else {
            return .red
        }
    }

    private var similarityDescription: String {
        if similarity > 0.85 {
            return "Very high similarity - likely the same device"
        } else if similarity > 0.6 {
            return "Moderate similarity - possibly the same device"
        } else {
            return "Low similarity - likely different devices"
        }
    }
}
