//
//  ContentView.swift
//  HomeKitAdopter - tvOS Network Scanner
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI
import HomeKit

/// Main content view with tab-based navigation
///
/// This view provides the primary navigation structure for the app:
/// - Scanner: Main device discovery and listing
/// - Dashboard: Statistics and insights
/// - Tools: Additional utilities (Export, Security, Diagnostics)
/// - More: Settings and advanced features
struct ContentView: View {
    @StateObject private var networkDiscovery = NetworkDiscoveryManager()
    @StateObject private var homeManager = HomeManagerWrapper.shared
    @State private var selectedTab = 0

    var body: some View {
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
        .onAppear {
            // Set the network discovery manager reference in scan scheduler
            ScanSchedulerManager.shared.setNetworkDiscoveryManager(networkDiscovery)
        }
    }
}

#Preview {
    ContentView()
}
