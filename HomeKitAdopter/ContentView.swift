//
//  ContentView.swift
//  HomeKitAdopter - tvOS Network Scanner
//
//  Created by Jordan Koch on 2025-11-22.
//  Updated: 2026-01-28 - Version 4.2
//  Copyright © 2025-2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import HomeKit

/// Main content view with tab-based navigation
///
/// This view provides the primary navigation structure for the app:
/// - Initial Launch: Shows splash screen with automatic network scan
/// - Scanner: Main device discovery and listing
/// - Dashboard: Statistics and insights
/// - Tools: Additional utilities (Export, Security, Diagnostics)
/// - More: Settings and advanced features
struct ContentView: View {
    @StateObject private var networkDiscovery = NetworkDiscoveryManager()
    @StateObject private var homeManager = HomeManagerWrapper.shared
    @State private var selectedTab = 0
    @State private var showingSplash = true
    @State private var scanProgress: Double = 0.0
    @State private var scanTimer: Timer?

    var body: some View {
        ZStack {
            // Glassmorphic background
            GlassmorphicBackground()

            // Main App Interface
            TabView(selection: $selectedTab) {
                // Main Scanner Tab
                ScannerView(networkDiscovery: networkDiscovery)
                    .tabItem {
                        Label("Scanner", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tag(0)

                // Dashboard Tab
                DashboardView(networkDiscovery: networkDiscovery)
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.fill")
                    }
                    .tag(1)

                // Tools Tab
                ToolsView(networkDiscovery: networkDiscovery)
                    .tabItem {
                        Label("Tools", systemImage: "wrench.and.screwdriver.fill")
                    }
                    .tag(2)

                // More Tab
                MoreView(networkDiscovery: networkDiscovery)
                    .tabItem {
                        Label("More", systemImage: "ellipsis.circle.fill")
                    }
                    .tag(3)
            }
            .opacity(showingSplash ? 0 : 1)

            // Launch Splash Screen with Initial Scan
            if showingSplash {
                InitialScanSplashView(
                    progress: $scanProgress,
                    deviceCount: networkDiscovery.discoveredDevices.count
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            startInitialScan()
        }
    }

    private func startInitialScan() {
        // Set the network discovery manager reference in scan scheduler
        ScanSchedulerManager.shared.setNetworkDiscoveryManager(networkDiscovery)

        // Start the network scan
        networkDiscovery.startDiscovery()
        LoggingManager.shared.info("Initial network scan started on app launch")

        // Simulate progress over 30 seconds (standard scan duration)
        let scanDuration: Double = 30.0
        let updateInterval: Double = 0.1 // Update every 100ms
        let totalSteps = scanDuration / updateInterval
        var currentStep: Double = 0

        scanTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            currentStep += 1
            scanProgress = currentStep / totalSteps

            // Complete splash after scan finishes
            if currentStep >= totalSteps {
                timer.invalidate()
                withAnimation(.easeOut(duration: 0.5)) {
                    showingSplash = false
                }
                LoggingManager.shared.info("Initial network scan completed, showing main interface")
            }
        }
    }
}

/// Initial launch splash screen with network scanning progress
struct InitialScanSplashView: View {
    @Binding var progress: Double
    let deviceCount: Int

    var body: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Icon/Logo Area
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 120))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                VStack(spacing: 16) {
                    Text("HomeKit Adopter")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Scanning Network for Devices")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }

                // Progress Section
                VStack(spacing: 24) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 24)

                            // Progress Fill
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green, Color.cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 24)
                                .animation(.linear(duration: 0.1), value: progress)
                        }
                    }
                    .frame(width: 600, height: 24)

                    // Progress Text
                    HStack(spacing: 40) {
                        Text("\(Int(progress * 100))% Complete")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)

                        if deviceCount > 0 {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                Text("\(deviceCount) device\(deviceCount == 1 ? "" : "s") found")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    // Scanning Info
                    Text("Scanning local network (192.168.x.x/24) for HomeKit and Matter devices")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)
                }

                Spacer()

                // Footer
                Text("Powered by Bonjour/mDNS Discovery")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    ContentView()
}
