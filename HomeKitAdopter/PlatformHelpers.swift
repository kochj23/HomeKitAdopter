//
//  PlatformHelpers.swift
//  HomeKitAdopter
//
//  Platform-specific helpers for tvOS
//  Created by Jordan Koch on 2025-11-21.
//  Updated: 2026-01-28 - Version 4.2
//  Copyright © 2025-2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - Platform Type Aliases for tvOS

/// Platform-specific color type - UIColor on tvOS
typealias PlatformColor = UIColor
typealias PlatformApplication = UIApplication

// MARK: - Platform Constants

struct PlatformConstants {
    /// Is the current platform a TV? - Always true for this tvOS-only app
    static let isTV: Bool = true

    /// Is the current platform a Mac? - Always false for tvOS
    static let isMac: Bool = false

    /// Is the current platform iOS? - Always false for tvOS
    static let isiOS: Bool = false

    /// Minimum card width for tvOS
    static let minCardWidth: CGFloat = 400

    /// Padding for list items on tvOS
    static let listItemPadding: CGFloat = 24

    /// Font size for headers on tvOS
    static let headerFontSize: CGFloat = 52

    /// Icon size for accessories on tvOS
    static let accessoryIconSize: CGFloat = 80
}

// MARK: - Platform-Specific View Modifiers

extension View {
    /// Apply platform-specific styling for control background
    func platformControlBackground() -> some View {
        self.background(Color(UIColor.darkGray))
    }

    /// Apply platform-specific grouped background
    func platformGroupedBackground() -> some View {
        self.background(Color.black)
    }

    /// Apply focus-friendly styling for tvOS
    @ViewBuilder
    func tvOSFocusable(_ enabled: Bool = true) -> some View {
        self.focusable(enabled)
            .buttonStyle(.card)
    }

    /// No-op for tvOS (was macOS-specific)
    @ViewBuilder
    func macOSFrame(minWidth: CGFloat? = nil, minHeight: CGFloat? = nil) -> some View {
        self
    }
}

// MARK: - Platform-Specific UI Utilities

struct PlatformUI {
    /// Open system preferences/settings for the app
    static func openAppSettings() {
        // tvOS doesn't support opening settings programmatically
        LoggingManager.shared.warning("Cannot open settings on tvOS")
    }

    /// Get control background color
    static var controlBackgroundColor: Color {
        return Color(UIColor.darkGray)
    }
}

// MARK: - Platform Availability Helpers

/// Check if camera is available on this platform - Always false on tvOS
let isCameraAvailable: Bool = false

/// Check if this platform supports focus engine - Always true on tvOS
let supportsFocusEngine: Bool = true
