//
//  HomeKitAdopterApp.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-21.
//  Updated: 2026-01-28 - Version 4.2
//  Copyright © 2025-2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Main application entry point for HomeKit Adopter tvOS Edition
///
/// This tvOS application provides a solution for managing HomeKit accessories
/// on Apple TV. Features include:
/// - Network device discovery via Bonjour/mDNS
/// - Port scanning and ARP scanning
/// - Ping monitoring and latency testing
/// - Security audit and vulnerability detection
/// - Device history and change tracking
/// - Export to CSV/JSON formats
/// - Dashboard with real-time statistics
///
/// # Platform Support:
/// - tvOS 16.0+ (Apple TV HD and Apple TV 4K)
///
/// # tvOS Limitations:
/// - HMAccessoryBrowser is NOT available on tvOS
/// - New accessories must be paired via iOS Home app first
/// - Camera/QR code scanning not available (no camera on Apple TV)
/// - Discovery shows paired accessories and HAP services (informational)
///
/// # Security Features:
/// - All operations use HomeKit's secure protocol
/// - Setup codes are never stored or logged
/// - Network communication is encrypted via HomeKit framework
///
/// # Usage:
/// 1. Launch the app on Apple TV
/// 2. Grant HomeKit permissions when prompted
/// 3. View accessories already paired via iOS
/// 4. To add new accessories, use iPhone/iPad Home app
/// 5. Manage homes and rooms from Apple TV
@main
struct HomeKitAdopterApp: App {
    /// Initialize logging system on app launch
    init() {
        LoggingManager.shared.log("HomeKitAdopter v4.2 launched on tvOS", level: .info)
        LoggingManager.shared.log("Apple TV device detected - full network scanning capabilities", level: .info)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // tvOS typically uses dark mode
        }
    }
}
