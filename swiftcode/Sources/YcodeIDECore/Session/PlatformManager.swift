import Foundation
import Observation
import os
import YcodeDeviceModel
import YcodeXcodebuild

public enum PlatformInstallStatus: String, Sendable, Equatable, Hashable {
    case installed
    case partial
    case missing
}

public enum PlatformIssueKind: String, Sendable, Equatable, Hashable {
    case xcodeMissing
    case commandLineToolsOnly
    case sdkMissing
    case runtimeMissing
    case runtimeUnavailable
    case runtimeNewerThanSDK
    case deviceTypeMissing
    case discoveryFailed
}

public struct PlatformIssue: Sendable, Equatable, Hashable, Identifiable {
    public var id: String { kind.rawValue + ":" + message }
    public let kind: PlatformIssueKind
    public let message: String
    public let remediation: String

    public init(kind: PlatformIssueKind, message: String, remediation: String) {
        self.kind = kind
        self.message = message
        self.remediation = remediation
    }
}

public struct PlatformSDK: Sendable, Equatable, Hashable, Identifiable {
    public var id: String { canonicalName }
    public let canonicalName: String
    public let displayName: String
    public let version: String
    public let path: String
    public let platformPath: String
    public let isBaseSDK: Bool

    public init(entry: SDKEntry) {
        self.canonicalName = entry.canonicalName
        self.displayName = entry.displayName
        self.version = entry.version
        self.path = entry.path
        self.platformPath = entry.platformPath
        self.isBaseSDK = entry.isBaseSDK
    }
}

public enum PlatformRuntimeSource: String, Sendable, Equatable, Hashable {
    case diskBundle
    case simctl
    case merged
}

public struct PlatformRuntime: Sendable, Equatable, Hashable, Identifiable {
    public var id: String { identifier }
    public let identifier: String
    public let name: String
    public let version: String
    public let buildVersion: String?
    public let isAvailable: Bool
    public let path: String?
    public let source: PlatformRuntimeSource

    public init(identifier: String, name: String, version: String, buildVersion: String?, isAvailable: Bool, path: String?, source: PlatformRuntimeSource) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.buildVersion = buildVersion
        self.isAvailable = isAvailable
        self.path = path
        self.source = source
    }
}

public struct ManagedPlatform: Sendable, Equatable, Hashable, Identifiable {
    public var id: DevicePlatform { platform }
    public let platform: DevicePlatform
    public let status: PlatformInstallStatus
    public let sdks: [PlatformSDK]
    public let runtimes: [PlatformRuntime]
    public let installationLocations: [String]
    public let issues: [PlatformIssue]

    public init(platform: DevicePlatform, status: PlatformInstallStatus, sdks: [PlatformSDK], runtimes: [PlatformRuntime], installationLocations: [String], issues: [PlatformIssue]) {
        self.platform = platform
        self.status = status
        self.sdks = sdks
        self.runtimes = runtimes
        self.installationLocations = installationLocations
        self.issues = issues
    }

    public var displayName: String { platform.rawValue }

    public var versions: [String] {
        let all = sdks.map(\.version) + runtimes.map(\.version)
        return Array(Set(all)).sorted { PlatformCatalogBuilder.compareVersionStrings($0, $1) == .orderedAscending }
    }

    public var newestSDKVersion: String? {
        sdks.map(\.version).max { PlatformCatalogBuilder.compareVersionStrings($0, $1) == .orderedAscending }
    }

    public var hasAvailableRuntime: Bool {
        runtimes.contains { $0.isAvailable }
    }
}

public struct PlatformCatalogSnapshot: Sendable, Equatable {
    public let platforms: [ManagedPlatform]
    public let developerDirectory: String?
    public let xcodeVersion: String?
    public let xcodeBuild: String?
    public let isCommandLineToolsOnly: Bool
    public let isXcodeInstalled: Bool
    public let globalIssues: [PlatformIssue]
    public let discoveryError: String?
    public let hasScanned: Bool
    public let lastRefreshed: Date

    public init(platforms: [ManagedPlatform], developerDirectory: String?, xcodeVersion: String?, xcodeBuild: String?, isCommandLineToolsOnly: Bool, isXcodeInstalled: Bool, globalIssues: [PlatformIssue], discoveryError: String?, hasScanned: Bool, lastRefreshed: Date) {
        self.platforms = platforms
        self.developerDirectory = developerDirectory
        self.xcodeVersion = xcodeVersion
        self.xcodeBuild = xcodeBuild
        self.isCommandLineToolsOnly = isCommandLineToolsOnly
        self.isXcodeInstalled = isXcodeInstalled
        self.globalIssues = globalIssues
        self.discoveryError = discoveryError
        self.hasScanned = hasScanned
        self.lastRefreshed = lastRefreshed
    }

    public static var empty: PlatformCatalogSnapshot {
        PlatformCatalogSnapshot(
            platforms: PlatformCatalogBuilder.supportedPlatforms.map {
                ManagedPlatform(platform: $0, status: .missing, sdks: [], runtimes: [], installationLocations: [], issues: [])
            },
            developerDirectory: nil,
            xcodeVersion: nil,
            xcodeBuild: nil,
            isCommandLineToolsOnly: false,
            isXcodeInstalled: false,
            globalIssues: [],
            discoveryError: nil,
            hasScanned: false,
            lastRefreshed: Date(timeIntervalSince1970: 0)
        )
    }

    public func platform(_ platform: DevicePlatform) -> ManagedPlatform? {
        platforms.first { $0.platform == platform }
    }

    public var installedPlatforms: [ManagedPlatform] {
        platforms.filter { $0.status == .installed }
    }

    public var missingPlatforms: [ManagedPlatform] {
        platforms.filter { $0.status == .missing }
    }
}

public enum PlatformManagerError: Error, LocalizedError, Sendable, Equatable {
    case xcodeNotInstalled
    case commandLineToolsOnly(String)
    case discoveryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .xcodeNotInstalled:
            return "Xcode was not found."
        case .commandLineToolsOnly(let directory):
            return "Only the Xcode Command Line Tools are installed at \(directory)."
        case .discoveryFailed(let message):
            return "Simulator discovery failed: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .xcodeNotInstalled:
            return "Install Xcode from the App Store, then select it with xcode-select -s /Applications/Xcode.app/Contents/Developer."
        case .commandLineToolsOnly:
            return "Install full Xcode from the App Store, then select it with xcode-select -s /Applications/Xcode.app/Contents/Developer."
        case .discoveryFailed:
            return "Platforms found on disk are still listed. Check that simctl works by running xcrun simctl list runtimes."
        }
    }
}

public enum PlatformCatalogBuilder {
    public static let supportedPlatforms: [DevicePlatform] = [.iOS, .iPadOS, .watchOS, .tvOS, .visionOS, .macOS]

    public static func build(
        sdkEntries: [SDKEntry],
        diskRuntimes: [SimulatorRuntime],
        simctlRuntimes: [RuntimeDTO],
        deviceTypes: [DeviceTypeDTO],
        environment: DeveloperEnvironmentInfo,
        discoveryError: String? = nil,
        refreshedAt: Date = Date()
    ) -> PlatformCatalogSnapshot {
        let developerDirectory: String? = environment.developerDirectory == "Unavailable" ? nil : environment.developerDirectory
        let isXcodeInstalled = environment.isFullXcodeInstall

        var sdksByPlatform: [DevicePlatform: [PlatformSDK]] = [:]
        for entry in sdkEntries {
            guard let platform = platform(forSDKEntry: entry) else { continue }
            sdksByPlatform[platform, default: []].append(PlatformSDK(entry: entry))
        }
        for platform in sdksByPlatform.keys {
            sdksByPlatform[platform]?.sort { compareVersionStrings($0.version, $1.version) == .orderedAscending }
        }

        var mergedByIdentifier: [String: PlatformRuntime] = [:]
        var platformOfRuntime: [String: DevicePlatform] = [:]
        for runtime in diskRuntimes {
            guard let platform = parsePlatformName(runtime.platform) else { continue }
            platformOfRuntime[runtime.identifier] = platform
            mergedByIdentifier[runtime.identifier] = PlatformRuntime(
                identifier: runtime.identifier,
                name: runtime.name,
                version: runtime.version,
                buildVersion: nil,
                isAvailable: runtime.isAvailable,
                path: runtime.path,
                source: .diskBundle
            )
        }
        for dto in simctlRuntimes {
            guard let platform = platform(forSimctlRuntime: dto) else { continue }
            let existing = mergedByIdentifier[dto.identifier]
            platformOfRuntime[dto.identifier] = platform
            mergedByIdentifier[dto.identifier] = PlatformRuntime(
                identifier: dto.identifier,
                name: dto.name.isEmpty ? (existing?.name ?? dto.identifier) : dto.name,
                version: dto.version,
                buildVersion: dto.buildversion ?? existing?.buildVersion,
                isAvailable: dto.isAvailable,
                path: existing?.path,
                source: existing == nil ? .simctl : .merged
            )
        }
        var runtimesByPlatform: [DevicePlatform: [PlatformRuntime]] = [:]
        for (identifier, runtime) in mergedByIdentifier {
            guard let platform = platformOfRuntime[identifier] else { continue }
            runtimesByPlatform[platform, default: []].append(runtime)
        }
        for platform in runtimesByPlatform.keys {
            runtimesByPlatform[platform]?.sort { compareVersionStrings($0.version, $1.version) == .orderedAscending }
        }

        let hasIPadDeviceType = deviceTypes.contains { deviceType in
            let family = deviceType.productFamily ?? ""
            if family.localizedCaseInsensitiveContains("iPad") { return true }
            return deviceType.name.localizedCaseInsensitiveContains("iPad")
        }

        let platforms: [ManagedPlatform] = supportedPlatforms.map { platform in
            buildManagedPlatform(
                platform,
                sdks: sdksByPlatform[platform] ?? [],
                runtimes: runtimesByPlatform[platform] ?? [],
                iosSDKs: sdksByPlatform[.iOS] ?? [],
                iosRuntimes: runtimesByPlatform[.iOS] ?? [],
                hasIPadDeviceType: hasIPadDeviceType,
                developerDirectory: developerDirectory,
                isXcodeInstalled: isXcodeInstalled,
                isCommandLineToolsOnly: environment.isCLTOnly
            )
        }

        var globalIssues: [PlatformIssue] = []
        if environment.isCLTOnly {
            globalIssues.append(commandLineToolsOnlyIssue(developerDirectory: developerDirectory))
        } else if !isXcodeInstalled {
            globalIssues.append(xcodeMissingIssue())
        }

        return PlatformCatalogSnapshot(
            platforms: platforms,
            developerDirectory: developerDirectory,
            xcodeVersion: environment.xcodeVersion,
            xcodeBuild: environment.xcodeBuild,
            isCommandLineToolsOnly: environment.isCLTOnly,
            isXcodeInstalled: isXcodeInstalled,
            globalIssues: globalIssues,
            discoveryError: discoveryError,
            hasScanned: true,
            lastRefreshed: refreshedAt
        )
    }

    static func buildManagedPlatform(
        _ platform: DevicePlatform,
        sdks: [PlatformSDK],
        runtimes: [PlatformRuntime],
        iosSDKs: [PlatformSDK],
        iosRuntimes: [PlatformRuntime],
        hasIPadDeviceType: Bool,
        developerDirectory: String?,
        isXcodeInstalled: Bool,
        isCommandLineToolsOnly: Bool
    ) -> ManagedPlatform {
        if platform == .iPadOS {
            guard hasIPadDeviceType, !iosSDKs.isEmpty else {
                var issues: [PlatformIssue] = []
                if isCommandLineToolsOnly {
                    issues.append(commandLineToolsOnlyIssue(developerDirectory: developerDirectory))
                } else if !isXcodeInstalled {
                    issues.append(xcodeMissingIssue())
                } else if iosSDKs.isEmpty {
                    issues.append(missingSDKIssue(platform: .iPadOS, developerDirectory: developerDirectory))
                } else {
                    issues.append(PlatformIssue(
                        kind: .deviceTypeMissing,
                        message: "No iPad device type was reported, so iPadOS cannot be offered even though the iOS SDK is installed.",
                        remediation: "Reinstall the iOS platform in Xcode > Settings > Components, or install the iPad simulator runtimes so simctl reports iPad device types."
                    ))
                }
                return ManagedPlatform(platform: .iPadOS, status: .missing, sdks: [], runtimes: [], installationLocations: [], issues: issues)
            }
            return buildSimulatorPlatform(
                .iPadOS,
                sdks: iosSDKs,
                runtimes: iosRuntimes,
                developerDirectory: developerDirectory,
                isXcodeInstalled: isXcodeInstalled,
                isCommandLineToolsOnly: isCommandLineToolsOnly
            )
        }
        if platform == .macOS {
            return buildMacPlatform(
                sdks: sdks,
                developerDirectory: developerDirectory,
                isXcodeInstalled: isXcodeInstalled,
                isCommandLineToolsOnly: isCommandLineToolsOnly
            )
        }
        return buildSimulatorPlatform(
            platform,
            sdks: sdks,
            runtimes: runtimes,
            developerDirectory: developerDirectory,
            isXcodeInstalled: isXcodeInstalled,
            isCommandLineToolsOnly: isCommandLineToolsOnly
        )
    }

    static func buildSimulatorPlatform(
        _ platform: DevicePlatform,
        sdks: [PlatformSDK],
        runtimes: [PlatformRuntime],
        developerDirectory: String?,
        isXcodeInstalled: Bool,
        isCommandLineToolsOnly: Bool
    ) -> ManagedPlatform {
        var issues: [PlatformIssue] = []
        if isCommandLineToolsOnly {
            issues.append(commandLineToolsOnlyIssue(developerDirectory: developerDirectory))
        } else if !isXcodeInstalled {
            issues.append(xcodeMissingIssue())
        }
        if sdks.isEmpty {
            issues.append(missingSDKIssue(platform: platform, developerDirectory: developerDirectory))
        }
        if !sdks.isEmpty && runtimes.isEmpty {
            issues.append(PlatformIssue(
                kind: .runtimeMissing,
                message: "No \(platform.rawValue) simulator runtime is installed.",
                remediation: "Download a \(platform.rawValue) runtime in Xcode > Settings > Components, or install one with xcrun simctl runtime add."
            ))
        }
        for runtime in runtimes where !runtime.isAvailable {
            issues.append(PlatformIssue(
                kind: .runtimeUnavailable,
                message: "Simulator runtime \(runtime.name) (\(runtime.version)) is reported as unavailable.",
                remediation: "Remove the unavailable runtime with xcrun simctl runtime delete \(runtime.identifier), then reinstall it from Xcode > Settings > Components."
            ))
        }
        if let newestSDKVersion = sdks.map(\.version).max(by: { compareVersionStrings($0, $1) == .orderedAscending }),
           let newestMajor = versionComponents(newestSDKVersion).first {
            for runtime in runtimes where runtime.isAvailable {
                guard let runtimeMajor = versionComponents(runtime.version).first, runtimeMajor > newestMajor else { continue }
                issues.append(PlatformIssue(
                    kind: .runtimeNewerThanSDK,
                    message: "Simulator runtime \(runtime.name) (\(runtime.version)) is newer than the newest installed \(platform.rawValue) SDK (\(newestSDKVersion)).",
                    remediation: "Update Xcode to a version that ships the \(platform.rawValue) \(runtime.version) SDK, or remove the runtime with xcrun simctl runtime delete \(runtime.identifier)."
                ))
            }
        }
        let status: PlatformInstallStatus
        if sdks.isEmpty && runtimes.isEmpty {
            status = .missing
        } else if sdks.isEmpty || runtimes.isEmpty || !runtimes.contains(where: \.isAvailable) {
            status = .partial
        } else {
            status = .installed
        }
        return ManagedPlatform(
            platform: platform,
            status: status,
            sdks: sdks,
            runtimes: runtimes,
            installationLocations: installationLocations(sdks: sdks, runtimes: runtimes),
            issues: issues
        )
    }

    static func buildMacPlatform(
        sdks: [PlatformSDK],
        developerDirectory: String?,
        isXcodeInstalled: Bool,
        isCommandLineToolsOnly: Bool
    ) -> ManagedPlatform {
        var issues: [PlatformIssue] = []
        if isCommandLineToolsOnly {
            issues.append(commandLineToolsOnlyIssue(developerDirectory: developerDirectory))
        } else if !isXcodeInstalled {
            issues.append(xcodeMissingIssue())
        }
        if sdks.isEmpty {
            issues.append(missingSDKIssue(platform: .macOS, developerDirectory: developerDirectory))
        }
        let status: PlatformInstallStatus = sdks.isEmpty ? .missing : .installed
        return ManagedPlatform(
            platform: .macOS,
            status: status,
            sdks: sdks,
            runtimes: [],
            installationLocations: installationLocations(sdks: sdks, runtimes: []),
            issues: issues
        )
    }

    static func installationLocations(sdks: [PlatformSDK], runtimes: [PlatformRuntime]) -> [String] {
        var locations = Set<String>()
        for sdk in sdks {
            locations.insert(sdk.platformPath)
            locations.insert(sdk.path)
        }
        for runtime in runtimes {
            if let path = runtime.path { locations.insert(path) }
        }
        return locations.sorted()
    }

    static func xcodeMissingIssue() -> PlatformIssue {
        PlatformIssue(
            kind: .xcodeMissing,
            message: "Xcode was not found. No platform SDKs or simulator runtimes can be listed without it.",
            remediation: "Install Xcode from the App Store, then select it with xcode-select -s /Applications/Xcode.app/Contents/Developer."
        )
    }

    static func commandLineToolsOnlyIssue(developerDirectory: String?) -> PlatformIssue {
        PlatformIssue(
            kind: .commandLineToolsOnly,
            message: "Only the Xcode Command Line Tools are installed at \(developerDirectory ?? "the selected developer directory"). Platform SDKs and simulator runtimes require full Xcode.",
            remediation: "Install Xcode from the App Store, then select it with xcode-select -s /Applications/Xcode.app/Contents/Developer."
        )
    }

    static func missingSDKIssue(platform: DevicePlatform, developerDirectory: String?) -> PlatformIssue {
        if let developerDirectory {
            return PlatformIssue(
                kind: .sdkMissing,
                message: "No \(platform.rawValue) SDK was found in \(developerDirectory)/Platforms.",
                remediation: "Install an Xcode version that ships the \(platform.rawValue) SDK, or add the platform in Xcode > Settings > Components."
            )
        }
        return PlatformIssue(
            kind: .sdkMissing,
            message: "No \(platform.rawValue) SDK was found because no developer directory is selected.",
            remediation: "Install Xcode from the App Store, then select it with xcode-select -s /Applications/Xcode.app/Contents/Developer."
        )
    }

    static func platform(forSDKEntry entry: SDKEntry) -> DevicePlatform? {
        let canonical = entry.canonicalName.lowercased()
        if canonical.hasPrefix("iphonesimulator") || canonical.hasPrefix("iphoneos") { return .iOS }
        if canonical.hasPrefix("macosx") { return .macOS }
        if canonical.hasPrefix("watchsimulator") || canonical.hasPrefix("watchos") { return .watchOS }
        if canonical.hasPrefix("appletvsimulator") || canonical.hasPrefix("appletvos") { return .tvOS }
        if canonical.hasPrefix("xrsimulator") || canonical.hasPrefix("xros") { return .visionOS }
        if let parsed = parsePlatformName(entry.platformName) { return parsed }
        return parsePlatformName(entry.platformDescription)
    }

    static func platform(forSimctlRuntime runtime: RuntimeDTO) -> DevicePlatform? {
        if let parsed = parsePlatformName(runtime.platform) { return parsed }
        let fromIdentifier = DevicePlatform(runtimeIdentifier: runtime.identifier)
        return fromIdentifier == .unknown ? nil : fromIdentifier
    }

    static func parsePlatformName(_ raw: String?) -> DevicePlatform? {
        guard let raw else { return nil }
        let parsed = DevicePlatform(parsing: raw)
        return parsed == .unknown ? nil : parsed
    }

    static func versionComponents(_ version: String) -> [Int] {
        version.split(separator: ".").map { component in
            Int(component.prefix(while: { $0.isNumber })) ?? 0
        }
    }

    static func compareVersionStrings(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionComponents(lhs)
        let right = versionComponents(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }
}

@Observable
@MainActor
public final class PlatformManager {
    public static let shared = PlatformManager()

    public private(set) var snapshot: PlatformCatalogSnapshot = .empty
    public private(set) var isRefreshing = false
    public private(set) var lastError: PlatformManagerError?

    public init() {}

    public var platforms: [ManagedPlatform] { snapshot.platforms }
    public var installedPlatforms: [ManagedPlatform] { snapshot.installedPlatforms }
    public var missingPlatforms: [ManagedPlatform] { snapshot.missingPlatforms }

    public func platform(_ platform: DevicePlatform) -> ManagedPlatform? {
        snapshot.platform(platform)
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        lastError = nil
        let environment = await DeveloperEnvironmentProbe.shared.runProbe()
        let developerDirectory = environment.developerDirectory == "Unavailable" ? "" : environment.developerDirectory
        if !environment.isFullXcodeInstall {
            if environment.isCLTOnly {
                lastError = .commandLineToolsOnly(environment.developerDirectory)
            } else {
                lastError = .xcodeNotInstalled
            }
        }
        SimulatorRuntimeManager.shared.clearCache()
        let registry = SDKRegistry(developerDirectory: developerDirectory)
        let diskRuntimes = await SimulatorRuntimeManager.shared.discoverRuntimes()
        var simctlRuntimes: [RuntimeDTO] = []
        var deviceTypes: [DeviceTypeDTO] = []
        var discoveryError: String?
        do {
            let result = try await SimctlDiscoveryClient.shared.fetchDiscoveryData()
            simctlRuntimes = result.runtimes
            deviceTypes = result.deviceTypes
        } catch {
            discoveryError = error.localizedDescription
            lastError = .discoveryFailed(error.localizedDescription)
            Logger.discovery.error("[PLATFORM-MANAGER] simctl discovery failed, continuing with on-disk runtimes: \(error.localizedDescription)")
        }
        snapshot = PlatformCatalogBuilder.build(
            sdkEntries: registry.entries,
            diskRuntimes: diskRuntimes,
            simctlRuntimes: simctlRuntimes,
            deviceTypes: deviceTypes,
            environment: environment,
            discoveryError: discoveryError
        )
        Logger.discovery.info("[PLATFORM-MANAGER] Refreshed \(snapshot.platforms.count) platforms; installed: \(snapshot.installedPlatforms.count), missing: \(snapshot.missingPlatforms.count).")
    }
}
