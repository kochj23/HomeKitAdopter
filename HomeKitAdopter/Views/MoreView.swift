//
//  MoreView.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// More view with additional features in grid menu
struct MoreView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 20) {
                    Text("More")
                        .font(.system(size: 52, weight: .bold))
                        .padding(.horizontal, 40)
                        .padding(.top, 30)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: 4), spacing: 30) {
                        // HomeKit Browser - NEW!
                        NavigationLink(destination: HomeKitBrowserView()) {
                            MoreMenuItem(
                                title: "HomeKit Browser",
                                icon: "house.and.flag.fill",
                                description: "View all HomeKit accessories",
                                color: .green
                            )
                        }
                        .buttonStyle(.plain)

                        // Scan Scheduler
                        NavigationLink(destination: ScanSchedulerView()) {
                            MoreMenuItem(
                                title: "Scan Scheduler",
                                icon: "calendar.badge.clock",
                                description: "Automated network scanning",
                                color: .blue
                            )
                        }
                        .buttonStyle(.plain)

                        // QR Code Generator
                        NavigationLink(destination: QRCodeListView(networkDiscovery: networkDiscovery)) {
                            MoreMenuItem(
                                title: "QR Codes",
                                icon: "qrcode",
                                description: "View pairing QR codes",
                                color: .green
                            )
                        }
                        .buttonStyle(.plain)

                        // Pairing Instructions
                        NavigationLink(destination: PairingInstructionsListView()) {
                            MoreMenuItem(
                                title: "Pairing Guides",
                                icon: "book.fill",
                                description: "Device-specific instructions",
                                color: .orange
                            )
                        }
                        .buttonStyle(.plain)

                        // Device Notes
                        NavigationLink(destination: DeviceNotesListView()) {
                            MoreMenuItem(
                                title: "Device Notes",
                                icon: "note.text",
                                description: "Add notes and tags",
                                color: .yellow
                            )
                        }
                        .buttonStyle(.plain)

                        // Multi-Home Manager
                        NavigationLink(destination: MultiHomeView()) {
                            MoreMenuItem(
                                title: "Multi-Home",
                                icon: "house.and.flag.fill",
                                description: "Manage multiple homes",
                                color: .purple
                            )
                        }
                        .buttonStyle(.plain)

                        // Privacy Settings
                        NavigationLink(destination: PrivacySettingsView()) {
                            MoreMenuItem(
                                title: "Privacy",
                                icon: "hand.raised.fill",
                                description: "Data protection options",
                                color: .red
                            )
                        }
                        .buttonStyle(.plain)

                        // Logs Viewer
                        NavigationLink(destination: LogsViewerView()) {
                            MoreMenuItem(
                                title: "Logs",
                                icon: "doc.text.magnifyingglass",
                                description: "View system logs",
                                color: .gray
                            )
                        }
                        .buttonStyle(.plain)

                        // Settings
                        NavigationLink(destination: SettingsView()) {
                            MoreMenuItem(
                                title: "Settings",
                                icon: "gearshape.fill",
                                description: "App preferences",
                                color: .blue
                            )
                        }
                        .buttonStyle(.plain)

                        // About
                        NavigationLink(destination: AboutView()) {
                            MoreMenuItem(
                                title: "About",
                                icon: "info.circle.fill",
                                description: "App info and credits",
                                color: .cyan
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
    }
}

/// Reusable more menu item card
struct MoreMenuItem: View {
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
