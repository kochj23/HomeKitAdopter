//
//  HomeKitAdopterApp.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-21.
//  Updated: 2026-01-31 - Version 4.3 - Added iOS/iPad support
//  Copyright © 2025-2026 Jordan Koch. All rights reserved.
//

import SwiftUI

/// Main application entry point for HomeKit Adopter
///
/// This application provides a solution for managing HomeKit accessories
/// on Apple TV and iPad. Features include:
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
/// - iOS 16.0+ (iPad - optimized for large screens)
///
/// # Platform-Specific Features:
/// ## tvOS:
/// - Optimized for 10-foot viewing experience
/// - Siri Remote navigation with focus engine
/// - HMAccessoryBrowser NOT available (use iOS Home app to pair)
///
/// ## iOS (iPad):
/// - Touch-optimized interface
/// - HMAccessoryBrowser available for direct pairing
/// - Camera/QR code scanning for setup codes
/// - Split-screen and multitasking support
///
/// # Security Features:
/// - All operations use HomeKit's secure protocol
/// - Setup codes are never stored or logged
/// - Network communication is encrypted via HomeKit framework
///
/// # Usage:
/// 1. Launch the app on Apple TV or iPad
/// 2. Grant HomeKit permissions when prompted
/// 3. View and manage accessories
/// 4. On iPad: Can pair new accessories directly
/// 5. On tvOS: Use iPhone/iPad Home app to pair new accessories
@main
struct HomeKitAdopterApp: App {
    /// Initialize logging system on app launch
    init() {
        let platform = PlatformConstants.isTV ? "tvOS (Apple TV)" : (PlatformConstants.isiPad ? "iPadOS" : "iOS")
        LoggingManager.shared.log("HomeKitAdopter v4.3 launched on \(platform)", level: .info)

        if PlatformConstants.isTV {
            LoggingManager.shared.log("Apple TV device detected - full network scanning capabilities", level: .info)
        } else if PlatformConstants.isiPad {
            LoggingManager.shared.log("iPad detected - touch interface with accessory pairing support", level: .info)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(tvOS)
                .preferredColorScheme(.dark) // tvOS typically uses dark mode
                #endif
        }
    }
}
