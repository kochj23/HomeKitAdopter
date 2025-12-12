//
//  QRCodeManager.swift
//  HomeKitAdopter - QR Code Generation
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import CoreImage
import UIKit

/// Manager for generating QR codes for HomeKit setup
///
/// Generates QR codes from setup codes found in device TXT records
@MainActor
final class QRCodeManager: ObservableObject {
    static let shared = QRCodeManager()

    private init() {
        LoggingManager.shared.info("QRCodeManager initialized")
    }

    /// Extract setup code from device TXT records
    func extractSetupCode(from device: NetworkDiscoveryManager.DiscoveredDevice) -> String? {
        // Try setup hash (sh) field
        if let setupHash = device.txtRecords["sh"] {
            return setupHash
        }

        // Try setup code field
        if let setupCode = device.txtRecords["setupCode"] {
            return setupCode
        }

        // Try pv (protocol version) + setup info
        if let pv = device.txtRecords["pv"],
           let id = device.txtRecords["id"],
           let ci = device.txtRecords["ci"] {
            // Construct setup payload
            return "X-HM://\(pv)\(id)\(ci)"
        }

        return nil
    }

    /// Generate QR code image from setup code
    func generateQRCode(from setupCode: String, size: CGSize = CGSize(width: 400, height: 400)) -> UIImage? {
        let data = setupCode.data(using: .utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            LoggingManager.shared.error("Failed to create QR code generator")
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")  // High error correction

        guard let ciImage = filter.outputImage else {
            LoggingManager.shared.error("Failed to generate QR code image")
            return nil
        }

        // Scale up the QR code
        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height
        let transformedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            LoggingManager.shared.error("Failed to create CGImage from QR code")
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)
        LoggingManager.shared.info("Generated QR code for setup code")
        return uiImage
    }

    /// Generate QR code for device if setup code is available
    func generateQRCodeForDevice(_ device: NetworkDiscoveryManager.DiscoveredDevice, size: CGSize = CGSize(width: 400, height: 400)) -> UIImage? {
        guard let setupCode = extractSetupCode(from: device) else {
            LoggingManager.shared.warning("No setup code found for device: \(device.name)")
            return nil
        }

        return generateQRCode(from: setupCode, size: size)
    }

    /// Check if device has setup code available
    func hasSetupCode(_ device: NetworkDiscoveryManager.DiscoveredDevice) -> Bool {
        return extractSetupCode(from: device) != nil
    }

    /// Extract Matter pairing information
    func extractMatterPairingInfo(from device: NetworkDiscoveryManager.DiscoveredDevice) -> MatterPairingInfo? {
        guard device.serviceType == .matterCommissioning else {
            return nil
        }

        let discriminator = device.txtRecords["D"]
        let vendorID = device.txtRecords["VP"]
        let productID = device.txtRecords["PI"]
        let commissioning = device.txtRecords["CM"]

        if discriminator != nil || vendorID != nil {
            return MatterPairingInfo(
                discriminator: discriminator,
                vendorID: vendorID,
                productID: productID,
                commissioningMode: commissioning,
                setupPayload: device.txtRecords["SII"]
            )
        }

        return nil
    }

    /// Matter pairing information
    struct MatterPairingInfo {
        let discriminator: String?
        let vendorID: String?
        let productID: String?
        let commissioningMode: String?
        let setupPayload: String?

        var isCommissioning: Bool {
            return commissioningMode == "1" || commissioningMode == "2"
        }

        var vendorName: String? {
            guard let vid = vendorID, let vendorInt = Int(vid, radix: 16) else {
                return nil
            }

            // Known Matter vendor IDs
            let vendors: [Int: String] = [
                0x1049: "Apple",
                0x1037: "Amazon",
                0x110A: "Google",
                0x115F: "Samsung SmartThings",
                0x1002: "Nordic Semiconductor",
                0x100B: "Philips",
                0x117C: "IKEA"
            ]

            return vendors[vendorInt]
        }
    }
}
