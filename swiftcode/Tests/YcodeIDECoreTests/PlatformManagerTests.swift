import Foundation
import Testing
@testable import YcodeDeviceModel
@testable import YcodeIDECore
@testable import YcodeXcodebuild

@Suite struct PlatformManagerTests {
    static func sdk(canonicalName: String, version: String, platformName: String) -> SDKEntry {
        SDKEntry(
            bundleName: canonicalName + ".sdk",
            path: "/Applications/Xcode.app/Contents/Developer/Platforms/" + platformName + ".platform/Developer/SDKs/" + canonicalName + ".sdk",
            canonicalName: canonicalName,
            displayName: canonicalName,
            version: version,
            isBaseSDK: true,
            platformName: platformName,
            platformDescription: platformName,
            platformVersion: version,
            platformPath: "/Applications/Xcode.app/Contents/Developer/Platforms/" + platformName + ".platform",
            systemVersion: [:]
        )
    }

    static func diskRuntime(identifier: String, name: String, version: String, platform: String, isAvailable: Bool = true) -> SimulatorRuntime {
        SimulatorRuntime(
            identifier: identifier,
            name: name,
            version: version,
            platform: platform,
            isAvailable: isAvailable,
            path: "/Library/Developer/CoreSimulator/Profiles/Runtimes/" + name + ".simruntime"
        )
    }

    static func simctlRuntimes(_ json: String) throws -> [RuntimeDTO] {
        let response = try JSONDecoder().decode(SimctlListResponse.self, from: Data(json.utf8))
        return response.runtimes ?? []
    }

    static func simctlDeviceTypes(_ json: String) throws -> [DeviceTypeDTO] {
        let response = try JSONDecoder().decode(SimctlListResponse.self, from: Data(json.utf8))
        return response.devicetypes ?? []
    }

    static func environment(
        developerDirectory: String = "/Applications/Xcode.app/Contents/Developer",
        xcodeVersion: String? = "27.0",
        isFullXcodeInstall: Bool = true,
        isCLTOnly: Bool = false
    ) -> DeveloperEnvironmentInfo {
        DeveloperEnvironmentInfo(
            developerDirectory: developerDirectory,
            xcodeVersion: xcodeVersion,
            xcodeBuild: "27A9269",
            xcrunVersion: "xcrun version 100.0",
            isFullXcodeInstall: isFullXcodeInstall,
            isCLTOnly: isCLTOnly
        )
    }

    static func build(
        sdks: [SDKEntry] = [],
        disk: [SimulatorRuntime] = [],
        simctl: [RuntimeDTO] = [],
        deviceTypes: [DeviceTypeDTO] = [],
        environment: DeveloperEnvironmentInfo? = nil,
        discoveryError: String? = nil
    ) -> PlatformCatalogSnapshot {
        PlatformCatalogBuilder.build(
            sdkEntries: sdks,
            diskRuntimes: disk,
            simctlRuntimes: simctl,
            deviceTypes: deviceTypes,
            environment: environment ?? Self.environment(),
            discoveryError: discoveryError
        )
    }

    static let iosSDK = sdk(canonicalName: "iphoneos26.0", version: "26.0", platformName: "iphoneos")
    static let iosSimctlJSON = """
    {"runtimes": [{"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-0", "name": "iOS 26.0", "version": "26.0", "buildversion": "23A100", "platform": "iOS", "isAvailable": true, "supportedArchitectures": ["arm64"]}]}
    """
    static let ipadDeviceTypeJSON = """
    {"devicetypes": [{"identifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4", "name": "iPad Pro 13-inch (M4)", "productFamily": "iPad"}]}
    """

    @Test func emptySnapshotListsAllSixPlatformsAsMissing() {
        let snapshot = PlatformCatalogSnapshot.empty
        #expect(snapshot.platforms.map(\.platform) == [.iOS, .iPadOS, .watchOS, .tvOS, .visionOS, .macOS])
        #expect(snapshot.platforms.allSatisfy { $0.status == .missing })
        #expect(snapshot.hasScanned == false)
        #expect(snapshot.isXcodeInstalled == false)
        #expect(snapshot.installedPlatforms.isEmpty)
        #expect(snapshot.missingPlatforms.count == 6)
    }

    @Test @MainActor func managerStartsUnscannedAndIdle() {
        let manager = PlatformManager()
        #expect(manager.snapshot == .empty)
        #expect(manager.isRefreshing == false)
        #expect(manager.lastError == nil)
        #expect(manager.platform(.iOS)?.status == .missing)
    }

    @Test func iosInstalledWithSDKAndMergedRuntime() throws {
        let disk = Self.diskRuntime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-0", name: "iOS 26.0", version: "26.0", platform: "iOS")
        let simctl = try Self.simctlRuntimes(Self.iosSimctlJSON)
        let snapshot = Self.build(sdks: [Self.iosSDK], disk: [disk], simctl: simctl)
        let ios = snapshot.platform(.iOS)
        #expect(ios?.status == .installed)
        #expect(ios?.sdks.count == 1)
        #expect(ios?.sdks.first?.canonicalName == "iphoneos26.0")
        #expect(ios?.runtimes.count == 1)
        #expect(ios?.runtimes.first?.source == .merged)
        #expect(ios?.runtimes.first?.buildVersion == "23A100")
        #expect(ios?.runtimes.first?.isAvailable == true)
        #expect(ios?.runtimes.first?.path?.contains("iOS 26.0.simruntime") == true)
        #expect(ios?.versions == ["26.0"])
        #expect(ios?.newestSDKVersion == "26.0")
        #expect(ios?.hasAvailableRuntime == true)
        #expect(ios?.issues.isEmpty == true)
        #expect(ios?.installationLocations.contains("/Applications/Xcode.app/Contents/Developer/Platforms/iphoneos.platform") == true)
        #expect(snapshot.developerDirectory == "/Applications/Xcode.app/Contents/Developer")
        #expect(snapshot.xcodeVersion == "27.0")
        #expect(snapshot.globalIssues.isEmpty)
    }

    @Test func sdkWithoutRuntimeIsPartialWithRuntimeMissingIssue() {
        let snapshot = Self.build(sdks: [Self.iosSDK])
        let ios = snapshot.platform(.iOS)
        #expect(ios?.status == .partial)
        #expect(ios?.issues.contains { $0.kind == .runtimeMissing } == true)
        #expect(ios?.issues.first { $0.kind == .runtimeMissing }?.remediation.contains("Settings > Components") == true)
    }

    @Test func runtimeWithoutSDKIsPartialWithSDKMissingIssue() throws {
        let simctl = try Self.simctlRuntimes(Self.iosSimctlJSON)
        let snapshot = Self.build(simctl: simctl)
        let ios = snapshot.platform(.iOS)
        #expect(ios?.status == .partial)
        #expect(ios?.runtimes.count == 1)
        #expect(ios?.runtimes.first?.source == .simctl)
        #expect(ios?.issues.contains { $0.kind == .sdkMissing } == true)
        #expect(ios?.issues.first { $0.kind == .sdkMissing }?.message.contains("Platforms") == true)
    }

    @Test func unavailableRuntimeKeepsPlatformPartial() {
        let disk = Self.diskRuntime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-0", name: "iOS 26.0", version: "26.0", platform: "iOS", isAvailable: false)
        let snapshot = Self.build(sdks: [Self.iosSDK], disk: [disk])
        let ios = snapshot.platform(.iOS)
        #expect(ios?.status == .partial)
        #expect(ios?.hasAvailableRuntime == false)
        #expect(ios?.issues.contains { $0.kind == .runtimeUnavailable } == true)
    }

    @Test func runtimeNewerThanSDKIsFlaggedIncompatible() throws {
        let json = """
        {"runtimes": [{"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-0", "name": "iOS 27.0", "version": "27.0", "isAvailable": true}]}
        """
        let simctl = try Self.simctlRuntimes(json)
        let snapshot = Self.build(sdks: [Self.iosSDK], simctl: simctl)
        let ios = snapshot.platform(.iOS)
        #expect(ios?.status == .installed)
        let issue = ios?.issues.first { $0.kind == .runtimeNewerThanSDK }
        #expect(issue != nil)
        #expect(issue?.message.contains("27.0") == true)
        #expect(issue?.message.contains("26.0") == true)
        #expect(issue?.remediation.contains("Update Xcode") == true)
    }

    @Test func macOSAppearsOnlyWhenMacSDKPresent() {
        let absent = Self.build()
        let missing = absent.platform(.macOS)
        #expect(missing?.status == .missing)
        #expect(missing?.sdks.isEmpty == true)
        #expect(missing?.runtimes.isEmpty == true)
        #expect(missing?.issues.contains { $0.kind == .sdkMissing } == true)
        #expect(missing?.issues.contains { $0.kind == .runtimeMissing } == false)

        let macSDK = Self.sdk(canonicalName: "macosx26.0", version: "26.0", platformName: "macosx")
        let present = Self.build(sdks: [macSDK])
        let installed = present.platform(.macOS)
        #expect(installed?.status == .installed)
        #expect(installed?.sdks.count == 1)
        #expect(installed?.issues.isEmpty == true)
    }

    @Test func iPadOSMissingWithoutIPadDeviceType() throws {
        let simctl = try Self.simctlRuntimes(Self.iosSimctlJSON)
        let snapshot = Self.build(sdks: [Self.iosSDK], simctl: simctl)
        #expect(snapshot.platform(.iOS)?.status == .installed)
        let ipad = snapshot.platform(.iPadOS)
        #expect(ipad?.status == .missing)
        #expect(ipad?.sdks.isEmpty == true)
        #expect(ipad?.runtimes.isEmpty == true)
        #expect(ipad?.issues.contains { $0.kind == .deviceTypeMissing } == true)
    }

    @Test func iPadOSInstalledWhenIPadDeviceTypePresent() throws {
        let simctl = try Self.simctlRuntimes(Self.iosSimctlJSON)
        let deviceTypes = try Self.simctlDeviceTypes(Self.ipadDeviceTypeJSON)
        let snapshot = Self.build(sdks: [Self.iosSDK], simctl: simctl, deviceTypes: deviceTypes)
        let ipad = snapshot.platform(.iPadOS)
        #expect(ipad?.status == .installed)
        #expect(ipad?.sdks.count == 1)
        #expect(ipad?.runtimes.count == 1)
        #expect(ipad?.issues.isEmpty == true)
    }

    @Test func visionOSFromXRSDKAndRuntime() throws {
        let xrSDK = Self.sdk(canonicalName: "xros2.0", version: "2.0", platformName: "xros")
        let json = """
        {"runtimes": [{"identifier": "com.apple.CoreSimulator.SimRuntime.xrOS-2-0", "name": "xrOS 2.0", "version": "2.0", "platform": "xrOS", "isAvailable": true}]}
        """
        let simctl = try Self.simctlRuntimes(json)
        let snapshot = Self.build(sdks: [xrSDK], simctl: simctl)
        let vision = snapshot.platform(.visionOS)
        #expect(vision?.status == .installed)
        #expect(vision?.sdks.first?.canonicalName == "xros2.0")
        #expect(vision?.runtimes.first?.identifier == "com.apple.CoreSimulator.SimRuntime.xrOS-2-0")
    }

    @Test func watchOSAndTVOSDetectedFromSDKsAndDiskRuntimes() {
        let watchSDK = Self.sdk(canonicalName: "watchos12.0", version: "12.0", platformName: "watchos")
        let tvSDK = Self.sdk(canonicalName: "appletvos26.0", version: "26.0", platformName: "appletvos")
        let watchRuntime = Self.diskRuntime(identifier: "com.apple.CoreSimulator.SimRuntime.watchOS-12-0", name: "watchOS 12.0", version: "12.0", platform: "watchOS")
        let tvRuntime = Self.diskRuntime(identifier: "com.apple.CoreSimulator.SimRuntime.tvOS-26-0", name: "tvOS 26.0", version: "26.0", platform: "tvOS")
        let snapshot = Self.build(sdks: [watchSDK, tvSDK], disk: [watchRuntime, tvRuntime])
        #expect(snapshot.platform(.watchOS)?.status == .installed)
        #expect(snapshot.platform(.tvOS)?.status == .installed)
        #expect(snapshot.platform(.watchOS)?.runtimes.first?.source == .diskBundle)
        #expect(snapshot.installedPlatforms.map(\.platform).sorted { $0.rawValue < $1.rawValue } == [.tvOS, .watchOS])
    }

    @Test func unknownSDKAndRuntimeEvidenceIsIgnored() {
        let unknownSDK = Self.sdk(canonicalName: "fooos1.0", version: "1.0", platformName: "fooos")
        let unknownRuntime = Self.diskRuntime(identifier: "com.apple.CoreSimulator.SimRuntime.Foo-1-0", name: "Foo 1.0", version: "1.0", platform: "Foo")
        let snapshot = Self.build(sdks: [unknownSDK], disk: [unknownRuntime])
        #expect(snapshot.installedPlatforms.isEmpty)
        #expect(snapshot.platforms.allSatisfy { $0.sdks.isEmpty && $0.runtimes.isEmpty })
    }

    @Test func xcodeMissingMarksAllPlatformsMissingWithActionableIssue() {
        let snapshot = Self.build(environment: .unavailable)
        #expect(snapshot.isXcodeInstalled == false)
        #expect(snapshot.developerDirectory == nil)
        #expect(snapshot.hasScanned == true)
        #expect(snapshot.globalIssues.contains { $0.kind == .xcodeMissing } == true)
        #expect(snapshot.globalIssues.first?.remediation.contains("xcode-select") == true)
        #expect(snapshot.platforms.allSatisfy { $0.status == .missing })
        #expect(snapshot.platform(.iOS)?.issues.contains { $0.kind == .xcodeMissing } == true)
        #expect(snapshot.platform(.macOS)?.issues.contains { $0.kind == .sdkMissing } == true)
    }

    @Test func commandLineToolsOnlySurfacedAsGlobalIssue() {
        let clt = Self.environment(
            developerDirectory: "/Library/Developer/CommandLineTools",
            xcodeVersion: nil,
            isFullXcodeInstall: false,
            isCLTOnly: true
        )
        let snapshot = Self.build(environment: clt)
        #expect(snapshot.isCommandLineToolsOnly == true)
        #expect(snapshot.isXcodeInstalled == false)
        #expect(snapshot.globalIssues.contains { $0.kind == .commandLineToolsOnly } == true)
        #expect(snapshot.platform(.iOS)?.issues.contains { $0.kind == .commandLineToolsOnly } == true)
    }

    @Test func versionsSortNumericallyNotLexicographically() {
        let oldSDK = Self.sdk(canonicalName: "macosx9.0", version: "9.0", platformName: "macosx")
        let newSDK = Self.sdk(canonicalName: "macosx10.0", version: "10.0", platformName: "macosx")
        let snapshot = Self.build(sdks: [newSDK, oldSDK])
        #expect(snapshot.platform(.macOS)?.versions == ["9.0", "10.0"])
        #expect(PlatformCatalogBuilder.compareVersionStrings("9.0", "10.0") == .orderedAscending)
        #expect(PlatformCatalogBuilder.compareVersionStrings("26.0.1", "26.0") == .orderedDescending)
        #expect(PlatformCatalogBuilder.compareVersionStrings("26.0", "26.0") == .orderedSame)
    }

    @Test func discoveryErrorPreservedOnSnapshot() {
        let snapshot = Self.build(sdks: [Self.iosSDK], discoveryError: "xcrun not found")
        #expect(snapshot.discoveryError == "xcrun not found")
        #expect(snapshot.hasScanned == true)
        #expect(snapshot.platform(.iOS)?.status == .partial)
    }

    @Test func errorDescriptionsAreActionable() {
        #expect(PlatformManagerError.xcodeNotInstalled.errorDescription?.contains("Xcode") == true)
        #expect(PlatformManagerError.xcodeNotInstalled.recoverySuggestion?.contains("xcode-select") == true)
        #expect(PlatformManagerError.commandLineToolsOnly("/Library/Developer/CommandLineTools").errorDescription?.contains("Command Line Tools") == true)
        #expect(PlatformManagerError.discoveryFailed("boom").errorDescription?.contains("boom") == true)
    }
}
