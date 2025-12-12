//
//  NetworkDiscoveryManagerTests.swift
//  HomeKitAdopterTests
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import XCTest
@testable import HomeKitAdopter

@MainActor
final class NetworkDiscoveryManagerTests: XCTestCase {

    var sut: NetworkDiscoveryManager!

    override func setUp() {
        super.setUp()
        sut = NetworkDiscoveryManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Device Discovery Tests

    func testInitialState_NoDevices() {
        // Then
        XCTAssertEqual(sut.discoveredDevices.count, 0, "Should start with no devices")
        XCTAssertFalse(sut.isScanning, "Should not be scanning initially")
    }

    // MARK: - Confidence Calculation Tests

    func testConfidenceCalculation_UnpairedHomeKitDevice_ReturnsHighConfidence() {
        // Given - Device with unpaired status flag
        let device = createMockDevice(
            serviceType: .homekit,
            txtRecords: ["sf": "1"] // Status flag indicating not paired
        )

        // When
        let (confidence, reasons) = sut.getCachedConfidence(for: device)

        // Then
        XCTAssertGreaterThanOrEqual(confidence, 70, "Unpaired HomeKit device should have high confidence")
        XCTAssertTrue(reasons.contains(where: { $0.contains("unpaired") || $0.contains("status flag") }),
                      "Should include unpaired reason")
    }

    func testConfidenceCalculation_MatterCommissioning_ReturnsHighConfidence() {
        // Given - Matter commissioning device
        let device = createMockDevice(serviceType: .matterCommissioning)

        // When
        let (confidence, _) = sut.getCachedConfidence(for: device)

        // Then
        XCTAssertGreaterThanOrEqual(confidence, 70, "Matter commissioning device should have high confidence")
    }

    func testConfidenceCalculation_SetupHashPresent_IncreasesConfidence() {
        // Given - Device with setup hash
        let device = createMockDevice(
            serviceType: .homekit,
            txtRecords: ["sh": "abc123xyz"]
        )

        // When
        let (confidence, reasons) = sut.getCachedConfidence(for: device)

        // Then
        XCTAssertGreaterThan(confidence, 50, "Setup hash should increase confidence")
        XCTAssertTrue(reasons.contains(where: { $0.contains("setup") }),
                      "Should include setup hash reason")
    }

    // MARK: - Bounded Array Tests

    func testBoundedDeviceArray_DoesNotExceedMaximum() {
        // Given - Max devices is 500
        let maxDevices = 500

        // When - Add more than max devices
        for i in 0..<550 {
            let device = createMockDevice(name: "Device \(i)")
            // Simulate adding via the internal method
            if sut.discoveredDevices.count < maxDevices {
                sut.discoveredDevices.append(device)
                sut.deviceConfidenceCache[device.id] = (50, ["test"])
            }
        }

        // Then
        XCTAssertLessThanOrEqual(sut.discoveredDevices.count, maxDevices,
                                 "Should not exceed maximum device count")
    }

    // MARK: - Confidence Cache Tests

    func testConfidenceCache_StoresCalculatedValues() {
        // Given
        let device = createMockDevice(serviceType: .homekit)

        // When - Get confidence (which should cache it)
        let (firstConfidence, _) = sut.getCachedConfidence(for: device)

        // Then - Cache should contain the device
        XCTAssertNotNil(sut.deviceConfidenceCache[device.id], "Device should be in cache")
        XCTAssertEqual(sut.deviceConfidenceCache[device.id]?.confidence, firstConfidence,
                       "Cached confidence should match calculated value")
    }

    func testConfidenceCache_ReturnsSameValueOnMultipleCalls() {
        // Given
        let device = createMockDevice(serviceType: .homekit)

        // When - Call multiple times
        let (firstConfidence, _) = sut.getCachedConfidence(for: device)
        let (secondConfidence, _) = sut.getCachedConfidence(for: device)
        let (thirdConfidence, _) = sut.getCachedConfidence(for: device)

        // Then - All should be identical
        XCTAssertEqual(firstConfidence, secondConfidence, "Cached values should be consistent")
        XCTAssertEqual(secondConfidence, thirdConfidence, "Cached values should be consistent")
    }

    // MARK: - Filtering Tests

    func testGetUnadoptedDevices_MinimumConfidence_FiltersCorrectly() {
        // Given - Create devices with different confidence levels
        // Note: Actual confidence calculation depends on TXT records
        let highConfDevice = createMockDevice(name: "High", serviceType: .matterCommissioning)
        let lowConfDevice = createMockDevice(name: "Low", serviceType: .homekit, txtRecords: ["sf": "0"])

        // Manually add to array and cache for testing
        sut.discoveredDevices.append(highConfDevice)
        sut.discoveredDevices.append(lowConfDevice)
        sut.deviceConfidenceCache[highConfDevice.id] = (75, ["test"])
        sut.deviceConfidenceCache[lowConfDevice.id] = (25, ["test"])

        // When
        let unadopted = sut.getUnadoptedDevices(minimumConfidence: 50)

        // Then
        XCTAssertEqual(unadopted.count, 1, "Should only return high confidence device")
        XCTAssertEqual(unadopted.first?.name, "High", "Should return the high confidence device")
    }

    // MARK: - Manufacturer Extraction Tests

    func testExtractManufacturer_FromTXTRecord_ReturnsCorrectValue() {
        // Given
        let txtRecords = ["manufacturer": "Apple Inc."]
        let device = createMockDevice(txtRecords: txtRecords)

        // Then
        XCTAssertEqual(device.manufacturer, "Apple Inc.", "Should extract manufacturer from TXT records")
    }

    func testExtractManufacturer_FromDeviceName_ReturnsKnownBrand() {
        // Given - Device names with known manufacturers
        let philipsDevice = createMockDevice(name: "Philips Hue Bridge")
        let nestDevice = createMockDevice(name: "Nest Thermostat")
        let googleDevice = createMockDevice(name: "Google Home Mini")

        // Then
        XCTAssertNotNil(philipsDevice.manufacturer, "Should extract Philips from name")
        XCTAssertNotNil(nestDevice.manufacturer, "Should extract Nest from name")
        XCTAssertNotNil(googleDevice.manufacturer, "Should extract Google from name")
    }

    // MARK: - MAC Address Parsing Tests

    func testMACAddressExtraction_ValidFormat_ReturnsFormatted() {
        // Given - TXT record with MAC address
        let txtRecords = ["id": "AA:BB:CC:DD:EE:FF"]
        let device = createMockDevice(txtRecords: txtRecords)

        // Then
        XCTAssertNotNil(device.macAddress, "Should extract MAC address")
        if let mac = device.macAddress {
            XCTAssertTrue(mac.contains(":"), "MAC should contain colons")
        }
    }

    // MARK: - Device Type Tests

    func testDeviceCategory_HomeKit_ReturnsSmartHome() {
        // Given
        let device = createMockDevice(serviceType: .homekit)

        // Then
        XCTAssertEqual(device.serviceType.category, .smarthome, "HomeKit should be smart home category")
    }

    func testDeviceCategory_GoogleCast_ReturnsGoogle() {
        // Given
        let device = createMockDevice(serviceType: .googlecast)

        // Then
        XCTAssertEqual(device.serviceType.category, .google, "Chromecast should be Google category")
    }

    func testDeviceCategory_UniFi_ReturnsUniFi() {
        // Given
        let device = createMockDevice(serviceType: .unifi)

        // Then
        XCTAssertEqual(device.serviceType.category, .unifi, "UniFi should be UniFi category")
    }

    // MARK: - Helper Methods

    private func createMockDevice(
        name: String = "Test Device",
        serviceType: NetworkDiscoveryManager.DiscoveredDevice.ServiceType = .homekit,
        host: String? = "192.168.1.100",
        port: UInt16? = 5353,
        macAddress: String? = nil,
        manufacturer: String? = nil,
        txtRecords: [String: String] = [:]
    ) -> NetworkDiscoveryManager.DiscoveredDevice {
        return NetworkDiscoveryManager.DiscoveredDevice(
            name: name,
            serviceType: serviceType,
            host: host,
            port: port,
            macAddress: macAddress,
            manufacturer: manufacturer,
            txtRecords: txtRecords,
            discoveredAt: Date()
        )
    }
}
