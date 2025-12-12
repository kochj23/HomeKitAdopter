//
//  StringExtensions.swift
//  HomeKitAdopter - Fuzzy Matching & String Utilities
//
//  Created by Jordan Koch on 2025-11-21.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation

extension String {
    /// Calculate Levenshtein distance between two strings
    /// Used for fuzzy name matching of devices
    func levenshteinDistance(to other: String) -> Int {
        let m = self.count
        let n = other.count

        guard m > 0 && n > 0 else { return max(m, n) }

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = self[self.index(self.startIndex, offsetBy: i - 1)] ==
                          other[other.index(other.startIndex, offsetBy: j - 1)] ? 0 : 1
                matrix[i][j] = Swift.min(
                    Swift.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[m][n]
    }

    /// Calculate similarity score between two strings (0.0 to 1.0)
    /// 1.0 = identical, 0.0 = completely different
    func similarityScore(to other: String) -> Double {
        let distance = self.levenshteinDistance(to: other)
        let maxLength = max(self.count, other.count)
        guard maxLength > 0 else { return 1.0 }
        return 1.0 - Double(distance) / Double(maxLength)
    }

    /// Normalize string for matching (lowercase, remove special chars)
    func normalizedForMatching() -> String {
        return self.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    /// Check if this string contains common manufacturer names
    func extractManufacturer() -> String? {
        let manufacturers = [
            "philips", "hue", "ikea", "tradfri", "eve", "nanoleaf",
            "lifx", "tp-link", "kasa", "wemo", "belkin", "ecobee",
            "honeywell", "lutron", "caseta", "aqara", "xiaomi",
            "meross", "vocolinc", "elgato", "logitech", "august",
            "schlage", "yale", "netatmo", "withings", "hunter",
            "mysa", "idevices", "leviton", "smart", "matter"
        ]

        let lowercased = self.lowercased()
        for manufacturer in manufacturers {
            if lowercased.contains(manufacturer) {
                return manufacturer.capitalized
            }
        }
        return nil
    }
}
