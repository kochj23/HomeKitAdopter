//
//  HomeManagerWrapper.swift
//  HomeKitAdopter - tvOS Edition
//
//  Created by Jordan Koch on 2025-11-21.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import HomeKit
import Combine

/// Wrapper for HMHomeManager providing read-only home access for tvOS
///
/// tvOS LIMITATIONS:
/// - Cannot add/remove homes (HMHomeManager.addHome unavailable on tvOS)
/// - Cannot add/remove rooms (HMHome.addRoom unavailable on tvOS)
/// - Cannot assign accessories (HMHome.assignAccessory unavailable on tvOS)
/// - Can only VIEW and CONTROL existing accessories
///
/// This class manages the user's HomeKit homes for viewing only:
/// - Read existing homes
/// - Access primary home
/// - View accessories and rooms
/// - Control accessories (via accessory services)
///
/// # Architecture:
/// - Uses Combine for reactive state updates
/// - Thread-safe through main actor isolation
/// - Singleton pattern for global home state
///
/// # Memory Management:
/// - Uses [weak self] in all closures to prevent retain cycles
/// - Properly removes observers in deinit
/// - No strong reference cycles with HMHomeManager
///
/// # Usage:
/// ```swift
/// let wrapper = HomeManagerWrapper.shared
/// let homes = wrapper.homes
/// let primary = wrapper.primaryHome
/// ```
@MainActor
final class HomeManagerWrapper: NSObject, ObservableObject {
    /// Shared singleton instance
    static let shared = HomeManagerWrapper()

    /// The underlying HomeKit home manager
    private var homeManager: HMHomeManager!

    /// Published array of available homes
    @Published private(set) var homes: [HMHome] = []

    /// Published primary home
    @Published private(set) var primaryHome: HMHome?

    /// Published flag indicating if HomeKit is ready
    @Published private(set) var isReady: Bool = false

    /// Published error messages
    @Published var errorMessage: String?

    /// Cancellable set for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Private initializer for singleton pattern
    private override init() {
        super.init()

        // Initialize home manager
        homeManager = HMHomeManager()
        homeManager.delegate = self

        LoggingManager.shared.info("HomeManagerWrapper initialized for tvOS (read-only mode)")
    }

    /// Clean up resources
    deinit {
        cancellables.removeAll()
        homeManager.delegate = nil
        LoggingManager.shared.info("HomeManagerWrapper deinitialized")
    }

    // MARK: - Read-Only Access Methods

    /// Get default home for initial selection
    ///
    /// Returns the primary home if set, otherwise the first available home
    ///
    /// - Returns: The default home, or nil if no homes exist
    func getDefaultHome() -> HMHome? {
        return primaryHome ?? homes.first
    }

    /// Get accessories in a specific home
    ///
    /// - Parameter home: The home to get accessories from
    /// - Returns: Array of accessories in the home
    func getAccessories(in home: HMHome) -> [HMAccessory] {
        return home.accessories
    }

    /// Get rooms in a specific home
    ///
    /// - Parameter home: The home to get rooms from
    /// - Returns: Array of rooms in the home
    func getRooms(in home: HMHome) -> [HMRoom] {
        return home.rooms
    }

    /// Get accessories in a specific room
    ///
    /// - Parameters:
    ///   - room: The room to get accessories from
    ///   - home: The home containing the room
    /// - Returns: Array of accessories in the room
    func getAccessories(in room: HMRoom, home: HMHome) -> [HMAccessory] {
        return home.accessories.filter { $0.room?.uniqueIdentifier == room.uniqueIdentifier }
    }

    /// Refresh home data from HomeKit
    ///
    /// Forces a refresh of the home data. This is useful after
    /// making changes via the iOS Home app.
    func refresh() {
        LoggingManager.shared.info("Refreshing home data")
        updateHomes()
    }

    // MARK: - Private Helper Methods

    /// Update homes array from home manager
    private func updateHomes() {
        homes = homeManager.homes
        primaryHome = homeManager.primaryHome

        LoggingManager.shared.info("Homes updated: \(homes.count) homes, primary: \(primaryHome?.name ?? "none")")
    }
}

// MARK: - HMHomeManagerDelegate

extension HomeManagerWrapper: HMHomeManagerDelegate {
    /// Called when HomeKit is ready
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            if !self.isReady {
                LoggingManager.shared.info("HomeKit ready")
                self.isReady = true
            }

            self.updateHomes()
        }
    }

    /// Called when primary home changes
    nonisolated func homeManagerDidUpdatePrimaryHome(_ manager: HMHomeManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.primaryHome = manager.primaryHome
            LoggingManager.shared.info("Primary home updated: \(manager.primaryHome?.name ?? "none")")
        }
    }

    /// Called when a home is added (via iOS app)
    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            LoggingManager.shared.info("Home added externally: \(home.name)")
            self.updateHomes()
        }
    }

    /// Called when a home is removed (via iOS app)
    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            LoggingManager.shared.info("Home removed externally: \(home.name)")
            self.updateHomes()
        }
    }
}

// MARK: - tvOS Compatibility Notes

/*
 tvOS HomeKit API Limitations:

 The following APIs are NOT available on tvOS:

 1. Home Management:
    - HMHomeManager.addHome(withName:completionHandler:) - UNAVAILABLE
    - HMHomeManager.removeHome(_:completionHandler:) - UNAVAILABLE
    - HMHomeManager.updatePrimaryHome(_:completionHandler:) - May be unavailable

 2. Room Management:
    - HMHome.addRoom(withName:completionHandler:) - UNAVAILABLE
    - HMHome.removeRoom(_:completionHandler:) - UNAVAILABLE
    - HMHome.assignAccessory(_:to:completionHandler:) - UNAVAILABLE

 3. Accessory Discovery & Pairing:
    - HMAccessoryBrowser - UNAVAILABLE (entire class)
    - HMHome.addAccessory(_:completionHandler:) - UNAVAILABLE
    - HMHome.removeAccessory(_:completionHandler:) - UNAVAILABLE

 4. Camera/QR Code:
    - AVCaptureDevice - Limited availability on tvOS
    - QR code scanning not practical on TV

 What DOES work on tvOS:

 1. Viewing:
    - HMHomeManager.homes - Read existing homes
    - HMHome.accessories - Read accessories
    - HMHome.rooms - Read rooms
    - HMAccessory properties - Read accessory state

 2. Control:
    - HMAccessory.services - Access services
    - HMService.characteristics - Read/write characteristics
    - Controlling lights, switches, thermostats, etc.

 3. Monitoring:
    - Delegate callbacks for state changes
    - Accessory reachability
    - Characteristic value updates

 Apple's Design Intent:

 tvOS is designed for CONTROL, not CONFIGURATION. Users should:
 1. Use iOS Home app to add/configure accessories
 2. Use tvOS apps to view and control existing accessories
 3. Both platforms share the same HomeKit database via iCloud

 This design makes sense because:
 - Setup requires cameras (for QR codes) and keyboards (for codes)
 - Configuration UIs are easier on touchscreens
 - Apple TV is primarily for consumption, not setup
 */
