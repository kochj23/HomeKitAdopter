//
//  LoggingManager.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-21.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import Foundation
import OSLog

/// Centralized logging manager for the HomeKitAdopter application
///
/// This manager provides structured logging with different severity levels
/// and automatic log persistence for debugging without console access.
///
/// # Features:
/// - Multiple log levels (debug, info, warning, error, critical)
/// - Automatic file-based logging
/// - Thread-safe operations
/// - Log rotation to prevent excessive disk usage
/// - Sanitization of sensitive data
///
/// # Security:
/// - Setup codes are NEVER logged
/// - Personal information is sanitized
/// - Logs are stored locally with restricted access
///
/// # Usage:
/// ```swift
/// LoggingManager.shared.log("Accessory discovered", level: .info)
/// LoggingManager.shared.log("Pairing failed", level: .error)
/// ```
final class LoggingManager {
    /// Shared singleton instance
    static let shared = LoggingManager()

    /// Log levels for categorizing messages
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }

    /// OSLog instance for system logging
    private let logger = Logger(subsystem: "com.digitalnoise.homekitadopter", category: "HomeKitAdopter")

    /// File URL for persistent log storage
    private let logFileURL: URL

    /// Serial queue for thread-safe file operations
    private let logQueue = DispatchQueue(label: "com.digitalnoise.homekitadopter.logging", qos: .utility)

    /// Maximum log file size (10 MB)
    private let maxLogFileSize: UInt64 = 10 * 1024 * 1024

    /// Date formatter for log timestamps
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Private initializer for singleton pattern
    private init() {
        // Create logs directory in application support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logsDirectory = appSupport.appendingPathComponent("HomeKitAdopter/Logs", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        // Set log file path
        self.logFileURL = logsDirectory.appendingPathComponent("homekit_adopter.log")

        // Log initialization
        log("LoggingManager initialized", level: .info)
        log("Log file location: \(logFileURL.path)", level: .debug)
    }

    /// Log a message with specified severity level
    ///
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The severity level of the message
    ///   - file: Source file (auto-populated)
    ///   - function: Function name (auto-populated)
    ///   - line: Line number (auto-populated)
    ///
    /// # Security Note:
    /// This method automatically sanitizes sensitive data before logging.
    /// Never pass setup codes or passwords directly to this method.
    func log(_ message: String,
             level: LogLevel = .info,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {

        let timestamp = dateFormatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent
        let sanitizedMessage = sanitize(message)

        let logEntry = "[\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(function) - \(sanitizedMessage)"

        // Log to system logger
        logger.log(level: level.osLogType, "\(logEntry)")

        // Log to file asynchronously
        logQueue.async { [weak self] in
            guard let self = self else { return }
            self.writeToFile(logEntry)
        }
    }

    /// Sanitize sensitive information from log messages
    ///
    /// Removes or masks:
    /// - Setup codes (8-digit patterns)
    /// - Email addresses
    /// - IP addresses (IPv4 and IPv6)
    /// - MAC addresses
    /// - Device IDs and UUIDs
    /// - API keys and tokens
    /// - Passwords
    ///
    /// - Parameter message: The message to sanitize
    /// - Returns: Sanitized message safe for logging
    private func sanitize(_ message: String) -> String {
        var sanitized = message

        // Mask 8-digit HomeKit setup codes (XXX-XX-XXX format)
        let setupCodePattern = "\\b\\d{3}[-\\s]?\\d{2}[-\\s]?\\d{3}\\b"
        if let regex = try? NSRegularExpression(pattern: setupCodePattern) {
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "<SETUP_CODE>"
            )
        }

        // Mask email addresses
        let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "<EMAIL>"
            )
        }

        // Mask IPv4 addresses (show first two octets only for debugging)
        let ipv4Pattern = "\\b(\\d{1,3}\\.\\d{1,3})\\.(\\d{1,3}\\.\\d{1,3})\\b"
        if let regex = try? NSRegularExpression(pattern: ipv4Pattern) {
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "$1.<IP>"
            )
        }

        // Mask IPv6 addresses completely
        let ipv6Pattern = "\\b([0-9a-fA-F]{0,4}:){7}[0-9a-fA-F]{0,4}\\b"
        if let regex = try? NSRegularExpression(pattern: ipv6Pattern) {
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "<IPv6>"
            )
        }

        // Mask MAC addresses (show first 3 bytes for manufacturer identification)
        let macPattern = "\\b([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\\b"
        if let regex = try? NSRegularExpression(pattern: macPattern) {
            // Replace with first 3 bytes + mask (e.g., "AA:BB:CC:XX:XX:XX")
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            let matches = regex.matches(in: sanitized, range: range)
            for match in matches.reversed() {
                if let range = Range(match.range, in: sanitized) {
                    let mac = String(sanitized[range])
                    let parts = mac.split(separator: mac.contains(":") ? ":" : "-")
                    if parts.count == 6 {
                        let separator = mac.contains(":") ? ":" : "-"
                        let masked = "\(parts[0])\(separator)\(parts[1])\(separator)\(parts[2])\(separator)<MAC>"
                        sanitized.replaceSubrange(range, with: masked)
                    }
                }
            }
        }

        // Mask UUIDs (keep first 8 chars for correlation)
        let uuidPattern = "\\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\b"
        if let regex = try? NSRegularExpression(pattern: uuidPattern) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            let matches = regex.matches(in: sanitized, range: range)
            for match in matches.reversed() {
                if let range = Range(match.range, in: sanitized) {
                    let uuid = String(sanitized[range])
                    let prefix = String(uuid.prefix(8))
                    sanitized.replaceSubrange(range, with: "\(prefix)-<UUID>")
                }
            }
        }

        // Mask API keys and tokens (common patterns)
        let apiKeyPatterns = [
            "sk_live_[a-zA-Z0-9]+",      // Stripe live keys
            "sk_test_[a-zA-Z0-9]+",      // Stripe test keys
            "Bearer [a-zA-Z0-9_\\-\\.]+", // Bearer tokens
            "token[=:][a-zA-Z0-9_\\-]+",  // Generic tokens
            "api_key[=:][a-zA-Z0-9_\\-]+", // API keys
        ]

        for pattern in apiKeyPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    range: NSRange(sanitized.startIndex..., in: sanitized),
                    withTemplate: "<API_KEY>"
                )
            }
        }

        // Mask password fields (common patterns in logs)
        let passwordPatterns = [
            "password[=:][^\\s]+",
            "pwd[=:][^\\s]+",
            "pass[=:][^\\s]+",
            "secret[=:][^\\s]+",
        ]

        for pattern in passwordPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    range: NSRange(sanitized.startIndex..., in: sanitized),
                    withTemplate: "<PASSWORD>"
                )
            }
        }

        // Mask credit card numbers (PAN)
        let ccPattern = "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b"
        if let regex = try? NSRegularExpression(pattern: ccPattern) {
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "<CARD_NUMBER>"
            )
        }

        return sanitized
    }

    /// Write log entry to file
    ///
    /// - Parameter entry: The log entry to write
    ///
    /// # Note:
    /// This method is called on a background queue and handles
    /// log rotation automatically when file size exceeds limit.
    private func writeToFile(_ entry: String) {
        // Check file size and rotate if necessary
        rotateLogIfNeeded()

        let logLine = entry + "\n"

        guard let data = logLine.data(using: .utf8) else { return }

        // Append to file or create new file
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }

    /// Rotate log file if it exceeds maximum size
    ///
    /// Creates a backup of the current log file with timestamp
    /// and starts a new log file.
    private func rotateLogIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? UInt64,
              fileSize > maxLogFileSize else {
            return
        }

        // Create backup filename with timestamp
        let timestamp = dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = logFileURL.deletingPathExtension()
            .appendingPathExtension("backup-\(timestamp).log")

        // Move current log to backup
        try? FileManager.default.moveItem(at: logFileURL, to: backupURL)

        // Create new empty log file
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
    }

    /// Get the current log file contents
    ///
    /// - Returns: String containing all log entries, or nil if file doesn't exist
    func getLogContents() -> String? {
        return try? String(contentsOf: logFileURL, encoding: .utf8)
    }

    /// Export logs to a specified URL
    ///
    /// - Parameter destinationURL: Where to copy the log file
    /// - Throws: File operation errors
    func exportLogs(to destinationURL: URL) throws {
        try FileManager.default.copyItem(at: logFileURL, to: destinationURL)
    }

    /// Clear all log files
    ///
    /// Deletes the main log file and all backups
    func clearLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            // Delete main log file
            try? FileManager.default.removeItem(at: self.logFileURL)

            // Delete backup files
            if let logsDirectory = self.logFileURL.deletingLastPathComponent() as URL?,
               let files = try? FileManager.default.contentsOfDirectory(
                at: logsDirectory,
                includingPropertiesForKeys: nil
               ) {
                for file in files where file.pathExtension == "log" {
                    try? FileManager.default.removeItem(at: file)
                }
            }

            self.log("Logs cleared", level: .info)
        }
    }
}

// MARK: - Convenience Methods

extension LoggingManager {
    /// Log debug information
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }

    /// Log informational message
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }

    /// Log warning
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }

    /// Log error
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }

    /// Log critical failure
    func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, file: file, function: function, line: line)
    }
}
