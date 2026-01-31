//
//  PlatformHelpers.swift
//  HomeKitAdopter
//
//  Platform-specific helpers for tvOS and iOS (iPad)
//  Created by Jordan Koch on 2025-11-21.
//  Updated: 2026-01-31 - Version 4.3 - Added iOS/iPad support
//  Copyright © 2025-2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - Platform Type Aliases

/// Platform-specific color type - UIColor on tvOS/iOS
typealias PlatformColor = UIColor
typealias PlatformApplication = UIApplication

// MARK: - Platform Detection

#if os(tvOS)
private let _isTV = true
private let _isiOS = false
#elseif os(iOS)
private let _isTV = false
private let _isiOS = true
#else
private let _isTV = false
private let _isiOS = false
#endif

// MARK: - Platform Constants

struct PlatformConstants {
    /// Is the current platform a TV?
    static let isTV: Bool = _isTV

    /// Is the current platform a Mac?
    static let isMac: Bool = false

    /// Is the current platform iOS (iPhone/iPad)?
    static let isiOS: Bool = _isiOS

    /// Is the current platform iPad specifically?
    static var isiPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    /// Minimum card width - larger on tvOS for 10-foot viewing
    static var minCardWidth: CGFloat {
        isTV ? 400 : (isiPad ? 300 : 160)
    }

    /// Padding for list items - larger on tvOS
    static var listItemPadding: CGFloat {
        isTV ? 24 : 16
    }

    /// Font size for headers - larger on tvOS
    static var headerFontSize: CGFloat {
        isTV ? 52 : (isiPad ? 34 : 28)
    }

    /// Icon size for accessories - larger on tvOS
    static var accessoryIconSize: CGFloat {
        isTV ? 80 : (isiPad ? 60 : 44)
    }

    /// Corner radius for cards
    static var cardCornerRadius: CGFloat {
        isTV ? 20 : 12
    }

    /// Grid column count based on platform
    static var gridColumns: Int {
        isTV ? 4 : (isiPad ? 3 : 2)
    }
}

// MARK: - Platform-Specific View Modifiers

extension View {
    /// Apply platform-specific styling for control background
    func platformControlBackground() -> some View {
        #if os(tvOS)
        return self.background(Color(UIColor.darkGray))
        #else
        return self.background(Color(UIColor.secondarySystemBackground))
        #endif
    }

    /// Apply platform-specific grouped background
    func platformGroupedBackground() -> some View {
        #if os(tvOS)
        return self.background(Color.black)
        #else
        return self.background(Color(UIColor.systemGroupedBackground))
        #endif
    }

    /// Apply focus-friendly styling for tvOS, regular styling for iOS
    @ViewBuilder
    func tvOSFocusable(_ enabled: Bool = true) -> some View {
        #if os(tvOS)
        self.focusable(enabled)
            .buttonStyle(.card)
        #else
        self
        #endif
    }

    /// Platform-adaptive card style
    @ViewBuilder
    func platformCardStyle() -> some View {
        #if os(tvOS)
        self.buttonStyle(.card)
        #else
        self
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(PlatformConstants.cardCornerRadius)
        #endif
    }

    /// No-op for tvOS/iOS (was macOS-specific)
    @ViewBuilder
    func macOSFrame(minWidth: CGFloat? = nil, minHeight: CGFloat? = nil) -> some View {
        self
    }

    /// Apply navigation style based on platform
    @ViewBuilder
    func platformNavigationStyle() -> some View {
        #if os(iOS)
        if PlatformConstants.isiPad {
            self.navigationViewStyle(.columns)
        } else {
            self.navigationViewStyle(.stack)
        }
        #else
        self
        #endif
    }
}

// MARK: - Platform-Specific UI Utilities

struct PlatformUI {
    /// Open system preferences/settings for the app
    static func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        // tvOS doesn't support opening settings programmatically
        LoggingManager.shared.warning("Cannot open settings on tvOS")
        #endif
    }

    /// Get control background color
    static var controlBackgroundColor: Color {
        #if os(tvOS)
        return Color(UIColor.darkGray)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }

    /// Get appropriate font for platform
    static func adaptiveFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = PlatformConstants.isTV ? size * 1.5 : size
        return .system(size: scaledSize, weight: weight)
    }
}

// MARK: - Platform Availability Helpers

/// Check if camera is available on this platform
let isCameraAvailable: Bool = {
    #if os(iOS)
    return UIImagePickerController.isSourceTypeAvailable(.camera)
    #else
    return false // tvOS has no camera
    #endif
}()

/// Check if this platform supports focus engine (tvOS only)
let supportsFocusEngine: Bool = _isTV

/// Check if this platform supports HMAccessoryBrowser (iOS only, not tvOS)
let supportsAccessoryBrowser: Bool = _isiOS

// MARK: - Adaptive Grid Layout

struct AdaptiveGrid {
    /// Create grid columns appropriate for current platform
    static var columns: [GridItem] {
        let count = PlatformConstants.gridColumns
        return Array(repeating: GridItem(.flexible(), spacing: PlatformConstants.listItemPadding), count: count)
    }

    /// Create adaptive grid columns for a specific count
    static func columns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: PlatformConstants.listItemPadding), count: count)
    }
}
