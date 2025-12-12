//
//  PairingInstructionsManager.swift
//  HomeKitAdopter - Device-Specific Pairing Instructions
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation

/// Manager for device-specific pairing instructions
///
/// Provides manufacturer-specific setup steps and troubleshooting guides
@MainActor
final class PairingInstructionsManager: ObservableObject {
    static let shared = PairingInstructionsManager()

    struct PairingInstructions {
        let manufacturer: String
        let steps: [String]
        let troubleshooting: [String]
        let supportURL: String?
        let videoURL: String?
        let estimatedTime: String
        let difficulty: Difficulty

        enum Difficulty: String {
            case easy = "Easy"
            case medium = "Medium"
            case hard = "Hard"
        }
    }

    private let instructionsDatabase: [String: PairingInstructions] = [
        "Philips": PairingInstructions(
            manufacturer: "Philips Hue",
            steps: [
                "Ensure Philips Hue Bridge is powered on and connected to your network",
                "Press the large button on the Hue Bridge",
                "Wait for the button LED to blink",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Scan the setup code on the bottom of the Hue Bridge",
                "Follow on-screen instructions to complete setup"
            ],
            troubleshooting: [
                "If bridge isn't found: Check network connection and restart bridge",
                "If pairing fails: Ensure bridge firmware is up to date via Hue app",
                "If lights don't appear: Reset lights by power cycling 6 times"
            ],
            supportURL: "https://www.philips-hue.com/en-us/support/faq/homekit",
            videoURL: nil,
            estimatedTime: "5-10 minutes",
            difficulty: .easy
        ),

        "Ikea": PairingInstructions(
            manufacturer: "IKEA TRÅDFRI",
            steps: [
                "Ensure TRÅDFRI Gateway is powered and connected to network",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Scan the setup code on the bottom of the Gateway",
                "Enter the security code printed under the QR code",
                "Wait for pairing to complete (may take 1-2 minutes)",
                "Name your gateway and assign to a room"
            ],
            troubleshooting: [
                "If gateway not found: Restart gateway by unplugging for 10 seconds",
                "If code doesn't work: Ensure you're using the code on gateway, not app",
                "If pairing stalls: Move iPhone closer to gateway during setup"
            ],
            supportURL: "https://www.ikea.com/us/en/customer-service/knowledge/articles/assembly-documents.html",
            videoURL: nil,
            estimatedTime: "5-10 minutes",
            difficulty: .easy
        ),

        "Eve": PairingInstructions(
            manufacturer: "Eve (Elgato)",
            steps: [
                "Plug in or install batteries in your Eve device",
                "Wait for device to power on (LED indicator if present)",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Scan the HomeKit setup code (found on device or in box)",
                "If code is damaged, tap 'Don't Have Code' and select device manually",
                "Follow prompts to assign room and name device"
            ],
            troubleshooting: [
                "If device not found: Ensure Bluetooth is enabled on iPhone",
                "If pairing fails: Reset device using manufacturer reset procedure",
                "If connection drops: Update Eve firmware via Eve app"
            ],
            supportURL: "https://www.evehome.com/en/support",
            videoURL: nil,
            estimatedTime: "3-5 minutes",
            difficulty: .easy
        ),

        "Nanoleaf": PairingInstructions(
            manufacturer: "Nanoleaf",
            steps: [
                "Plug in your Nanoleaf panels and wait for them to boot up",
                "Press and hold the controller button for 5-7 seconds until LED blinks",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Scan the 8-digit setup code (found on controller or in Nanoleaf app)",
                "Wait for HomeKit pairing to complete",
                "Assign to room and name your Nanoleaf"
            ],
            troubleshooting: [
                "If not found: Ensure Nanoleaf is on same WiFi network (2.4GHz only)",
                "If pairing fails: Factory reset by holding power button for 15 seconds",
                "If lights don't respond: Update firmware via Nanoleaf app first"
            ],
            supportURL: "https://helpdesk.nanoleaf.me/",
            videoURL: nil,
            estimatedTime: "5-10 minutes",
            difficulty: .medium
        ),

        "Lifx": PairingInstructions(
            manufacturer: "LIFX",
            steps: [
                "Screw in LIFX bulb and turn on power",
                "Wait for bulb to pulse (indicating setup mode)",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Select 'Don't Have a Code or Can't Scan'",
                "Select your LIFX bulb from the list",
                "Follow prompts to connect to WiFi and complete setup"
            ],
            troubleshooting: [
                "If bulb not found: Reset by power cycling 5 times (on 1s, off 1s)",
                "If WiFi connection fails: Ensure using 2.4GHz network only",
                "If bulb doesn't pulse: Update firmware via LIFX app first"
            ],
            supportURL: "https://support.lifx.com/",
            videoURL: nil,
            estimatedTime: "5-10 minutes",
            difficulty: .easy
        ),

        "Tp-Link": PairingInstructions(
            manufacturer: "TP-Link Kasa",
            steps: [
                "Plug in TP-Link device and wait for LED to flash amber and green",
                "Download and open Kasa app to complete initial WiFi setup",
                "Once device is online in Kasa app, enable HomeKit",
                "In Kasa app: Go to device settings → HomeKit → Enable",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Scan the HomeKit code shown in Kasa app or on device label",
                "Complete setup in Home app"
            ],
            troubleshooting: [
                "If HomeKit option missing: Update device firmware via Kasa app",
                "If code doesn't work: Regenerate HomeKit code in Kasa app",
                "If device offline: Check WiFi connection (2.4GHz required)"
            ],
            supportURL: "https://www.tp-link.com/us/support/",
            videoURL: nil,
            estimatedTime: "10-15 minutes",
            difficulty: .medium
        ),

        "Ecobee": PairingInstructions(
            manufacturer: "Ecobee",
            steps: [
                "Install Ecobee thermostat and complete initial setup",
                "On thermostat: Menu → Settings → HomeKit",
                "Generate HomeKit code on thermostat display",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Scan the code displayed on thermostat",
                "Assign to room and name thermostat",
                "Configure heating/cooling zones as needed"
            ],
            troubleshooting: [
                "If code expires: Generate new code on thermostat",
                "If pairing fails: Restart thermostat from settings menu",
                "If sensors don't appear: Add sensors separately in Ecobee app first"
            ],
            supportURL: "https://support.ecobee.com/",
            videoURL: nil,
            estimatedTime: "5-10 minutes",
            difficulty: .medium
        ),

        "Aqara": PairingInstructions(
            manufacturer: "Aqara",
            steps: [
                "Plug in Aqara Hub and wait for voice prompt",
                "Download Aqara Home app and create account",
                "Add hub in Aqara app and complete WiFi setup",
                "In Aqara app: Go to hub settings → HomeKit",
                "Enable HomeKit integration",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Scan HomeKit code shown in Aqara app",
                "All Aqara devices connected to hub will appear in Home app"
            ],
            troubleshooting: [
                "If hub not found: Ensure hub is on 2.4GHz WiFi network",
                "If devices missing: Add devices to hub via Aqara app first",
                "If pairing fails: Reset hub using reset button for 10 seconds"
            ],
            supportURL: "https://www.aqara.com/us/support.html",
            videoURL: nil,
            estimatedTime: "10-15 minutes",
            difficulty: .medium
        ),

        "Meross": PairingInstructions(
            manufacturer: "Meross",
            steps: [
                "Plug in Meross device, LED will flash blue",
                "Download Meross app and create account",
                "Add device in Meross app using WiFi setup",
                "Once online, go to device settings in Meross app",
                "Enable HomeKit (may require firmware update)",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Scan HomeKit code from Meross app or device sticker",
                "Complete setup in Home app"
            ],
            troubleshooting: [
                "If HomeKit unavailable: Update firmware via Meross app",
                "If pairing fails: Reset device by holding button for 5 seconds",
                "If device offline: Check 2.4GHz WiFi connection"
            ],
            supportURL: "https://www.meross.com/support",
            videoURL: nil,
            estimatedTime: "10-15 minutes",
            difficulty: .medium
        ),

        "Matter": PairingInstructions(
            manufacturer: "Matter Device",
            steps: [
                "Ensure device is powered on and in pairing mode",
                "Look for Matter logo and QR code on device",
                "Open Home app on your iPhone or iPad",
                "Tap '+' to add accessory",
                "Scan the Matter QR code",
                "Select 'Add to This Home' when prompted",
                "Wait for device to connect (uses Thread or WiFi)",
                "Assign to room and name device",
                "Device is now available across all Matter ecosystems"
            ],
            troubleshooting: [
                "If QR code won't scan: Enter numeric code manually",
                "If pairing stalls: Ensure iPhone has latest iOS version",
                "If device not found: Factory reset device and try again",
                "If Thread device: Ensure you have Thread border router (HomePod mini/Apple TV)"
            ],
            supportURL: "https://support.apple.com/guide/iphone/set-up-matter-accessories-iph0c026a392/ios",
            videoURL: nil,
            estimatedTime: "5-10 minutes",
            difficulty: .easy
        )
    ]

    private init() {
        LoggingManager.shared.info("PairingInstructionsManager initialized with \(instructionsDatabase.count) manufacturers")
    }

    /// Get pairing instructions for a manufacturer
    func getInstructions(for manufacturer: String?) -> PairingInstructions? {
        guard let manufacturer = manufacturer else { return nil }

        // Try exact match first
        if let instructions = instructionsDatabase[manufacturer] {
            return instructions
        }

        // Try partial match
        let normalizedQuery = manufacturer.lowercased()
        for (key, instructions) in instructionsDatabase {
            if key.lowercased().contains(normalizedQuery) || normalizedQuery.contains(key.lowercased()) {
                return instructions
            }
        }

        return nil
    }

    /// Get generic HomeKit pairing instructions
    func getGenericInstructions() -> PairingInstructions {
        return PairingInstructions(
            manufacturer: "Generic HomeKit Device",
            steps: [
                "Plug in or power on your HomeKit device",
                "Wait for the device to enter pairing mode (check LED indicators)",
                "Open the Home app on your iPhone or iPad",
                "Tap the '+' button in the top right corner",
                "Select 'Add Accessory'",
                "Scan the 8-digit HomeKit code (on device label or packaging)",
                "If code is missing: Tap 'Don't Have a Code' and select manually",
                "Follow on-screen prompts to complete setup",
                "Assign device to a room and give it a name"
            ],
            troubleshooting: [
                "Ensure your iPhone/iPad is on the same WiFi network as the device",
                "Check that Bluetooth is enabled on your iPhone/iPad",
                "Verify the device supports HomeKit (look for 'Works with Apple HomeKit' logo)",
                "Try moving closer to the device during pairing",
                "If all else fails: Factory reset device and try again"
            ],
            supportURL: "https://support.apple.com/guide/iphone/set-up-homekit-accessories-iph3c50f191/ios",
            videoURL: nil,
            estimatedTime: "5-10 minutes",
            difficulty: .easy
        )
    }

    /// Get all supported manufacturers
    func getSupportedManufacturers() -> [String] {
        return Array(instructionsDatabase.keys).sorted()
    }
}
