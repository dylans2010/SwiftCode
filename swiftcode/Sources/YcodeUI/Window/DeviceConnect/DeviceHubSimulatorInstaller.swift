import AppKit
import Foundation
import SwiftUI
import YcodeDeviceModel
import YcodeIDECore
import YcodeSubprocess


public enum DeviceHubPlatform: String, Sendable, CaseIterable, Identifiable {
    case iOS = "iOS"
    case iPadOS = "iPadOS"
    case watchOS = "watchOS"
    case tvOS = "tvOS"
    case visionOS = "visionOS"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public var subtitle: String {
        switch self {
        case .iOS: return "iPhone simulator runtimes & mobile environments"
        case .iPadOS: return "iPad simulator runtimes & tablet multitasking presets"
        case .watchOS: return "Apple Watch simulator runtimes & accessory environments"
        case .tvOS: return "Apple TV simulator runtimes & living room display configurations"
        case .visionOS: return "Apple Vision Pro spatial computing simulator runtimes"
        }
    }

    public var iconName: String {
        switch self {
        case .iOS: return "iphone"
        case .iPadOS: return "ipad"
        case .watchOS: return "applewatch"
        case .tvOS: return "appletv"
        case .visionOS: return "visionpro"
        }
    }

    
    
    public var downloadName: String {
        switch self {
        case .iOS, .iPadOS: return "iOS"
        case .watchOS: return "watchOS"
        case .tvOS: return "tvOS"
        case .visionOS: return "visionOS"
        }
    }

    public var simPlatform: SimPlatform {
        switch self {
        case .iOS, .iPadOS: return .iOS
        case .watchOS: return .watchOS
        case .tvOS: return .tvOS
        case .visionOS: return .visionOS
        }
    }

    public var productFamily: String {
        switch self {
        case .iOS: return "iPhone"
        case .iPadOS: return "iPad"
        case .watchOS: return "Apple Watch"
        case .tvOS: return "Apple TV"
        case .visionOS: return "Apple Vision"
        }
    }

    public var typicalSize: String {
        switch self {
        case .iOS, .iPadOS: return "~8 GB"
        case .watchOS, .tvOS: return "~4 GB"
        case .visionOS: return "~7 GB"
        }
    }
}


public struct PlatformStatus: Identifiable, Sendable {
    public var id: String { platform.rawValue }
    public let platform: DeviceHubPlatform
    public var isInstalled: Bool
    public var installedVersion: String?
    public var installedBuild: String?
    public var isDownloading: Bool = false
    public var sdkDisplayName: String?

    public init(
        platform: DeviceHubPlatform,
        isInstalled: Bool = false,
        installedVersion: String? = nil,
        installedBuild: String? = nil,
        isDownloading: Bool = false,
        sdkDisplayName: String? = nil
    ) {
        self.platform = platform
        self.isInstalled = isInstalled
        self.installedVersion = installedVersion
        self.installedBuild = installedBuild
        self.isDownloading = isDownloading
        self.sdkDisplayName = sdkDisplayName
    }
}


public struct DeviceTypeRecord: Identifiable, Sendable, Hashable {
    public var id: String { identifier }
    public let name: String
    public let identifier: String
    public let productFamily: String

    public init(name: String, identifier: String, productFamily: String) {
        self.name = name
        self.identifier = identifier
        self.productFamily = productFamily
    }
}

@MainActor
public final class DeviceHubSimulatorInstaller: ObservableObject {
    public static let shared = DeviceHubSimulatorInstaller()

    @Published public var isRunning = false
    @Published public var currentPlatform: SimPlatform = .iOS
    @Published public var currentHubPlatform: DeviceHubPlatform = .iOS
    @Published public var progressFraction: Double?
    @Published public var progressStage: String = "Idle"
    @Published public var progressLine: String = ""
    @Published public var logLines: [String] = []
    @Published public var errorMessage: String?
    @Published public var availableDeviceTypes: [(name: String, identifier: String)] = []
    @Published public var deviceTypeRecords: [DeviceTypeRecord] = []
    @Published public var availableRuntimes: [(name: String, identifier: String)] = []
    @Published public var existingSimulatorNames: [String] = []
    @Published public var platformStatuses: [DeviceHubPlatform: PlatformStatus] = [:]
    @Published public var isQueryingPlatforms: Bool = false

    private var currentRun: XcodebuildDownloadRun?

    public init() {
        for p in DeviceHubPlatform.allCases {
            platformStatuses[p] = PlatformStatus(platform: p)
        }
    }

    

    public func fetchAvailableTypesAndRuntimes() {
        Task {
            do {
                let records = try await Self.fetchDeviceTypeRecords()
                let runtimes = try await Self.fetchRuntimes()
                await MainActor.run {
                    self.deviceTypeRecords = records
                    self.availableDeviceTypes = records.map { (name: $0.name, identifier: $0.identifier) }
                    self.availableRuntimes = runtimes
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func queryPlatformStatuses() {
        guard !isQueryingPlatforms else { return }
        isQueryingPlatforms = true
        Task {
            let statuses = await Self.detectPlatformStatuses()
            await MainActor.run {
                for s in statuses {
                    self.platformStatuses[s.platform] = s
                }
                self.isQueryingPlatforms = false
            }
        }
    }

    public static func detectPlatformStatuses() async -> [PlatformStatus] {
        await Task.detached {
            var results: [DeviceHubPlatform: PlatformStatus] = [:]
            for p in DeviceHubPlatform.allCases {
                results[p] = PlatformStatus(platform: p)
            }

            
            let (sdkStatus, sdkOutput) = await runXcrunProcess(["xcodebuild", "-showsdks", "-json"], timeout: 15)
            if sdkStatus == 0, let data = sdkOutput.data(using: .utf8),
               let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for sdk in list {
                    let canon = (sdk["canonicalName"] as? String ?? "").lowercased()
                    let displayName = sdk["displayName"] as? String ?? ""
                    let version = sdk["sdkVersion"] as? String
                    let build = sdk["productBuildVersion"] as? String

                    if canon.contains("iphonesimulator") {
                        results[.iOS]?.isInstalled = true
                        results[.iOS]?.installedVersion = version
                        results[.iOS]?.installedBuild = build
                        results[.iOS]?.sdkDisplayName = displayName

                        results[.iPadOS]?.isInstalled = true
                        results[.iPadOS]?.installedVersion = version
                        results[.iPadOS]?.installedBuild = build
                        results[.iPadOS]?.sdkDisplayName = displayName.replacingOccurrences(of: "iOS", with: "iPadOS")
                    } else if canon.contains("watchsimulator") {
                        results[.watchOS]?.isInstalled = true
                        results[.watchOS]?.installedVersion = version
                        results[.watchOS]?.installedBuild = build
                        results[.watchOS]?.sdkDisplayName = displayName
                    } else if canon.contains("appletvsimulator") {
                        results[.tvOS]?.isInstalled = true
                        results[.tvOS]?.installedVersion = version
                        results[.tvOS]?.installedBuild = build
                        results[.tvOS]?.sdkDisplayName = displayName
                    } else if canon.contains("xrsimulator") {
                        results[.visionOS]?.isInstalled = true
                        results[.visionOS]?.installedVersion = version
                        results[.visionOS]?.installedBuild = build
                        results[.visionOS]?.sdkDisplayName = displayName
                    }
                }
            }

            
            let (simStatus, simOutput) = await runXcrunProcess(["simctl", "list", "-j", "runtimes"], timeout: 15)
            if simStatus == 0, let data = simOutput.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let runtimes = json["runtimes"] as? [[String: Any]] {
                for r in runtimes {
                    let name = (r["name"] as? String ?? "").lowercased()
                    let id = (r["identifier"] as? String ?? "").lowercased()
                    let ver = r["version"] as? String
                    let build = r["buildversion"] as? String
                    let avail = (r["isAvailable"] as? Bool) ?? true
                    guard avail else { continue }

                    func updateStatus(for platform: DeviceHubPlatform) {
                        guard var item = results[platform] else { return }
                        item.isInstalled = true
                        if let ver { item.installedVersion = ver }
                        if let build { item.installedBuild = build }
                        results[platform] = item
                    }

                    if id.contains("ios") || name.contains("ios") {
                        updateStatus(for: .iOS)
                        updateStatus(for: .iPadOS)
                    } else if id.contains("watchos") || name.contains("watch") {
                        updateStatus(for: .watchOS)
                    } else if id.contains("tvos") || name.contains("tv") {
                        updateStatus(for: .tvOS)
                    } else if id.contains("xros") || id.contains("vision") || name.contains("vision") {
                        updateStatus(for: .visionOS)
                    }
                }
            }

            return Array(results.values)
        }.value
    }

    public static func fetchDeviceTypeRecords() async throws -> [DeviceTypeRecord] {
        let result = try await DeviceConnectProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["simctl", "list", "-j", "devicetypes"],
            timeout: 30
        )
        guard result.exitCode == 0,
              let data = result.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["devicetypes"] as? [[String: Any]] else {
            throw NSError(domain: "SimulatorInstaller", code: Int(result.exitCode),
                          userInfo: [NSLocalizedDescriptionKey: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return list.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let id = dict["identifier"] as? String else { return nil }
            let family = (dict["productFamily"] as? String) ?? {
                if name.contains("iPad") { return "iPad" }
                if name.contains("iPhone") { return "iPhone" }
                if name.contains("Watch") { return "Apple Watch" }
                if name.contains("TV") { return "Apple TV" }
                if name.contains("Vision") { return "Apple Vision" }
                return "iPhone"
            }()
            return DeviceTypeRecord(name: name, identifier: id, productFamily: family)
        }
    }

    public static func fetchDeviceTypes() async -> [(name: String, identifier: String)] {
        let records = (try? await fetchDeviceTypeRecords()) ?? []
        return records.map { ($0.name, $0.identifier) }
    }

    public static func fetchRuntimes() async throws -> [(name: String, identifier: String)] {
        let result = try await DeviceConnectProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["simctl", "list", "-j", "runtimes"],
            timeout: 30
        )
        guard result.exitCode == 0,
              let data = result.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["runtimes"] as? [[String: Any]] else {
            throw NSError(domain: "SimulatorInstaller", code: Int(result.exitCode),
                          userInfo: [NSLocalizedDescriptionKey: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return list.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let id = dict["identifier"] as? String else { return nil }
            return (name: name, identifier: id)
        }
    }

    

    public func installPlatform(_ hubPlatform: DeviceHubPlatform, onFinished: (@MainActor (Bool) -> Void)? = nil) {
        guard !isRunning else { return }
        isRunning = true
        currentHubPlatform = hubPlatform
        currentPlatform = hubPlatform.simPlatform
        progressFraction = nil
        progressStage = "Starting download for \(hubPlatform.title)…"
        progressLine = "Initializing Xcode tooling for \(hubPlatform.title)…"
        logLines.removeAll()
        errorMessage = nil

        if hubPlatform == .iPadOS {
            logLines.append("Note: iPadOS simulators run on Apple's iOS Simulator Runtime bundle.")
            logLines.append("Executing `xcodebuild -downloadPlatform iOS` with iPadOS tablet profile configurations…")
        }

        let download = XcodebuildDownload(platform: hubPlatform.simPlatform)
        let run = XcodebuildDownloadRun(download)
        currentRun = run

        Task {
            let outcome = await run.run(
                output: { [weak self] line in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.logLines.append(line)
                        if self.logLines.count > 1000 { self.logLines.removeFirst(200) }
                    }
                },
                progress: { [weak self] p in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let f = p.fraction { self.progressFraction = f }
                        if let s = p.stage { self.progressStage = s }
                        self.progressLine = p.line
                    }
                }
            )

            await MainActor.run {
                self.isRunning = false
                self.currentRun = nil
                switch outcome {
                case .finished:
                    self.progressStage = "\(hubPlatform.title) installation completed successfully!"
                    self.progressFraction = 1.0
                    self.queryPlatformStatuses()
                    onFinished?(true)
                case .cancelled:
                    self.progressStage = "Installation cancelled"
                    onFinished?(false)
                case .failed(let code, let err):
                    self.progressStage = "Failed (Exit code \(code))"
                    self.errorMessage = err
                    onFinished?(false)
                }
            }
        }
    }

    public func installPlatform(_ platform: SimPlatform, onFinished: (@MainActor (Bool) -> Void)? = nil) {
        let hub = DeviceHubPlatform(rawValue: platform.rawValue) ?? .iOS
        installPlatform(hub, onFinished: onFinished)
    }

    public func installAllPlatforms(onFinished: (@MainActor (Bool) -> Void)? = nil) {
        guard !isRunning else { return }
        isRunning = true
        progressFraction = nil
        progressStage = "Downloading all available Apple simulator platforms…"
        progressLine = "Executing `xcodebuild -downloadAllPlatforms` via background process…"
        logLines.removeAll()
        errorMessage = nil

        Task.detached {
            let code: Int32
            do {
                code = try await DeviceConnectProcessRunner.shared.runStreamingWithExitCode(
                    executableURL: URL(fileURLWithPath: "/usr/bin/xcodebuild"),
                    arguments: ["-downloadAllPlatforms"],
                    onStdout: { line in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.logLines.append(line)
                            if self.logLines.count > 1000 { self.logLines.removeFirst(200) }
                            if let progress = XcodebuildProgress.parse(line) {
                                if let f = progress.fraction { self.progressFraction = f }
                                if let s = progress.stage { self.progressStage = s }
                                self.progressLine = progress.line
                            }
                        }
                    },
                    onStderr: { line in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.logLines.append(line)
                            if self.logLines.count > 1000 { self.logLines.removeFirst(200) }
                            if let progress = XcodebuildProgress.parse(line) {
                                if let f = progress.fraction { self.progressFraction = f }
                                if let s = progress.stage { self.progressStage = s }
                                self.progressLine = progress.line
                            }
                        }
                    }
                )
            } catch {
                await MainActor.run {
                    self.isRunning = false
                    self.progressStage = "Failed to launch xcodebuild"
                    self.errorMessage = error.localizedDescription
                    onFinished?(false)
                }
                return
            }

            let exitCode = code
            await MainActor.run {
                self.isRunning = false
                if exitCode == 0 {
                    self.progressStage = "All platforms downloaded and installed successfully!"
                    self.progressFraction = 1.0
                    self.queryPlatformStatuses()
                    onFinished?(true)
                } else {
                    self.progressStage = "Download all platforms failed (Exit code \(exitCode))"
                    onFinished?(false)
                }
            }
        }
    }

    public func importRuntimeDiskImage(at url: URL, onFinished: (@MainActor (Bool) -> Void)? = nil) {
        guard !isRunning else { return }
        isRunning = true
        progressFraction = nil
        progressStage = "Importing Simulator Runtime Disk Image…"
        progressLine = "Mounting and registering \(url.lastPathComponent)…"
        logLines.removeAll()
        errorMessage = nil

        Task.detached {
            let (status, output) = await Self.runXcrunProcess(["simctl", "runtime", "add", url.path], timeout: 180)
            await MainActor.run {
                self.isRunning = false
                self.logLines.append(output)
                if status == 0 {
                    self.progressStage = "Runtime successfully imported and verified!"
                    self.progressFraction = 1.0
                    self.queryPlatformStatuses()
                    onFinished?(true)
                } else {
                    self.progressStage = "Failed to import runtime (Exit code \(status))"
                    self.errorMessage = output.isEmpty ? "simctl runtime add failed" : output
                    onFinished?(false)
                }
            }
        }
    }

    public func cancel() {
        currentRun?.cancel()
    }

    

    @discardableResult
    public static func runXcrunProcess(_ args: [String], timeout: TimeInterval = 60) async -> (status: Int32, output: String) {
        do {
            let result = try await DeviceConnectProcessRunner.shared.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
                arguments: args,
                timeout: timeout
            )
            return (result.exitCode, result.stdout + result.stderr)
        } catch let error as DeviceConnectProcessError {
            if case .timedOut = error {
                return (-2, "timed out")
            }
            return (-1, error.localizedDescription)
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    

    public static func parseExistingSimulatorNames(from jsonData: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let devices = json["devices"] as? [String: [[String: Any]]] else { return [] }
        var names: [String] = []
        for list in devices.values {
            for device in list {
                if let name = device["name"] as? String, !name.isEmpty {
                    names.append(name)
                }
            }
        }
        return names
    }

    public static func fetchExistingSimulatorNames() async throws -> [String] {
        let result = try await DeviceConnectProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["simctl", "list", "-j", "devices"],
            timeout: 30
        )
        guard result.exitCode == 0, let data = result.stdout.data(using: .utf8) else {
            let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "SimulatorInstaller", code: Int(result.exitCode),
                          userInfo: [NSLocalizedDescriptionKey: detail.isEmpty ? "Failed to list existing simulators" : detail])
        }
        return parseExistingSimulatorNames(from: data)
    }

    public func refreshExistingSimulatorNames() {
        Task {
            if let names = try? await Self.fetchExistingSimulatorNames() {
                await MainActor.run {
                    self.existingSimulatorNames = names
                }
            }
        }
    }

    public static func createSimulator(name: String, deviceTypeID: String, runtimeID: String) async throws -> String {
        let result = try await DeviceConnectProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["simctl", "create", name, deviceTypeID, runtimeID],
            timeout: 60
        )
        let outStr = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.exitCode != 0 {
            let errStr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "SimulatorInstaller", code: Int(result.exitCode), userInfo: [NSLocalizedDescriptionKey: errStr.isEmpty ? "Failed to create simulator" : errStr])
        }
        return outStr
    }

    public static func cloneSimulator(sourceUDID: String, newName: String) async throws -> String {
        let (status, output) = await runXcrunProcess(["simctl", "clone", sourceUDID, newName])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func eraseSimulator(udid: String) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "erase", udid])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
    }

    public static func eraseAllSimulators() async throws {
        let (status, output) = await runXcrunProcess(["simctl", "erase", "all"])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
    }

    public static func bootSimulator(udid: String) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "boot", udid])
        if status != 0 && !output.contains("current state: Booted") {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
    }

    public static func shutdownSimulator(udid: String) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "shutdown", udid])
        if status != 0 && !output.contains("current state: Shutdown") {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
    }

    public static func shutdownAllSimulators() async throws {
        let (status, output) = await runXcrunProcess(["simctl", "shutdown", "all"])
        if status != 0 && !output.isEmpty {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
    }

    

    public static func setAppearance(udid: String, appearance: String) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "ui", udid, "appearance", appearance])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    public static func setContentSize(udid: String, size: String) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "ui", udid, "content_size", size])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    public static func setIncreaseContrast(udid: String, enabled: Bool) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "ui", udid, "increase_contrast", enabled ? "enabled" : "disabled"])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    public static func setReduceMotion(udid: String, enabled: Bool) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "spawn", udid, "defaults", "write", "com.apple.Accessibility", "ReduceMotionEnabled", "-int", enabled ? "1" : "0"])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    public static func setLanguageAndLocale(udid: String, languageCode: String, localeCode: String? = nil) async throws {
        _ = await runXcrunProcess(["simctl", "spawn", udid, "defaults", "write", "Apple Global Domain", "AppleLanguages", "-array", languageCode])
        if let localeCode {
            _ = await runXcrunProcess(["simctl", "spawn", udid, "defaults", "write", "Apple Global Domain", "AppleLocale", localeCode])
        }
    }

    

    public static func setLocation(udid: String, latitude: Double, longitude: Double) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "location", udid, "set", "\(latitude),\(longitude)"])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    public static func runLocationScenario(udid: String, scenario: String) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "location", udid, "run", scenario])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    public static func clearLocation(udid: String) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "location", udid, "clear"])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    

    public static func overrideStatusBar(
        udid: String,
        batteryLevel: Int? = nil,
        batteryState: String? = nil,
        dataNetwork: String? = nil,
        wifiMode: String? = nil,
        wifiBars: Int? = nil,
        cellularMode: String? = nil,
        cellularBars: Int? = nil,
        operatorName: String? = nil,
        time: String? = nil
    ) async throws {
        var args = ["simctl", "status_bar", udid, "override"]
        if let time, !time.isEmpty { args += ["--time", time] }
        if let batteryLevel { args += ["--batteryLevel", String(batteryLevel), "--batteryState", batteryState ?? "charged"] }
        if let dataNetwork, !dataNetwork.isEmpty { args += ["--dataNetwork", dataNetwork] }
        if let wifiBars { args += ["--wifiBars", String(wifiBars), "--wifiMode", wifiMode ?? "active"] }
        if let cellularBars { args += ["--cellularBars", String(cellularBars), "--cellularMode", cellularMode ?? "active"] }
        if let operatorName, !operatorName.isEmpty { args += ["--operatorName", operatorName] }

        let (status, output) = await runXcrunProcess(args)
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    public static func clearStatusBar(udid: String) async throws {
        let (status, output) = await runXcrunProcess(["simctl", "status_bar", udid, "clear"])
        if status != 0 {
            throw NSError(domain: "SimulatorInstaller", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
        }
    }

    

    public static func setStageManager(udid: String, enabled: Bool) async throws {
        _ = await runXcrunProcess(["simctl", "spawn", udid, "defaults", "write", "com.apple.springboard", "SBStageManagerEnabled", "-bool", enabled ? "true" : "false"])
        _ = await runXcrunProcess(["simctl", "spawn", udid, "defaults", "write", "com.apple.springboard", "SBChamoisHideDock", "-bool", "false"])
    }

    public static func simulateApplePencilAction(udid: String, action: String) async throws {
        switch action {
        case "doubleTap":
            _ = await runXcrunProcess(["simctl", "spawn", udid, "defaults", "write", "com.apple.Pencil", "DoubleTapAction", "-int", "1"])
        case "squeeze":
            _ = await runXcrunProcess(["simctl", "spawn", udid, "defaults", "write", "com.apple.Pencil", "SqueezeAction", "-int", "1"])
        default:
            break
        }
    }
}



public struct InstallSimulatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var installer = DeviceHubSimulatorInstaller.shared
    @State private var selectedPlatform: DeviceHubPlatform = .iOS
    let onCompletion: (() -> Void)?

    public init(onCompletion: (() -> Void)? = nil) {
        self.onCompletion = onCompletion
    }

    public var body: some View {
        VStack(spacing: 16) {
            
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Simulator Platform Runtimes")
                        .font(.headline)
                    Text("Download, install, and manage Apple Simulator platforms (iOS, iPadOS, watchOS, tvOS, visionOS)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") {
                    installer.queryPlatformStatuses()
                }
                .buttonStyle(.borderless)
                .disabled(installer.isRunning || installer.isQueryingPlatforms)
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Platform")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(DeviceHubPlatform.allCases) { platform in
                            let status = installer.platformStatuses[platform]
                            let isSelected = selectedPlatform == platform
                            Button {
                                selectedPlatform = platform
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: platform.iconName)
                                        .font(.system(size: 24))
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                    Text(platform.title)
                                        .font(.subheadline)
                                        .fontWeight(isSelected ? .bold : .medium)
                                    if let s = status, s.isInstalled {
                                        Text("Installed")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(.green)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.green.opacity(0.12))
                                            .cornerRadius(4)
                                    } else {
                                        Text("Available (\(platform.typicalSize))")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 95, height: 85)
                                .background(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                                )
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(installer.isRunning)
                        }
                    }
                    .padding(.vertical, 2)
                }

                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedPlatform.subtitle)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(selectedPlatform == .iPadOS
                             ? "iPadOS simulator devices run on the iOS simulator runtime bundle using tablet profiles."
                             : "Invokes `xcodebuild -downloadPlatform \(selectedPlatform.downloadName)` via background Process.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
            .padding(.horizontal)

            
            if installer.isRunning || installer.progressFraction != nil {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(installer.progressStage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        if let f = installer.progressFraction {
                            Text("\(Int(f * 100))%")
                                .font(.monospacedDigit(.subheadline)())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let f = installer.progressFraction {
                        ProgressView(value: f)
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }

                    Text(installer.progressLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal)
            }

            if let error = installer.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal)
            }

            
            if !installer.logLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Execution Output")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(installer.logLines.suffix(30).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 90)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                }
                .padding(.horizontal)
            }

            Spacer()

            
            HStack {
                if installer.isRunning {
                    Button("Cancel") {
                        installer.cancel()
                    }
                } else {
                    Button("Close") {
                        dismiss()
                    }

                    Button("Import DMG…") {
                        importDiskImage()
                    }
                    .buttonStyle(.bordered)
                    .disabled(installer.isRunning)

                    Button("Download All Platforms") {
                        installer.installAllPlatforms { success in
                            if success { onCompletion?() }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(installer.isRunning)
                }

                Spacer()

                Button(installer.isRunning ? "Downloading…" : "Install \(selectedPlatform.title)") {
                    installer.installPlatform(selectedPlatform) { success in
                        if success {
                            onCompletion?()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(installer.isRunning)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 560, height: 460)
        .onAppear {
            installer.queryPlatformStatuses()
        }
    }

    private func importDiskImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "dmg") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select an Apple Simulator Runtime Disk Image (.dmg) to install"
        if panel.runModal() == .OK, let url = panel.url {
            installer.importRuntimeDiskImage(at: url) { success in
                if success { onCompletion?() }
            }
        }
    }
}

public enum SimulatorCreateValidation {
    public static func runtimeFamily(identifier: String, name: String) -> String? {
        let haystack = (identifier + " " + name).lowercased()
        if haystack.contains("watchos") || haystack.contains("watch") { return "watchOS" }
        if haystack.contains("tvos") { return "tvOS" }
        if haystack.contains("xros") || haystack.contains("visionos") || haystack.contains("vision") { return "visionOS" }
        if haystack.contains("ios") { return "iOS" }
        return nil
    }

    public static func expectedRuntimeFamily(productFamily: String) -> String? {
        let family = productFamily.lowercased()
        if family.contains("watch") { return "watchOS" }
        if family.contains("tv") { return "tvOS" }
        if family.contains("vision") { return "visionOS" }
        if family.contains("iphone") || family.contains("ipad") { return "iOS" }
        return nil
    }

    public static func runtimeFamily(for platform: DeviceHubPlatform) -> String {
        switch platform {
        case .iOS, .iPadOS: return "iOS"
        case .watchOS: return "watchOS"
        case .tvOS: return "tvOS"
        case .visionOS: return "visionOS"
        }
    }

    public static func isCompatible(deviceType: DeviceTypeRecord, runtimeIdentifier: String, runtimeName: String) -> Bool {
        guard let expected = expectedRuntimeFamily(productFamily: deviceType.productFamily),
              let actual = runtimeFamily(identifier: runtimeIdentifier, name: runtimeName) else { return false }
        return expected == actual
    }

    public static func duplicateExistingName(_ name: String, existingNames: [String]) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return existingNames.first { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed.lowercased() }
    }

    public static func validationError(
        name: String,
        deviceType: DeviceTypeRecord?,
        runtimeName: String?,
        runtimeIdentifier: String?,
        existingNames: [String]
    ) -> String? {
        guard let deviceType, let runtimeName, let runtimeIdentifier else {
            return "Select a device type and a runtime before creating a simulator."
        }
        if !isCompatible(deviceType: deviceType, runtimeIdentifier: runtimeIdentifier, runtimeName: runtimeName) {
            if let expected = expectedRuntimeFamily(productFamily: deviceType.productFamily) {
                return "\(deviceType.name) cannot run on \(runtimeName). Choose a \(expected) runtime for this device type."
            }
            return "\(deviceType.name) cannot run on \(runtimeName). Choose a runtime for this device type."
        }
        if let existing = duplicateExistingName(name, existingNames: existingNames) {
            return "A simulator named “\(existing)” already exists. Choose a different name."
        }
        return nil
    }
}

public struct CreateSimulatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var installer = DeviceHubSimulatorInstaller.shared
    @State public var selectedPlatform: DeviceHubPlatform = .iOS
    @State private var simulatorName = ""
    @State private var selectedDeviceType = ""
    @State private var selectedRuntime = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    
    @State private var enableStageManager = true
    @State private var enableApplePencil = true

    let onCreated: ((String) -> Void)?

    public init(initialPlatform: DeviceHubPlatform = .iOS, onCreated: ((String) -> Void)? = nil) {
        _selectedPlatform = State(initialValue: initialPlatform)
        self.onCreated = onCreated
    }

    private var filteredDeviceTypes: [DeviceTypeRecord] {
        installer.deviceTypeRecords.filter { record in
            switch selectedPlatform {
            case .iOS:
                return record.productFamily == "iPhone" || record.name.contains("iPhone")
            case .iPadOS:
                return record.productFamily == "iPad" || record.name.contains("iPad")
            case .watchOS:
                return record.productFamily == "Apple Watch" || record.name.contains("Watch")
            case .tvOS:
                return record.productFamily == "Apple TV" || record.name.contains("TV")
            case .visionOS:
                return record.productFamily == "Apple Vision" || record.name.contains("Vision")
            }
        }
    }

    private var filteredRuntimes: [(name: String, identifier: String)] {
        let family = SimulatorCreateValidation.runtimeFamily(for: selectedPlatform)
        return installer.availableRuntimes.filter { runtime in
            SimulatorCreateValidation.runtimeFamily(identifier: runtime.identifier, name: runtime.name) == family
        }
    }

    private var selectedDeviceTypeRecord: DeviceTypeRecord? {
        filteredDeviceTypes.first { $0.identifier == selectedDeviceType }
    }

    private var selectedRuntimeRecord: (name: String, identifier: String)? {
        filteredRuntimes.first { $0.identifier == selectedRuntime }
    }

    private var createValidationMessage: String? {
        let trimmedName = simulatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        guard !selectedDeviceType.isEmpty, !selectedRuntime.isEmpty else {
            return "Select a device type and a runtime before creating a simulator."
        }
        return SimulatorCreateValidation.validationError(
            name: trimmedName,
            deviceType: selectedDeviceTypeRecord,
            runtimeName: selectedRuntimeRecord?.name,
            runtimeIdentifier: selectedRuntimeRecord?.identifier,
            existingNames: installer.existingSimulatorNames
        )
    }

    public var body: some View {
        VStack(spacing: 14) {
            
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Simulator")
                        .font(.headline)
                    Text("Configure and provision a new simulator instance with Apple's `simctl` tool")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Platform")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach(DeviceHubPlatform.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedPlatform) { _ in
                        updateSelectionForPlatform()
                    }
                }

                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Simulator Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Simulator Name", text: $simulatorName)
                        .textFieldStyle(.roundedBorder)
                }

                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Type")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: $selectedDeviceType) {
                        if filteredDeviceTypes.isEmpty {
                            Text("Loading device types…").tag("")
                        }
                        ForEach(filteredDeviceTypes) { dt in
                            Text(dt.name).tag(dt.identifier)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedDeviceType) { _ in
                        updateDefaultName()
                    }
                }

                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Runtime")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("", selection: $selectedRuntime) {
                        if filteredRuntimes.isEmpty {
                            Text(installer.availableRuntimes.isEmpty ? "Loading runtimes…" : "No compatible runtime available").tag("")
                        }
                        ForEach(filteredRuntimes, id: \.identifier) { r in
                            Text(r.name).tag(r.identifier)
                        }
                    }
                    .pickerStyle(.menu)
                }

                
                if selectedPlatform == .iPadOS {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("iPadOS Tablet Features")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            Toggle("Enable Stage Manager", isOn: $enableStageManager)
                                .font(.caption)
                            Toggle("Enable Apple Pencil Simulation", isOn: $enableApplePencil)
                                .font(.caption)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
                }

                if let err = createValidationMessage ?? errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)

            Spacer()

            
            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button(isCreating ? "Creating…" : "Create Simulator") {
                    create()
                }
                .buttonStyle(.borderedProminent)
                .disabled(simulatorName.trimmingCharacters(in: .whitespaces).isEmpty || selectedDeviceType.isEmpty || selectedRuntime.isEmpty || createValidationMessage != nil || isCreating)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 500, height: selectedPlatform == .iPadOS ? 430 : 380)
        .onAppear {
            installer.fetchAvailableTypesAndRuntimes()
            installer.refreshExistingSimulatorNames()
            updateSelectionForPlatform()
        }
        .onChange(of: installer.deviceTypeRecords.count) { _ in
            updateSelectionForPlatform()
        }
        .onChange(of: installer.availableRuntimes.count) { _ in
            updateSelectionForPlatform()
        }
    }

    private func updateSelectionForPlatform() {
        if selectedDeviceType.isEmpty || !filteredDeviceTypes.contains(where: { $0.identifier == selectedDeviceType }) {
            selectedDeviceType = filteredDeviceTypes.first?.identifier ?? ""
        }
        if selectedRuntime.isEmpty || !filteredRuntimes.contains(where: { $0.identifier == selectedRuntime }) {
            selectedRuntime = filteredRuntimes.first?.identifier ?? ""
        }
        updateDefaultName()
    }

    private func updateDefaultName() {
        if let chosen = filteredDeviceTypes.first(where: { $0.identifier == selectedDeviceType }) {
            simulatorName = "\(chosen.name) (\(selectedPlatform.title))"
        }
    }

    private func create() {
        let name = simulatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Enter a name for the simulator."
            return
        }
        guard !selectedDeviceType.isEmpty, !selectedRuntime.isEmpty else {
            errorMessage = "Select a device type and a runtime before creating a simulator."
            return
        }
        isCreating = true
        errorMessage = nil

        Task {
            let freshNames = (try? await DeviceHubSimulatorInstaller.fetchExistingSimulatorNames()) ?? installer.existingSimulatorNames
            let deviceType = selectedDeviceTypeRecord
            let runtime = selectedRuntimeRecord
            let problem: String?
            if let deviceType, let runtime {
                problem = SimulatorCreateValidation.validationError(name: name, deviceType: deviceType, runtimeName: runtime.name, runtimeIdentifier: runtime.identifier, existingNames: freshNames)
            } else {
                problem = "Select a device type and a runtime before creating a simulator."
            }
            if let problem {
                await MainActor.run {
                    self.isCreating = false
                    self.errorMessage = problem
                }
                return
            }
            do {
                let udid = try await DeviceHubSimulatorInstaller.createSimulator(name: name, deviceTypeID: selectedDeviceType, runtimeID: selectedRuntime)

                
                if selectedPlatform == .iPadOS {
                    if enableStageManager {
                        try? await DeviceHubSimulatorInstaller.setStageManager(udid: udid, enabled: true)
                    }
                    if enableApplePencil {
                        try? await DeviceHubSimulatorInstaller.simulateApplePencilAction(udid: udid, action: "doubleTap")
                    }
                }

                await MainActor.run {
                    self.isCreating = false
                    self.onCreated?(udid)
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isCreating = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}


public struct CloneSimulatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sourceUDID: String
    let sourceName: String
    @State private var cloneName: String
    @State private var isCloning = false
    @State private var errorMessage: String?
    let onCloned: ((String) -> Void)?

    public init(sourceUDID: String, sourceName: String, onCloned: ((String) -> Void)? = nil) {
        self.sourceUDID = sourceUDID
        self.sourceName = sourceName
        _cloneName = State(initialValue: "\(sourceName) (Clone)")
        self.onCloned = onCloned
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "square.on.square.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clone Simulator")
                        .font(.headline)
                    Text("Duplicate “\(sourceName)” with all installed data and settings via `simctl clone`")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Simulator Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Name", text: $cloneName)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Cloning duplicates application sandbox containers, cookies, and UserDefaults preferences.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button(isCloning ? "Cloning…" : "Clone Simulator") {
                    clone()
                }
                .buttonStyle(.borderedProminent)
                .disabled(cloneName.trimmingCharacters(in: .whitespaces).isEmpty || isCloning)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 460, height: 260)
    }

    private func clone() {
        guard !cloneName.isEmpty else { return }
        isCloning = true
        errorMessage = nil

        Task {
            do {
                let newUDID = try await DeviceHubSimulatorInstaller.cloneSimulator(sourceUDID: sourceUDID, newName: cloneName)
                await MainActor.run {
                    self.isCloning = false
                    self.onCloned?(newUDID)
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isCloning = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
