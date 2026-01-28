# HomeKit Adopter

A comprehensive tvOS application for discovering and analyzing HomeKit, Matter, and network devices on Apple TV. Features advanced network scanning capabilities, security auditing, and device management tools.

![Version](https://img.shields.io/badge/version-4.2-blue.svg)
![Platform](https://img.shields.io/badge/platform-tvOS%2016%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/swift-5.9-orange.svg)
![Status](https://img.shields.io/badge/status-Production-green.svg)

## Purpose

HomeKit Adopter is designed for network administrators, smart home enthusiasts, and IT professionals who need to:

- **Discover HomeKit and Matter devices** on the local network
- **Identify unadopted devices** that aren't yet paired with HomeKit
- **Audit network security** of smart home devices
- **Monitor network health** with ping and port scanning tools
- **Track device changes** over time with history logging
- **Export device data** for documentation and analysis

**Key Use Cases:**
- Smart home setup and troubleshooting
- Network security assessment
- Device inventory management
- Matter device commissioning detection
- Network topology analysis

## Features

### Network Discovery (22 Features Implemented)

#### Bonjour/mDNS Service Discovery
- **HomeKit (HAP)** - `_hap._tcp` service detection
- **Matter Commissioning** - `_matterc._udp` for unadopted Matter devices
- **Matter Operational** - `_matter._tcp` for paired Matter devices
- **Google Cast/Home** - Chromecast, Google Home, Nest devices
- **UniFi Network** - Ubiquiti discovery and NVR devices
- **AirPlay** - Apple TV and AirPlay-enabled speakers

#### Advanced Device Detection
- **Confidence Scoring** - Intelligent matching against adopted accessories
- **TXT Record Parsing** - Extracts setup codes, firmware versions, capabilities
- **Status Flag Analysis** - Determines pairing state from HAP status flags
- **Multi-Factor Matching** - Combines name, MAC, manufacturer for accuracy

#### Device Information
- Device name and model
- IP address and port
- MAC address / Device ID
- Manufacturer detection
- Service type categorization
- TXT record metadata

### Network Tools

#### Port Scanner
- Custom port range scanning (1-65535)
- Common ports presets (HTTP, HTTPS, SSH, Telnet)
- Smart home ports (8080, 8443, 51827)
- Concurrent scanning for speed
- Service identification for open ports

#### ARP Scanner
- Full subnet scanning (192.168.x.x/24)
- MAC address discovery
- Vendor lookup from OUI database
- Device fingerprinting
- Network topology mapping

#### Ping Monitor
- Continuous latency monitoring
- Packet loss detection
- Response time graphing
- Network health alerts
- Multiple host monitoring

#### Network Diagnostics
- Connectivity testing
- DNS resolution checks
- Gateway reachability
- Internet access verification

### Security Audit

#### Vulnerability Assessment
- Open port detection on smart devices
- Default credential warnings
- Encryption status checking
- Firmware version tracking
- Security recommendations

#### Device Security Score
- Risk level categorization (Low/Medium/High)
- Actionable security recommendations
- Best practices guidance
- Privacy risk assessment

### Data Management

#### Device History
- Change tracking over time
- First seen / last seen timestamps
- Adoption status history
- Notes and tags per device
- Custom labels for organization

#### Export Capabilities
- CSV export for spreadsheets
- JSON export for APIs/automation
- Privacy options - redact MAC, obfuscate IP
- Filtered exports by category

### User Interface

#### Modern Glassmorphic Design
- Dark theme optimized for TV viewing
- Animated backgrounds with glass effects
- Color-coded status indicators
- Large, TV-friendly controls
- Focus-based navigation

#### Dashboard
- Real-time statistics
- Device category breakdown
- Network health indicators
- Recent activity feed
- Circular progress gauges

#### Tab-Based Navigation
1. **Scanner** - Main device discovery
2. **Dashboard** - Statistics and insights
3. **Tools** - Port scanner, ARP, Ping
4. **More** - Settings, Export, History

## Requirements

- Apple TV HD or Apple TV 4K
- tvOS 16.0 or later
- Active network connection
- HomeKit access (optional)

## Installation

### From Xcode (Development)
1. Clone the repository
2. Open `HomeKitAdopter.xcodeproj` in Xcode
3. Select your Apple TV as the destination
4. Build and run

### Manual Installation
1. Build the app from Xcode
2. Use `xcrun devicectl device install app` to install
3. Grant HomeKit permissions when prompted

## Architecture

### Technology Stack
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **Network Discovery**: Network.framework (NWBrowser)
- **HomeKit Integration**: HomeKit.framework
- **Data Persistence**: UserDefaults, Keychain
- **Platform**: tvOS 16+

### Project Structure
```
HomeKitAdopter/
├── HomeKitAdopter/
│   ├── HomeKitAdopterApp.swift      # App entry point
│   ├── ContentView.swift            # Main tab view
│   ├── ModernDesign.swift           # Glassmorphic UI components
│   ├── PlatformHelpers.swift        # tvOS helpers
│   ├── Views/
│   │   ├── ScannerView.swift        # Device scanner
│   │   ├── DashboardView.swift      # Statistics dashboard
│   │   ├── ToolsView.swift          # Network tools
│   │   ├── MoreView.swift           # Settings & export
│   │   ├── PortScannerView.swift    # Port scanning UI
│   │   ├── ARPScannerView.swift     # ARP scanning UI
│   │   ├── PingMonitorView.swift    # Ping monitoring UI
│   │   └── ...more views
│   ├── Managers/
│   │   ├── NetworkDiscoveryManager.swift  # Bonjour discovery
│   │   ├── HomeManagerWrapper.swift       # HomeKit integration
│   │   ├── PortScannerManager.swift       # Port scanning
│   │   ├── ARPScannerManager.swift        # ARP scanning
│   │   ├── PingMonitorManager.swift       # Ping monitoring
│   │   ├── SecurityAuditManager.swift     # Security checks
│   │   ├── DeviceHistoryManager.swift     # History tracking
│   │   ├── ExportManager.swift            # CSV/JSON export
│   │   └── ...more managers
│   ├── Security/
│   │   ├── SecureStorageManager.swift     # Keychain storage
│   │   ├── InputValidator.swift           # Input validation
│   │   └── NetworkSecurityValidator.swift # Security checks
│   └── Assets.xcassets/                   # App icons
├── README.md
├── LICENSE
└── HomeKitAdopter.xcodeproj
```

## Discovered Services

| Service Type | Description |
|-------------|-------------|
| `_hap._tcp` | HomeKit Accessory Protocol |
| `_matterc._udp` | Matter Commissioning Mode |
| `_matter._tcp` | Matter Operational |
| `_googlecast._tcp` | Google Chromecast |
| `_googleremoter._tcp` | Google Remote |
| `_googlezone._tcp` | Google Home/Nest |
| `_nest._tcp` | Nest Devices |
| `_ubnt-disc._udp` | Ubiquiti/UniFi |
| `_nvr._tcp` | UniFi Protect NVR |
| `_airplay._tcp` | AirPlay Video |
| `_raop._tcp` | AirPlay Audio |

## Performance

- **Memory efficient** - Bounded device arrays with LRU eviction
- **Cached confidence scores** - Avoid recalculation
- **Non-blocking scans** - Background discovery
- **Efficient UI updates** - SwiftUI diffing
- **Network efficient** - Smart polling intervals

## Version History

### Version 4.2 (2026-01-28)
- Fixed project configuration for tvOS
- Updated build settings and deployment target
- Improved documentation

### Version 4.0-4.1
- Complete UI redesign with glassmorphic theme
- Added confidence scoring algorithm
- Enhanced device matching
- Export privacy options

### Version 3.0
- Added Port Scanner, ARP Scanner, Ping Monitor
- Security audit features

### Version 2.0
- Multi-service discovery
- Dashboard statistics
- Device notes and tags

### Version 1.0 (2025-09-29)
- Initial release

## License

MIT License - Copyright (c) 2025-2026 Jordan Koch

## Author

**Jordan Koch** - GitHub: [@kochj23](https://github.com/kochj23)

---

*HomeKit Adopter - Comprehensive smart home network analysis for Apple TV*

**Last Updated:** January 28, 2026
