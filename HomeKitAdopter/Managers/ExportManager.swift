//
//  ExportManager.swift
//  HomeKitAdopter - Export Device Data
//
//  Created by Jordan Koch on 2025-11-22.
//  Updated: 2026-01-28 - Version 4.2
//  Copyright © 2025-2026 Jordan Koch. All rights reserved.
//

import Foundation
import UIKit

/// Manager for exporting device data to various formats
///
/// Supports CSV and JSON export with privacy options
@MainActor
final class ExportManager: ObservableObject {
    static let shared = ExportManager()

    /// Privacy options for export
    struct PrivacyOptions {
        var redactMAC: Bool = false
        var obfuscateIP: Bool = false
        var removeNotes: Bool = false
        var anonymizeNames: Bool = false

        static let none = PrivacyOptions()
        static let full = PrivacyOptions(redactMAC: true, obfuscateIP: true, removeNotes: true, anonymizeNames: true)
    }

    private init() {
        LoggingManager.shared.info("ExportManager initialized")
    }

    /// Export devices to CSV format
    func exportToCSV(devices: [NetworkDiscoveryManager.DiscoveredDevice], privacyOptions: PrivacyOptions = .none) -> String {
        var csv = "Device Name,IP Address,MAC Address,Manufacturer,Service Type,Port,Confidence Score,Discovered At,Notes,Tags\n"

        for device in devices {
            let name = privacyOptions.anonymizeNames ? anonymizeName(device.name) : device.name
            let ip = privacyOptions.obfuscateIP ? obfuscateIP(device.host) : (device.host ?? "N/A")
            let mac = privacyOptions.redactMAC ? "XX:XX:XX:XX:XX:XX" : (device.macAddress ?? "N/A")
            let manufacturer = device.manufacturer ?? "Unknown"
            let serviceType = device.serviceType.displayName
            let port = device.port.map { String($0) } ?? "N/A"

            // Get confidence score
            let (confidence, _) = device.calculateConfidenceScore(adoptedAccessories: [])

            // Get notes
            let deviceKey = makeDeviceKey(device)
            let note = DeviceNotesManager.shared.getNote(for: deviceKey)
            let noteText = privacyOptions.removeNotes ? "" : (note?.note ?? "")
            let tags = privacyOptions.removeNotes ? "" : (note?.tags.joined(separator: ";") ?? "")

            let discoveredAt = ISO8601DateFormatter().string(from: device.discoveredAt)

            csv += "\"\(name)\",\"\(ip)\",\"\(mac)\",\"\(manufacturer)\",\"\(serviceType)\",\"\(port)\",\"\(confidence)%\",\"\(discoveredAt)\",\"\(noteText)\",\"\(tags)\"\n"
        }

        LoggingManager.shared.info("Exported \(devices.count) devices to CSV")
        return csv
    }

    /// Export devices to JSON format
    func exportToJSON(devices: [NetworkDiscoveryManager.DiscoveredDevice], privacyOptions: PrivacyOptions = .none) -> String? {
        let exportData = devices.map { device -> [String: Any] in
            let name = privacyOptions.anonymizeNames ? anonymizeName(device.name) : device.name
            let ip = privacyOptions.obfuscateIP ? obfuscateIP(device.host) : (device.host ?? "N/A")
            let mac = privacyOptions.redactMAC ? "XX:XX:XX:XX:XX:XX" : (device.macAddress ?? "N/A")

            let (confidence, reasons) = device.calculateConfidenceScore(adoptedAccessories: [])

            let deviceKey = makeDeviceKey(device)
            let note = DeviceNotesManager.shared.getNote(for: deviceKey)

            var json: [String: Any] = [
                "name": name,
                "ipAddress": ip,
                "macAddress": mac,
                "manufacturer": device.manufacturer ?? "Unknown",
                "serviceType": device.serviceType.rawValue,
                "serviceTypeName": device.serviceType.displayName,
                "port": device.port ?? 0,
                "confidenceScore": confidence,
                "confidenceReasons": reasons,
                "discoveredAt": ISO8601DateFormatter().string(from: device.discoveredAt),
                "txtRecords": device.txtRecords
            ]

            if !privacyOptions.removeNotes, let note = note {
                json["notes"] = note.note
                json["tags"] = note.tags
                json["customLabel"] = note.customLabel
                json["physicalLocation"] = note.physicalLocation
                json["ignored"] = note.ignored
            }

            return json
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
            let jsonString = String(data: jsonData, encoding: .utf8)
            LoggingManager.shared.info("Exported \(devices.count) devices to JSON")
            return jsonString
        } catch {
            LoggingManager.shared.error("Failed to export to JSON: \(error.localizedDescription)")
            return nil
        }
    }

    /// Save export to temporary file and return URL
    func saveToFile(content: String, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            LoggingManager.shared.info("Saved export to: \(fileURL.path)")
            return fileURL
        } catch {
            LoggingManager.shared.error("Failed to save export file: \(error.localizedDescription)")
            return nil
        }
    }

    /// Generate file name for export
    func generateFileName(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        return "HomeKit_Devices_\(dateString).\(format)"
    }

    // MARK: - Privacy Helpers

    private func anonymizeName(_ name: String) -> String {
        // Keep manufacturer but anonymize model
        let components = name.components(separatedBy: " ")
        if components.count > 1 {
            return "\(components[0]) Device-\(String(name.hash.magnitude % 10000))"
        }
        return "Device-\(String(name.hash.magnitude % 10000))"
    }

    private func obfuscateIP(_ ip: String?) -> String {
        guard let ip = ip else { return "N/A" }
        let components = ip.components(separatedBy: ".")
        if components.count == 4 {
            return "\(components[0]).\(components[1]).XXX.XXX"
        }
        return "XXX.XXX.XXX.XXX"
    }

    private func makeDeviceKey(_ device: NetworkDiscoveryManager.DiscoveredDevice) -> String {
        return "\(device.name)-\(device.serviceType.rawValue)"
    }
}
