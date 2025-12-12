//
//  HomeKitBrowserView.swift
//  HomeKitAdopter - View HomeKit Accessories from Apple TV Hub
//
//  Created by Jordan Koch on 2025-11-23.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI
import HomeKit

/// Browse and view all HomeKit accessories accessible from the Apple TV hub
///
/// This view displays all HomeKit homes and accessories that the Apple TV
/// can access as a HomeKit hub. Data is synced via iCloud from the Home app.
struct HomeKitBrowserView: View {
    @StateObject private var homeManager = HomeManagerWrapper.shared
    @State private var selectedHome: HMHome?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("HomeKit Browser")
                        .font(.system(size: 48, weight: .bold))
                    Text("All accessories synced to this Apple TV hub")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                // Status Card
                statusCard

                // Home Selector (if multiple homes)
                if homeManager.homes.count > 1 {
                    homeSelector
                }

                // Accessories List
                if let home = selectedHome ?? homeManager.primaryHome ?? homeManager.homes.first {
                    accessoriesSection(for: home)
                } else if !homeManager.isReady {
                    loadingView
                } else {
                    noHomesView
                }
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            // Set initial home selection
            if selectedHome == nil {
                selectedHome = homeManager.primaryHome ?? homeManager.homes.first
            }
        }
        .onChange(of: homeManager.homes) { newHomes in
            // Update selection if current home is no longer available
            if let selected = selectedHome, !newHomes.contains(where: { $0.uniqueIdentifier == selected.uniqueIdentifier }) {
                selectedHome = homeManager.primaryHome ?? newHomes.first
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 30) {
            // HomeKit Status
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: homeManager.isReady ? "checkmark.circle.fill" : "clock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(homeManager.isReady ? .green : .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("HomeKit Status")
                            .font(.system(size: 20, weight: .semibold))
                        Text(homeManager.isReady ? "Ready" : "Loading...")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color.green.opacity(0.1))
            .cornerRadius(16)

            // Home Count
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(homeManager.homes.count)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.blue)
                        Text(homeManager.homes.count == 1 ? "Home" : "Homes")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(16)

            // Accessory Count
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.purple)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalAccessoryCount)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.purple)
                        Text(totalAccessoryCount == 1 ? "Accessory" : "Accessories")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(16)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Home Selector

    private var homeSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Home")
                .font(.system(size: 28, weight: .bold))
                .padding(.horizontal, 40)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(homeManager.homes, id: \.uniqueIdentifier) { home in
                        Button(action: {
                            selectedHome = home
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: home.uniqueIdentifier == homeManager.primaryHome?.uniqueIdentifier ? "house.fill" : "house")
                                    .font(.system(size: 24))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(home.name)
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("\(home.accessories.count) accessories")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(selectedHome?.uniqueIdentifier == home.uniqueIdentifier ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedHome?.uniqueIdentifier == home.uniqueIdentifier ? .white : .primary)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }

    // MARK: - Accessories Section

    private func accessoriesSection(for home: HMHome) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(home.name)
                    .font(.system(size: 32, weight: .bold))

                if home.uniqueIdentifier == homeManager.primaryHome?.uniqueIdentifier {
                    Text("PRIMARY")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 40)

            if home.accessories.isEmpty {
                emptyAccessoriesView
            } else {
                // Group accessories by room
                let accessoriesByRoom = Dictionary(grouping: home.accessories) { accessory in
                    accessory.room?.name ?? "No Room"
                }

                ForEach(Array(accessoriesByRoom.keys.sorted()), id: \.self) { roomName in
                    roomSection(roomName: roomName, accessories: accessoriesByRoom[roomName] ?? [])
                }
            }
        }
    }

    private func roomSection(roomName: String, accessories: [HMAccessory]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: roomName == "No Room" ? "questionmark.square.dashed" : "square.grid.2x2.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                Text(roomName)
                    .font(.system(size: 24, weight: .semibold))
                Text("(\(accessories.count))")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)

            VStack(spacing: 12) {
                ForEach(accessories, id: \.uniqueIdentifier) { accessory in
                    accessoryCard(accessory)
                }
            }
            .padding(.horizontal, 40)
        }
    }

    private func accessoryCard(_ accessory: HMAccessory) -> some View {
        HStack(spacing: 20) {
            // Icon based on category
            Image(systemName: iconForAccessory(accessory))
                .font(.system(size: 36))
                .foregroundColor(colorForAccessory(accessory))
                .frame(width: 70, height: 70)
                .background(colorForAccessory(accessory).opacity(0.15))
                .cornerRadius(14)

            // Accessory Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(accessory.name)
                        .font(.system(size: 24, weight: .semibold))

                    if !accessory.isReachable {
                        Text("OFFLINE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                }

                HStack(spacing: 16) {
                    Label(accessory.manufacturer ?? "Unknown", systemImage: "building.2")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)

                    if let model = accessory.model {
                        Label(model, systemImage: "cube.box")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }

                    Label(categoryName(for: accessory.category), systemImage: "tag")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // UUID
            VStack(alignment: .trailing, spacing: 4) {
                Text("UUID")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text(accessory.uniqueIdentifier.uuidString.prefix(8) + "...")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accessory.isReachable ? Color.clear : Color.red.opacity(0.5), lineWidth: 2)
        )
    }

    // MARK: - Empty States

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2.0)
            Text("Loading HomeKit data...")
                .font(.system(size: 24, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    private var noHomesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No HomeKit Homes Found")
                .font(.system(size: 28, weight: .bold))
            Text("Set up your home in the Home app on iOS")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    private var emptyAccessoriesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("No Accessories in This Home")
                .font(.system(size: 28, weight: .bold))
            Text("Add accessories using the Home app on iOS")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Helper Functions

    private var totalAccessoryCount: Int {
        homeManager.homes.flatMap { $0.accessories }.count
    }

    private func iconForAccessory(_ accessory: HMAccessory) -> String {
        let categoryType = accessory.category.categoryType

        // tvOS 16.0 compatible categories
        if categoryType == HMAccessoryCategoryTypeLightbulb { return "lightbulb.fill" }
        if categoryType == HMAccessoryCategoryTypeSwitch { return "switch.2" }
        if categoryType == HMAccessoryCategoryTypeOutlet { return "powerplug.fill" }
        if categoryType == HMAccessoryCategoryTypeThermostat { return "thermometer" }
        if categoryType == HMAccessoryCategoryTypeFan { return "fan.fill" }
        if categoryType == HMAccessoryCategoryTypeDoorLock { return "lock.fill" }
        if categoryType == HMAccessoryCategoryTypeDoor { return "door.left.hand.open" }
        if categoryType == HMAccessoryCategoryTypeWindow { return "window.vertical.open" }
        if categoryType == HMAccessoryCategoryTypeGarageDoorOpener { return "garage.open.fill" }
        if categoryType == HMAccessoryCategoryTypeSensor { return "sensor.fill" }
        if categoryType == HMAccessoryCategoryTypeSecuritySystem { return "shield.fill" }
        if categoryType == HMAccessoryCategoryTypeSprinkler { return "sprinkler.fill" }
        if categoryType == HMAccessoryCategoryTypeBridge { return "antenna.radiowaves.left.and.right" }

        // tvOS 18.0+ categories (check availability)
        if #available(tvOS 18.0, *) {
            if categoryType == HMAccessoryCategoryTypeTelevision { return "tv.fill" }
            if categoryType == HMAccessoryCategoryTypeSpeaker { return "hifispeaker.fill" }
        }

        return "lightbulb.fill"
    }

    private func colorForAccessory(_ accessory: HMAccessory) -> Color {
        if !accessory.isReachable {
            return .gray
        }

        let categoryType = accessory.category.categoryType

        // tvOS 16.0 compatible categories
        if categoryType == HMAccessoryCategoryTypeLightbulb { return .yellow }
        if categoryType == HMAccessoryCategoryTypeSwitch { return .blue }
        if categoryType == HMAccessoryCategoryTypeOutlet { return .green }
        if categoryType == HMAccessoryCategoryTypeThermostat { return .orange }
        if categoryType == HMAccessoryCategoryTypeFan { return .cyan }
        if categoryType == HMAccessoryCategoryTypeDoorLock { return .red }
        if categoryType == HMAccessoryCategoryTypeSecuritySystem { return .red }
        if categoryType == HMAccessoryCategoryTypeSensor { return .mint }

        return .blue
    }

    private func categoryName(for category: HMAccessoryCategory) -> String {
        let categoryType = category.categoryType

        // tvOS 16.0 compatible categories
        if categoryType == HMAccessoryCategoryTypeLightbulb { return "Light" }
        if categoryType == HMAccessoryCategoryTypeSwitch { return "Switch" }
        if categoryType == HMAccessoryCategoryTypeOutlet { return "Outlet" }
        if categoryType == HMAccessoryCategoryTypeThermostat { return "Thermostat" }
        if categoryType == HMAccessoryCategoryTypeFan { return "Fan" }
        if categoryType == HMAccessoryCategoryTypeDoorLock { return "Lock" }
        if categoryType == HMAccessoryCategoryTypeDoor { return "Door" }
        if categoryType == HMAccessoryCategoryTypeWindow { return "Window" }
        if categoryType == HMAccessoryCategoryTypeWindowCovering { return "Window Covering" }
        if categoryType == HMAccessoryCategoryTypeGarageDoorOpener { return "Garage Door" }
        if categoryType == HMAccessoryCategoryTypeSensor { return "Sensor" }
        if categoryType == HMAccessoryCategoryTypeSecuritySystem { return "Security System" }
        if categoryType == HMAccessoryCategoryTypeVideoDoorbell { return "Video Doorbell" }
        if categoryType == HMAccessoryCategoryTypeSprinkler { return "Sprinkler" }
        if categoryType == HMAccessoryCategoryTypeBridge { return "Bridge" }
        if categoryType == HMAccessoryCategoryTypeAirPurifier { return "Air Purifier" }
        if categoryType == HMAccessoryCategoryTypeAirHeater { return "Heater" }
        if categoryType == HMAccessoryCategoryTypeAirConditioner { return "Air Conditioner" }

        // tvOS 18.0+ categories
        if #available(tvOS 18.0, *) {
            if categoryType == HMAccessoryCategoryTypeTelevision { return "TV" }
            if categoryType == HMAccessoryCategoryTypeSpeaker { return "Speaker" }
        }

        return "Other"
    }
}
