//
//  AppTheme.swift
//  HomeKitAdopter - Modern UI Theme System
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

/// World-class theme system with glass morphism and modern design
@MainActor
final class AppTheme: ObservableObject {
    static let shared = AppTheme()

    // MARK: - Color Palette

    struct Colors {
        // Primary Colors
        static let primary = Color(red: 0.0, green: 0.48, blue: 1.0) // Vibrant Blue
        static let secondary = Color(red: 0.35, green: 0.34, blue: 0.84) // Deep Purple
        static let accent = Color(red: 0.0, green: 0.78, blue: 0.75) // Teal

        // Status Colors
        static let success = Color(red: 0.2, green: 0.78, blue: 0.35) // Green
        static let warning = Color(red: 1.0, green: 0.58, blue: 0.0) // Orange
        static let error = Color(red: 1.0, green: 0.23, blue: 0.19) // Red
        static let info = Color(red: 0.35, green: 0.78, blue: 0.98) // Light Blue

        // Glassmorphism
        static let glassBackground = Color.white.opacity(0.1)
        static let glassStroke = Color.white.opacity(0.2)
        static let glassShadow = Color.black.opacity(0.1)

        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accentGradient = LinearGradient(
            colors: [accent, primary],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let warmGradient = LinearGradient(
            colors: [Color.orange, Color.pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let coolGradient = LinearGradient(
            colors: [Color.cyan, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Background Colors
        static let backgroundPrimary = Color(red: 0.05, green: 0.05, blue: 0.08)
        static let backgroundSecondary = Color(red: 0.1, green: 0.1, blue: 0.15)
        static let backgroundTertiary = Color(red: 0.15, green: 0.15, blue: 0.2)

        // Text Colors
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textTertiary = Color.white.opacity(0.5)
    }

    // MARK: - Typography

    struct Typography {
        static let largeTitle = Font.system(size: 52, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 42, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 36, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 30, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 26, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 22, weight: .regular, design: .rounded)
        static let callout = Font.system(size: 20, weight: .regular, design: .rounded)
        static let subheadline = Font.system(size: 18, weight: .medium, design: .rounded)
        static let footnote = Font.system(size: 16, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 14, weight: .regular, design: .rounded)
        static let caption2 = Font.system(size: 12, weight: .regular, design: .rounded)
    }

    // MARK: - Spacing

    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let full: CGFloat = 1000
    }

    // MARK: - Shadows

    struct Shadows {
        static let small = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.15)
        static let large = Color.black.opacity(0.25)

        static func elevation(_ level: Int) -> some View {
            return Group {
                EmptyView()
            }
        }
    }

    // MARK: - Animations

    struct Animations {
        static let quick = Animation.easeOut(duration: 0.2)
        static let standard = Animation.easeInOut(duration: 0.3)
        static let slow = Animation.easeInOut(duration: 0.5)
        static let spring = Animation.spring(response: 0.4, dampingFraction: 0.7)
        static let bounce = Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply glassmorphism effect
    func glassEffect() -> some View {
        self
            .background(AppTheme.Colors.glassBackground)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(AppTheme.Colors.glassStroke, lineWidth: 1)
            )
            .shadow(color: AppTheme.Colors.glassShadow, radius: 20, x: 0, y: 10)
    }

    /// Apply card style
    func cardStyle() -> some View {
        self
            .background(AppTheme.Colors.backgroundSecondary)
            .cornerRadius(AppTheme.CornerRadius.lg)
            .shadow(color: AppTheme.Shadows.medium, radius: 10, x: 0, y: 5)
    }

    /// Apply gradient background
    func gradientBackground(_ gradient: LinearGradient = AppTheme.Colors.primaryGradient) -> some View {
        self
            .background(gradient)
    }

    /// Shimmering effect for loading states
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }

    /// Pulsing animation
    func pulse() -> some View {
        self.modifier(PulseModifier())
    }

    /// Slide in animation
    func slideIn(from edge: Edge = .bottom, delay: Double = 0) -> some View {
        self.modifier(SlideInModifier(edge: edge, delay: delay))
    }
}

// MARK: - Custom Modifiers

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: phase),
                                    .init(color: .clear, location: phase + 0.2)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            )
    }
}

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

struct SlideInModifier: ViewModifier {
    let edge: Edge
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .offset(
                x: !isVisible && (edge == .leading || edge == .trailing) ? (edge == .leading ? -300 : 300) : 0,
                y: !isVisible && (edge == .top || edge == .bottom) ? (edge == .top ? -300 : 300) : 0
            )
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(AppTheme.Animations.spring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}
