//
//  FeatureViews.swift
//  HomeKitAdopter
//
//  Created by Jordan Koch on 2025-11-22.
//  Copyright © 2025 Jordan Koch. All rights reserved.
//

import SwiftUI

// MARK: - Export Views

struct ExportSheetView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager
    @Environment(\.dismiss) var dismiss
    @State private var exportFormat: ExportFormat = .csv
    @State private var privacyOptions = ExportManager.PrivacyOptions.none

    enum ExportFormat {
        case csv, json
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $exportFormat) {
                        Text("CSV").tag(ExportFormat.csv)
                        Text("JSON").tag(ExportFormat.json)
                    }
                }

                Section("Privacy Options") {
                    Toggle("Redact MAC Addresses", isOn: Binding(
                        get: { privacyOptions.redactMAC },
                        set: { privacyOptions.redactMAC = $0 }
                    ))
                    Toggle("Obfuscate IP Addresses", isOn: Binding(
                        get: { privacyOptions.obfuscateIP },
                        set: { privacyOptions.obfuscateIP = $0 }
                    ))
                    Toggle("Anonymize Device Names", isOn: Binding(
                        get: { privacyOptions.anonymizeNames },
                        set: { privacyOptions.anonymizeNames = $0 }
                    ))
                }

                Section {
                    Button("Export \(networkDiscovery.discoveredDevices.count) Devices") {
                        performExport()
                    }
                }
            }
            .navigationTitle("Export Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func performExport() {
        let exportManager = ExportManager.shared
        let devices = networkDiscovery.discoveredDevices
        
        switch exportFormat {
        case .csv:
            let csv = exportManager.exportToCSV(devices: devices, privacyOptions: privacyOptions)
            LoggingManager.shared.info("CSV Export generated: \(csv.count) bytes")
        case .json:
            if let json = exportManager.exportToJSON(devices: devices, privacyOptions: privacyOptions) {
                LoggingManager.shared.info("JSON Export generated: \(json.count) bytes")
            }
        }
        
        dismiss()
    }
}

// MARK: - Security Audit Views

struct SecurityAuditListView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager
    @State private var showAllDevices = false

    var filteredDevices: [NetworkDiscoveryManager.DiscoveredDevice] {
        if showAllDevices {
            return networkDiscovery.discoveredDevices
        } else {
            return networkDiscovery.discoveredDevices.filter { device in
                switch device.serviceType.category {
                case .smarthome, .google, .unifi:
                    return true
                default:
                    return false
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Security Audit")
                        .font(.system(size: 48, weight: .bold))

                    Spacer()

                    Button(action: { showAllDevices.toggle() }) {
                        HStack(spacing: 8) {
                            Image(systemName: showAllDevices ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                            Text("Show All")
                                .font(.system(size: 18))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                VStack(spacing: 16) {
                    ForEach(filteredDevices) { device in
                        NavigationLink(destination: SecurityAuditDetailView(device: device)) {
                            HStack(spacing: 16) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.red)
                                    .frame(width: 60, height: 60)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(device.name)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("Tap to run security audit")
                                        .font(.system(size: 18))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }
                            .padding(20)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

struct SecurityAuditDetailView: View {
    let device: NetworkDiscoveryManager.DiscoveredDevice
    @State private var report: SecurityAuditManager.SecurityReport?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(device.name)
                        .font(.system(size: 48, weight: .bold))
                    Text("Security Audit Report")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                if let report = report {
                    // Risk Level Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 20) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 48))
                                .foregroundColor(colorForRisk(report.overallRisk))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Overall Risk Level")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(report.overallRisk.rawValue)
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(colorForRisk(report.overallRisk))
                            }
                        }

                        // Issue counts
                        HStack(spacing: 16) {
                            if report.criticalCount > 0 {
                                issueCountBadge(count: report.criticalCount, label: "Critical", color: .red)
                            }
                            if report.highCount > 0 {
                                issueCountBadge(count: report.highCount, label: "High", color: .orange)
                            }
                            if report.mediumCount > 0 {
                                issueCountBadge(count: report.mediumCount, label: "Medium", color: .yellow)
                            }
                            if report.lowCount > 0 {
                                issueCountBadge(count: report.lowCount, label: "Low", color: .blue)
                            }
                        }
                    }
                    .padding(28)
                    .background(colorForRisk(report.overallRisk).opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)

                    // Issues List
                    if report.issues.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.green)
                            Text("No Security Issues Found")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.green)
                            Text("This device passed all security checks")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Security Issues (\(report.issues.count))")
                                .font(.system(size: 32, weight: .bold))
                                .padding(.horizontal, 40)

                            ForEach(report.issues, id: \.title) { issue in
                                issueCard(issue: issue)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }

                    // Timestamp
                    Text("Report generated: \(formatDate(report.generatedAt))")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2.0)
                        Text("Running Security Audit...")
                            .font(.system(size: 28, weight: .semibold))
                        Text("Analyzing device for vulnerabilities and security issues")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }
            }
        }
        .focusable()
        .onAppear {
            runAudit()
        }
    }

    private func issueCountBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.15))
        .cornerRadius(10)
    }

    private func issueCard(issue: SecurityAuditManager.SecurityIssue) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: severityIcon(issue.severity))
                    .font(.system(size: 28))
                    .foregroundColor(severityColor(issue.severity))

                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.system(size: 24, weight: .bold))
                    HStack(spacing: 12) {
                        Text(issue.severity.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(severityColor(issue.severity))
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(issue.category.rawValue)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let cve = issue.cveID {
                    Text(cve)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)
                }
            }

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 12) {
                Text("Description")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(issue.description)
                    .font(.system(size: 20))
            }

            // Recommendation
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommendation")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(issue.recommendation)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
        }
        .padding(24)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(severityColor(issue.severity).opacity(0.3), lineWidth: 2)
        )
    }

    private func runAudit() {
        let manager = SecurityAuditManager.shared
        report = manager.auditDevice(device)
    }

    private func colorForRisk(_ risk: SecurityAuditManager.SecurityReport.RiskLevel) -> Color {
        switch risk {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        }
    }

    private func severityColor(_ severity: SecurityAuditManager.SecurityIssue.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }

    private func severityIcon(_ severity: SecurityAuditManager.SecurityIssue.Severity) -> String {
        switch severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.circle"
        case .low: return "info.circle"
        case .info: return "info.circle.fill"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Network Diagnostics Views

struct NetworkDiagnosticsListView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager
    @State private var showAllDevices = false

    var filteredDevices: [NetworkDiscoveryManager.DiscoveredDevice] {
        if showAllDevices {
            return networkDiscovery.discoveredDevices
        } else {
            // Filter to only smart home devices (HomeKit, Matter, Google, Nest, UniFi)
            return networkDiscovery.discoveredDevices.filter { device in
                switch device.serviceType.category {
                case .smarthome, .google, .unifi:
                    return true
                default:
                    return false
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Network Diagnostics")
                        .font(.system(size: 48, weight: .bold))

                    Spacer()

                    Button(action: { showAllDevices.toggle() }) {
                        HStack(spacing: 8) {
                            Image(systemName: showAllDevices ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                            Text("Show All")
                                .font(.system(size: 18))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                if filteredDevices.isEmpty {
                    // No devices at all
                    VStack(spacing: 24) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)

                        VStack(spacing: 12) {
                            Text("No Devices Discovered")
                                .font(.system(size: 32, weight: .bold))

                            Text("Run a network scan to discover devices")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(60)
                } else {
                    // Show filtered devices - we'll resolve IPs on-demand
                    HStack {
                        Text("\(filteredDevices.count) smart home devices")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)

                        if !showAllDevices && filteredDevices.count < networkDiscovery.discoveredDevices.count {
                            Text("(\(networkDiscovery.discoveredDevices.count - filteredDevices.count) filtered)")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 40)

                    VStack(spacing: 16) {
                        ForEach(filteredDevices) { device in
                            NavigationLink(destination: NetworkDiagnosticsDetailView(device: device)) {
                                HStack(spacing: 16) {
                                    Image(systemName: "stethoscope")
                                        .font(.system(size: 32))
                                        .foregroundColor(.green)
                                        .frame(width: 60, height: 60)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(12)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(device.name)
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundColor(.primary)
                                        if let host = device.host {
                                            Text(host)
                                                .font(.system(size: 18))
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("IP will be resolved")
                                                .font(.system(size: 18))
                                                .foregroundColor(.orange)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                }
                                .padding(20)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.card)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
    }
}

struct NetworkDiagnosticsDetailView: View {
    let device: NetworkDiscoveryManager.DiscoveredDevice
    @StateObject private var diagnosticsManager = NetworkDiagnosticsManager.shared
    @State private var result: NetworkDiagnosticsManager.DiagnosticResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(device.name)
                        .font(.system(size: 48, weight: .bold))
                    if let host = device.host {
                        Text(host)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                // Run Diagnostics Button
                Button(action: { runDiagnostics() }) {
                    HStack(spacing: 12) {
                        Image(systemName: diagnosticsManager.isRunningDiagnostics ? "arrow.triangle.2.circlepath" : "play.circle.fill")
                            .font(.system(size: 28))
                        Text(diagnosticsManager.isRunningDiagnostics ? "Running Diagnostics..." : "Run Diagnostics")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(diagnosticsManager.isRunningDiagnostics ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                .disabled(diagnosticsManager.isRunningDiagnostics)
                .padding(.horizontal, 40)

                // Progress Bar
                if diagnosticsManager.isRunningDiagnostics {
                    VStack(spacing: 12) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 16)

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * diagnosticsManager.currentProgress, height: 16)
                            }
                        }
                        .frame(height: 16)

                        Text("\(Int(diagnosticsManager.currentProgress * 100))% Complete")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 40)
                }

                // Results
                if let result = result {
                    diagnosticsResults(result)
                }
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            loadCachedResult()
        }
    }

    @ViewBuilder
    private func diagnosticsResults(_ result: NetworkDiagnosticsManager.DiagnosticResult) -> some View {
        VStack(spacing: 24) {
            // Connection Quality Card
            HStack(spacing: 32) {
                Image(systemName: result.connectionQuality.icon)
                    .font(.system(size: 64))
                    .foregroundColor(colorForQuality(result.connectionQuality))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection Quality")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(result.connectionQuality.rawValue)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(colorForQuality(result.connectionQuality))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(32)
            .background(colorForQuality(result.connectionQuality).opacity(0.1))
            .cornerRadius(20)
            .padding(.horizontal, 40)

            // Latency Statistics
            VStack(alignment: .leading, spacing: 20) {
                Text("Latency Statistics")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 40)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statBox(title: "Average", value: "\(Int(result.averageLatency ?? 0))ms", icon: "clock", color: .blue)
                    statBox(title: "Min", value: "\(Int(result.minLatency ?? 0))ms", icon: "arrow.down", color: .green)
                    statBox(title: "Max", value: "\(Int(result.maxLatency ?? 0))ms", icon: "arrow.up", color: .orange)
                    statBox(title: "Jitter", value: "\(Int(result.jitter ?? 0))ms", icon: "waveform.path.ecg", color: .purple)
                }
                .padding(.horizontal, 40)
            }

            // Packet Loss
            if let packetLoss = result.packetLoss {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Packet Loss")
                        .font(.system(size: 28, weight: .bold))

                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(String(format: "%.1f", packetLoss))%")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(packetLoss > 10 ? .red : .green)
                            Text(packetLoss > 10 ? "High Packet Loss" : "Normal")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Visual indicator
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                                .frame(width: 120, height: 120)

                            Circle()
                                .trim(from: 0, to: CGFloat(min(packetLoss / 100, 1.0)))
                                .stroke(packetLoss > 10 ? Color.red : Color.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))
                        }
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 40)
            }

            // Port Scan Results
            VStack(alignment: .leading, spacing: 16) {
                Text("Port Scan Results")
                    .font(.system(size: 28, weight: .bold))

                HStack(spacing: 16) {
                    // Open Ports
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Open Ports (\(result.openPorts.count))")
                                .font(.system(size: 20, weight: .semibold))
                        }

                        if result.openPorts.isEmpty {
                            Text("No open ports detected")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(result.openPorts, id: \.self) { port in
                                HStack {
                                    Text("\(port)")
                                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                                    Text(portDescription(port))
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)

                    // Closed Ports
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                            Text("Closed Ports (\(result.closedPorts.count))")
                                .font(.system(size: 20, weight: .semibold))
                        }

                        if result.closedPorts.isEmpty {
                            Text("All ports open")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(result.closedPorts.prefix(5), id: \.self) { port in
                                Text("\(port)")
                                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            if result.closedPorts.count > 5 {
                                Text("+\(result.closedPorts.count - 5) more")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)

            // Timestamp
            Text("Last tested: \(formatDate(result.timestamp))")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
        }
    }

    private func statBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }

    private func runDiagnostics() {
        Task {
            await diagnosticsManager.runComprehensiveDiagnostics(device)
            loadCachedResult()
        }
    }

    private func loadCachedResult() {
        let deviceKey = "\(device.name)-\(device.serviceType.rawValue)"
        result = diagnosticsManager.getDiagnosticResult(for: deviceKey)
    }

    private func colorForQuality(_ quality: NetworkDiagnosticsManager.DiagnosticResult.ConnectionQuality) -> Color {
        switch quality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .offline: return .red
        }
    }

    private func portDescription(_ port: Int) -> String {
        switch port {
        case 80: return "HTTP"
        case 443: return "HTTPS"
        case 5353: return "mDNS"
        case 8080: return "HTTP Alt"
        case 8883: return "MQTT/TLS"
        case 5540: return "Matter"
        default: return "Custom"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Other Feature Views (Placeholders)

struct FirmwareCheckView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager

    var body: some View {
        List(networkDiscovery.discoveredDevices) { device in
            VStack(alignment: .leading) {
                Text(device.name)
                    .font(.headline)
                if let firmware = FirmwareManager.shared.extractFirmware(from: device) {
                    Text("Version: \(firmware.version)")
                        .font(.caption)
                        .foregroundColor(firmware.isOutdated ? .red : .green)
                } else {
                    Text("No firmware info")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Firmware Check")
    }
}

struct DeviceHistoryListView: View {
    @StateObject private var historyManager = DeviceHistoryManager.shared
    @State private var showingExport = false
    @State private var selectedRecord: DeviceHistoryManager.DeviceRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Device History")
                        .font(.system(size: 48, weight: .bold))
                    Text("\(historyManager.deviceHistory.count) devices tracked")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                // Statistics
                HStack(spacing: 20) {
                    statCard(
                        title: "Total Devices",
                        value: "\(historyManager.deviceHistory.count)",
                        icon: "clock.arrow.circlepath",
                        color: .blue
                    )

                    statCard(
                        title: "Recently Adopted",
                        value: "\(historyManager.getRecentlyAdoptedDevices().count)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    statCard(
                        title: "Never Adopted",
                        value: "\(historyManager.getNeverAdoptedDevices().count)",
                        icon: "xmark.circle",
                        color: .orange
                    )
                }
                .padding(.horizontal, 40)

                // Export Button
                Button(action: { showingExport = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                        Text("Export History")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)

                // Device List
                if historyManager.deviceHistory.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("No Device History")
                            .font(.system(size: 28, weight: .bold))
                        Text("Discovered devices will appear here")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(60)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("All Tracked Devices")
                            .font(.system(size: 32, weight: .bold))
                            .padding(.horizontal, 40)

                        LazyVStack(spacing: 16) {
                            ForEach(Array(historyManager.deviceHistory.values.sorted(by: { $0.lastSeen > $1.lastSeen }))) { record in
                                Button(action: { selectedRecord = record }) {
                                    deviceHistoryCard(record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingExport) {
            exportSheet
        }
        .sheet(item: $selectedRecord) { record in
            DeviceHistoryDetailSheet(record: record)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }

    private func deviceHistoryCard(_ record: DeviceHistoryManager.DeviceRecord) -> some View {
        HStack(spacing: 20) {
            // Status icon
            Image(systemName: record.currentAdoptionStatus ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 36))
                .foregroundColor(record.currentAdoptionStatus ? .green : .orange)
                .frame(width: 60, height: 60)
                .background((record.currentAdoptionStatus ? Color.green : Color.orange).opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 8) {
                Text(record.name)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 16) {
                    Label(formatRelativeDate(record.firstSeen), systemImage: "clock")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)

                    if record.wasRecentlyAdopted {
                        Label("Recently Adopted", systemImage: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }

                if !record.ipAddresses.isEmpty {
                    Text(record.ipAddresses.last ?? "")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text("\(record.adoptionHistory.count)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.purple)
                Text("events")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private var exportSheet: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Export Device History")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.top, 30)

                if let jsonData = historyManager.exportAsJSON() {
                    ScrollView {
                        Text(jsonData)
                            .font(.system(size: 14, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .frame(maxHeight: 400)
                    .padding(.horizontal, 40)

                    Text("Copy this JSON data to save your device history")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                } else {
                    Text("Failed to export history")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                }

                Button("Done") {
                    showingExport = false
                }
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Spacer()
            }
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "First seen " + formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DeviceHistoryDetailSheet: View {
    let record: DeviceHistoryManager.DeviceRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.name)
                                .font(.system(size: 36, weight: .bold))

                            HStack(spacing: 12) {
                                Label(
                                    record.currentAdoptionStatus ? "Adopted" : "Not Adopted",
                                    systemImage: record.currentAdoptionStatus ? "checkmark.circle.fill" : "circle.dashed"
                                )
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(record.currentAdoptionStatus ? .green : .orange)

                                if record.wasRecentlyAdopted {
                                    Label("Recently", systemImage: "sparkles")
                                        .font(.system(size: 18))
                                        .foregroundColor(.purple)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 30)

                    // Device Info
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Device Information")
                            .font(.system(size: 24, weight: .bold))

                        infoRow(label: "Service Type", value: record.serviceType)
                        infoRow(label: "First Seen", value: formatDate(record.firstSeen))
                        infoRow(label: "Last Seen", value: formatDate(record.lastSeen))
                        infoRow(label: "Duration", value: formatDuration(record.durationSeen))

                        if let manufacturer = record.manufacturer {
                            infoRow(label: "Manufacturer", value: manufacturer)
                        }

                        if let model = record.modelInfo {
                            infoRow(label: "Model", value: model)
                        }
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)

                    // IP Address History
                    if !record.ipAddresses.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("IP Address History")
                                .font(.system(size: 24, weight: .bold))

                            ForEach(record.ipAddresses, id: \.self) { ip in
                                HStack {
                                    Image(systemName: "network")
                                        .foregroundColor(.blue)
                                    Text(ip)
                                        .font(.system(size: 18, design: .monospaced))
                                }
                                .padding(12)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 40)
                    }

                    // Adoption Events
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Adoption History (\(record.adoptionHistory.count) events)")
                            .font(.system(size: 24, weight: .bold))

                        ForEach(Array(record.adoptionHistory.enumerated()), id: \.offset) { index, event in
                            HStack {
                                Image(systemName: event.wasAdopted ? "checkmark.circle.fill" : "xmark.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(event.wasAdopted ? .green : .red)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.wasAdopted ? "Adopted" : "Not Adopted")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text(formatDate(event.date))
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("Confidence: \(event.confidenceScore)%")
                                    .font(.system(size: 16))
                                    .foregroundColor(.purple)
                            }
                            .padding(16)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(.system(size: 18, weight: .medium))
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute]
        return formatter.string(from: interval) ?? "Unknown"
    }
}

struct ScanSchedulerView: View {
    @StateObject private var scheduler = ScanSchedulerManager.shared

    var body: some View {
        Form {
            Section("Schedule") {
                Toggle("Enable Scheduled Scans", isOn: Binding(
                    get: { scheduler.schedule.isEnabled },
                    set: { scheduler.schedule.isEnabled = $0 }
                ))

                Picker("Interval", selection: Binding(
                    get: { scheduler.schedule.interval },
                    set: { scheduler.schedule.interval = $0 }
                )) {
                    Text("Every 15 Minutes").tag(0)
                    Text("Every 30 Minutes").tag(1)
                    Text("Hourly").tag(2)
                    Text("Every 6 Hours").tag(3)
                    Text("Daily").tag(4)
                }
            }

            Section("Statistics") {
                Text("Total Scans: \(scheduler.schedule.scanHistory.count)")
            }
        }
        .navigationTitle("Scan Scheduler")
    }
}

struct QRCodeListView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager

    var body: some View {
        List(networkDiscovery.discoveredDevices) { device in
            VStack(alignment: .leading) {
                Text(device.name)
                if QRCodeManager.shared.extractSetupCode(from: device) != nil {
                    Text("QR code available")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("No QR code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("QR Codes")
    }
}

struct PairingInstructionsListView: View {
    var body: some View {
        List {
            Text("Device pairing instructions")
        }
        .navigationTitle("Pairing Guides")
    }
}

struct DeviceNotesListView: View {
    var body: some View {
        List {
            Text("Device notes and tags")
        }
        .navigationTitle("Device Notes")
    }
}

struct MultiHomeView: View {
    @StateObject private var homeManager = HomeManagerWrapper.shared

    var body: some View {
        List(homeManager.homes, id: \.uniqueIdentifier) { home in
            VStack(alignment: .leading) {
                Text(home.name)
                    .font(.headline)
                Text("\(home.accessories.count) accessories")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Multi-Home")
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section("Data Protection") {
                Text("Privacy settings")
            }
        }
        .navigationTitle("Privacy")
    }
}

struct LogsViewerView: View {
    var body: some View {
        ScrollView {
            Text("System logs would appear here")
                .font(.system(.caption, design: .monospaced))
                .padding()
        }
        .navigationTitle("Logs")
    }
}

struct SettingsSheetView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("App Settings") {
                    Text("App preferences")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Settings view for tvOS navigation
struct SettingsView: View {
    @StateObject private var scanScheduler = ScanSchedulerManager.shared
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enableAutoScan") private var enableAutoScan = false
    @AppStorage("scanOnLaunch") private var scanOnLaunch = true
    @AppStorage("showUnadoptedOnly") private var showUnadoptedOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.system(size: 48, weight: .bold))
                    Text("App Preferences")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)

                // General Settings
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                        Text("General")
                            .font(.system(size: 32, weight: .bold))
                    }
                    .padding(.horizontal, 40)

                    VStack(spacing: 16) {
                        settingToggle(
                            title: "Scan on Launch",
                            description: "Automatically scan network when app starts",
                            isOn: $scanOnLaunch,
                            icon: "antenna.radiowaves.left.and.right",
                            color: .blue
                        )

                        settingToggle(
                            title: "Show Unadopted Only",
                            description: "Filter to show only devices not yet adopted",
                            isOn: $showUnadoptedOnly,
                            icon: "line.3.horizontal.decrease.circle",
                            color: .orange
                        )

                        settingToggle(
                            title: "Enable Notifications",
                            description: "Receive alerts for new devices and security issues",
                            isOn: $enableNotifications,
                            icon: "bell.fill",
                            color: .purple
                        )
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                }

                // Scanning Settings
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "wifi")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                        Text("Network Scanning")
                            .font(.system(size: 32, weight: .bold))
                    }
                    .padding(.horizontal, 40)

                    VStack(spacing: 16) {
                        settingToggle(
                            title: "Automatic Scanning",
                            description: "Enable scheduled network scans",
                            isOn: $enableAutoScan,
                            icon: "clock.arrow.circlepath",
                            color: .green
                        )

                        if enableAutoScan {
                            HStack(spacing: 16) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Scan Schedule")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Configure scheduled scans in More > Scan Scheduler")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(20)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                }

                // App Info
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.cyan)
                        Text("About")
                            .font(.system(size: 32, weight: .bold))
                    }
                    .padding(.horizontal, 40)

                    VStack(spacing: 16) {
                        infoRow(label: "Version", value: "4.1")
                        infoRow(label: "Build", value: "2025.11.23")
                        infoRow(label: "Platform", value: "tvOS 16.0+")
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                }

                // Reset Options
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                        Text("Reset")
                            .font(.system(size: 32, weight: .bold))
                    }
                    .padding(.horizontal, 40)

                    Button(action: resetToDefaults) {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                            Text("Reset All Settings to Defaults")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.card)
                    .padding(24)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func settingToggle(title: String, description: String, isOn: Binding<Bool>, icon: String, color: Color) -> some View {
        Button(action: {
            isOn.wrappedValue.toggle()
        }) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.15))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 24, weight: .semibold))
                    Text(description)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .scaleEffect(1.3)
                    .allowsHitTesting(false)
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.card)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .semibold))
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func resetToDefaults() {
        enableNotifications = true
        enableAutoScan = false
        scanOnLaunch = true
        showUnadoptedOnly = false
        LoggingManager.shared.info("Settings reset to defaults")
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 100))
                .foregroundColor(.blue)

            Text("HomeKitAdopter 2.0")
                .font(.title)
                .bold()

            Text("Network Scanner for Unadopted Devices")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Created by Jordan Koch")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("November 2025")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("About")
    }
}

// MARK: - Device Comparison List View
struct DeviceComparisonListView: View {
    @ObservedObject var networkDiscovery: NetworkDiscoveryManager

    var body: some View {
        List {
            ForEach(networkDiscovery.discoveredDevices) { device in
                if let match = networkDiscovery.getBestMatchingAccessory(for: device), match.1 > 0.6 {
                    NavigationLink(destination: DeviceComparisonView(
                        discoveredDevice: device,
                        possibleMatch: match.0,
                        similarity: match.1,
                        onConfirmSame: {},
                        onConfirmDifferent: {}
                    )) {
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.headline)
                            Text("Match: \(match.0.name) (\(Int(match.1 * 100))%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Device Comparison")
    }
}
