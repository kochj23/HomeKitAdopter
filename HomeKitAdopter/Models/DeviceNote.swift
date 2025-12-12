//
//  DeviceNote.swift
//  HomeKitAdopter - Device Notes and Tags
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation

/// Model for device notes and tags
///
/// Allows users to add custom notes, tags, and metadata to discovered devices
/// for better organization and tracking.
struct DeviceNote: Codable, Identifiable {
    let id: UUID
    let deviceKey: String  // Unique identifier for device (name-serviceType)
    var note: String
    var tags: [String]
    var customLabel: String?
    var photoPath: String?
    var ignored: Bool  // Mark device as "won't pair"
    var physicalLocation: String?
    var createdAt: Date
    var updatedAt: Date

    init(deviceKey: String, note: String = "", tags: [String] = [], customLabel: String? = nil) {
        self.id = UUID()
        self.deviceKey = deviceKey
        self.note = note
        self.tags = tags
        self.customLabel = customLabel
        self.photoPath = nil
        self.ignored = false
        self.physicalLocation = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func update(note: String? = nil, tags: [String]? = nil, customLabel: String? = nil, ignored: Bool? = nil, physicalLocation: String? = nil) {
        if let note = note { self.note = note }
        if let tags = tags { self.tags = tags }
        if let customLabel = customLabel { self.customLabel = customLabel }
        if let ignored = ignored { self.ignored = ignored }
        if let physicalLocation = physicalLocation { self.physicalLocation = physicalLocation }
        self.updatedAt = Date()
    }
}

/// Manager for device notes and tags
@MainActor
final class DeviceNotesManager: ObservableObject {
    static let shared = DeviceNotesManager()

    @Published private(set) var notes: [String: DeviceNote] = [:]

    private let secureStorage = SecureStorageManager.shared
    private let storageKey = "deviceNotes"

    private init() {
        loadNotes()
        LoggingManager.shared.info("DeviceNotesManager initialized with \(notes.count) notes")
    }

    /// Get note for a device
    func getNote(for deviceKey: String) -> DeviceNote? {
        return notes[deviceKey]
    }

    /// Save or update note for a device
    func saveNote(_ note: DeviceNote) {
        notes[note.deviceKey] = note
        saveNotes()
        LoggingManager.shared.info("Note saved for device: \(note.deviceKey)")
    }

    /// Delete note for a device
    func deleteNote(for deviceKey: String) {
        notes.removeValue(forKey: deviceKey)
        saveNotes()
        LoggingManager.shared.info("Note deleted for device: \(deviceKey)")
    }

    /// Get all devices with a specific tag
    func getDevices(withTag tag: String) -> [DeviceNote] {
        return notes.values.filter { $0.tags.contains(tag) }
    }

    /// Get all unique tags
    func getAllTags() -> [String] {
        let allTags = notes.values.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    /// Get all ignored devices
    func getIgnoredDevices() -> [DeviceNote] {
        return notes.values.filter { $0.ignored }
    }

    /// Check if device is ignored
    func isIgnored(_ deviceKey: String) -> Bool {
        return notes[deviceKey]?.ignored ?? false
    }

    // MARK: - Private Methods

    private func saveNotes() {
        do {
            try secureStorage.store(notes, forKey: storageKey)
            LoggingManager.shared.info("Device notes saved (\(notes.count) notes)")
        } catch {
            LoggingManager.shared.error("Failed to save device notes: \(error.localizedDescription)")
        }
    }

    private func loadNotes() {
        do {
            if let loadedNotes = try secureStorage.retrieve([String: DeviceNote].self, forKey: storageKey) {
                notes = loadedNotes
                LoggingManager.shared.info("Device notes loaded (\(notes.count) notes)")
            }
        } catch {
            LoggingManager.shared.error("Failed to load device notes: \(error.localizedDescription)")
        }
    }
}
