import Foundation

public enum DeviceHubSection: String, Sendable, CaseIterable, Identifiable {
    case overview = "Overview"
    case devices = "Devices"
    case simulators = "Simulators"
    case platforms = "Platforms"
    case runtimes = "Runtimes"
    case groups = "Groups"
    case diagnostics = "Diagnostics"
    case settings = "Settings"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var systemImage: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .devices: return "iphone"
        case .simulators: return "ipad"
        case .platforms: return "square.stack.3d.down.right"
        case .runtimes: return "arrow.down.circle"
        case .groups: return "folder"
        case .diagnostics: return "stethoscope"
        case .settings: return "gearshape"
        }
    }

    public var showsCanvas: Bool {
        switch self {
        case .devices, .simulators: return true
        default: return false
        }
    }
}

public struct DeviceHubOverviewSnapshot: Sendable, Equatable {
    public var connectedPhysicalDevices: Int
    public var availableSimulators: Int
    public var bootedSimulators: Int
    public var installedPlatforms: [String]
    public var missingPlatforms: [String]
    public var installedRuntimes: Int
    public var availableRuntimes: Int
    public var xcodeVersion: String?
    public var xcodeBuild: String?
    public var developerDirectory: String?
    public var isXcodeInstalled: Bool
    public var isCommandLineToolsOnly: Bool
    public var hasScanned: Bool
    public var lastError: String?
    public var globalIssues: [String]

    public init(
        connectedPhysicalDevices: Int = 0,
        availableSimulators: Int = 0,
        bootedSimulators: Int = 0,
        installedPlatforms: [String] = [],
        missingPlatforms: [String] = [],
        installedRuntimes: Int = 0,
        availableRuntimes: Int = 0,
        xcodeVersion: String? = nil,
        xcodeBuild: String? = nil,
        developerDirectory: String? = nil,
        isXcodeInstalled: Bool = false,
        isCommandLineToolsOnly: Bool = false,
        hasScanned: Bool = false,
        lastError: String? = nil,
        globalIssues: [String] = []
    ) {
        self.connectedPhysicalDevices = connectedPhysicalDevices
        self.availableSimulators = availableSimulators
        self.bootedSimulators = bootedSimulators
        self.installedPlatforms = installedPlatforms
        self.missingPlatforms = missingPlatforms
        self.installedRuntimes = installedRuntimes
        self.availableRuntimes = availableRuntimes
        self.xcodeVersion = xcodeVersion
        self.xcodeBuild = xcodeBuild
        self.developerDirectory = developerDirectory
        self.isXcodeInstalled = isXcodeInstalled
        self.isCommandLineToolsOnly = isCommandLineToolsOnly
        self.hasScanned = hasScanned
        self.lastError = lastError
        self.globalIssues = globalIssues
    }

    public static var empty: DeviceHubOverviewSnapshot { DeviceHubOverviewSnapshot() }

    public var toolchainSummary: String {
        if !hasScanned {
            return "Toolchain has not been scanned yet."
        }
        if !isXcodeInstalled {
            return "Xcode is not installed. Install Xcode from the App Store, then select it with xcode-select."
        }
        if isCommandLineToolsOnly {
            return "Only the Command Line Tools are installed. Install full Xcode for simulator runtimes and SDKs."
        }
        if let version = xcodeVersion {
            return "Xcode \(version) is installed and selected."
        }
        return "Xcode is installed, but its version could not be read."
    }

    public var toolchainHealthy: Bool {
        hasScanned && isXcodeInstalled && !isCommandLineToolsOnly
    }

    public var xcodeDisplay: String {
        if let version = xcodeVersion {
            if let build = xcodeBuild { return "Xcode \(version) (\(build))" }
            return "Xcode \(version)"
        }
        return "Not installed"
    }

    public var developerDirectoryDisplay: String {
        guard let directory = developerDirectory, !directory.isEmpty else { return "Unknown" }
        return directory
    }
}
