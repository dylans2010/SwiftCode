import Foundation
import os
import YcodeDeviceModel

public actor SimctlService {
    private let executor = SimulatorCommandExecutor()
    private let logger = Logger(subsystem: "com.swiftcode.simulator", category: "SimctlService")

    public init() {}

    public struct PipelineDiagnostics: Sendable, Codable {
        public let xcodePath: String
        public let xcodeVersion: String
        public let xcrunVersion: String
        public let isSimctlAvailable: Bool
        public let runtimeCount: Int
        public let deviceCount: Int
        public let runningCount: Int
        public let lastRefreshTime: Date
        public let discoveryDuration: TimeInterval
        public let latestStderr: String
        public let latestExitCode: Int32
    }

    public func fetchDevicesAndRuntimes() async throws -> (devices: [SimulatorDevice], runtimes: [SimulatorRuntime]) {
        let command = SimulatorCommand.listEverything()
        let result = try await executor.execute(command)

        guard result.exitCode == 0 else {
            logger.error("List everything command returned non-zero code \(result.exitCode): \(result.errorOutput)")
            throw SimulatorError.simctlFailed(reason: "List command returned non-zero code. Output: \(result.errorOutput)")
        }

        guard let data = result.output.data(using: .utf8) else {
            throw SimulatorError.simctlFailed(reason: "Invalid list response encoding")
        }

        return try parseDevicesAndRuntimes(data: data)
    }

    public func parseDevicesAndRuntimes(data: Data) throws -> (devices: [SimulatorDevice], runtimes: [SimulatorRuntime]) {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            var parsedRuntimes: [SimulatorRuntime] = []
            if let runtimesList = json["runtimes"] as? [[String: Any]] {
                for r in runtimesList {
                    let identifier = r["identifier"] as? String ?? ""
                    let name = r["name"] as? String ?? ""
                    let version = r["version"] as? String ?? ""
                    let declaredPlatform = DevicePlatform(parsing: r["platform"] as? String)
                    let platform: String
                    if declaredPlatform != .unknown {
                        platform = declaredPlatform.rawValue
                    } else {
                        let fromName = DevicePlatform(parsing: name)
                        platform = fromName == .unknown ? DevicePlatform(runtimeIdentifier: identifier).rawValue : fromName.rawValue
                    }
                    let isAvailable = r["isAvailable"] as? Bool ?? true

                    if isAvailable {
                        parsedRuntimes.append(SimulatorRuntime(
                            identifier: identifier,
                            name: name,
                            version: version,
                            platform: platform,
                            isAvailable: isAvailable
                        ))
                    }
                }
            }

            parsedRuntimes.sort { r1, r2 in
                r1.version.compare(r2.version, options: .numeric) == .orderedDescending
            }

            var runtimeVersions: [String: String] = [:]
            var runtimePlatforms: [String: String] = [:]
            var runtimeArchitectures: [String: String] = [:]
            for r in parsedRuntimes {
                runtimeVersions[r.identifier] = r.version
                runtimePlatforms[r.identifier] = r.platform
            }
            if let runtimesList = json["runtimes"] as? [[String: Any]] {
                for r in runtimesList {
                    guard let id = r["identifier"] as? String,
                          let archs = r["supportedArchitectures"] as? [String],
                          let first = archs.first else { continue }
                    runtimeArchitectures[id] = first
                }
            }

            var parsedDevices: [SimulatorDevice] = []
            if let devicesMap = json["devices"] as? [String: [[String: Any]]] {
                for (runtimeKey, devList) in devicesMap {
                    let cleanRuntimeID = runtimeKey.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
                    let parts = cleanRuntimeID.split(separator: "-")
                    let platform = runtimePlatforms[runtimeKey] ?? DevicePlatform(runtimeIdentifier: runtimeKey).rawValue
                    let version = runtimeVersions[runtimeKey] ?? parts.dropFirst().joined(separator: ".")
                    let architecture = runtimeArchitectures[runtimeKey] ?? "Unknown"

                    for d in devList {
                        let udid = d["udid"] as? String ?? ""
                        let name = d["name"] as? String ?? ""
                        let stateStr = d["state"] as? String ?? "Shutdown"
                        let isAvailable = d["isAvailable"] as? Bool ?? true

                        let state: SimulatorState = {
                            switch stateStr.lowercased() {
                            case "booted": return .booted
                            case "booting": return .booting
                            case "shutting down": return .shuttingDown
                            case "shutdown": return .shutdown
                            default: return .unknown
                            }
                        }()

                        parsedDevices.append(SimulatorDevice(
                            udid: udid,
                            name: name,
                            runtimeIdentifier: runtimeKey,
                            platform: platform,
                            osVersion: version,
                            architecture: architecture,
                            state: state,
                            isAvailable: isAvailable
                        ))
                    }
                }
            }

            return (parsedDevices, parsedRuntimes)

        } catch {
            logger.error("[FAILED] parsing simctl JSON list: \(error.localizedDescription)")
            throw SimulatorError.simctlFailed(reason: "JSON decoding failed: \(error.localizedDescription)")
        }
    }

    public func runDiagnostics() async -> PipelineDiagnostics {
        let startTime = Date()

        let pathResult = try? await executor.execute(SimulatorCommand.determineDeveloperDirectory())
        let path = pathResult?.output.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unavailable"

        let versionResult = try? await executor.execute(SimulatorCommand.determineXcodeVersion())
        let xcodeVer = versionResult?.output.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unavailable"

        let xcrunResult = try? await executor.execute(SimulatorCommand.verifyXcrun())
        let xcrunVer = xcrunResult?.output.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unavailable"

        let listResult = try? await executor.execute(SimulatorCommand.listEverything())
        let isAvailable = listResult?.exitCode == 0

        var rCount = 0
        var dCount = 0
        var bCount = 0
        var latestErr = ""
        var latestExit: Int32 = 0

        if let data = listResult?.output.data(using: .utf8),
           let parsed = try? parseDevicesAndRuntimes(data: data) {
            rCount = parsed.runtimes.count
            dCount = parsed.devices.count
            bCount = parsed.devices.filter { $0.state == .booted }.count
        } else {
            latestErr = listResult?.errorOutput ?? "Failed to run list command"
            latestExit = listResult?.exitCode ?? -1
        }

        let duration = Date().timeIntervalSince(startTime)

        return PipelineDiagnostics(
            xcodePath: path,
            xcodeVersion: xcodeVer,
            xcrunVersion: xcrunVer,
            isSimctlAvailable: isAvailable,
            runtimeCount: rCount,
            deviceCount: dCount,
            runningCount: bCount,
            lastRefreshTime: Date(),
            discoveryDuration: duration,
            latestStderr: latestErr,
            latestExitCode: latestExit
        )
    }

    public func bootDevice(udid: String) async throws {
        let command = SimulatorCommand.boot(udid: udid)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func rebootDevice(udid: String) async throws {
        let command = SimulatorCommand.reboot(udid: udid)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func triggerShake(udid: String) async throws {
        let command = SimulatorCommand.notifyPost(udid: udid, notification: "com.apple.UIKit.SimulatorPreferences.ShakeDevice")
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func triggerMemoryWarning(udid: String) async throws {
        let command = SimulatorCommand.notifyPost(udid: udid, notification: "com.apple.UIKit.SimulatorPreferences.MemoryWarning")
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func setSlowAnimations(udid: String, enabled: Bool) async throws {
        let notif = enabled ? "com.apple.CoreGraphics.SlowAnimations.enable" : "com.apple.CoreGraphics.SlowAnimations.disable"
        let command = SimulatorCommand.notifyPost(udid: udid, notification: notif)
        _ = try? await executor.execute(command)
    }

    public func setStandbyMode(udid: String, enabled: Bool) async throws {
        let notif = enabled ? "com.apple.springboard.standby.enter" : "com.apple.springboard.standby.exit"
        let command = SimulatorCommand.notifyPost(udid: udid, notification: notif)
        _ = try? await executor.execute(command)
    }

    public func shutdownDevice(udid: String) async throws {
        let command = SimulatorCommand.shutdown(udid: udid)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func eraseDevice(udid: String) async throws {
        let command = SimulatorCommand.erase(udid: udid)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func deleteDevice(udid: String) async throws {
        let command = SimulatorCommand.delete(udid: udid)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func createDevice(name: String, deviceType: String, runtime: String) async throws {
        let command = SimulatorCommand.create(name: name, deviceType: deviceType, runtime: runtime)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func installApplication(udid: String, appPath: String) async throws {
        let command = SimulatorCommand.installApp(udid: udid, appPath: appPath)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func uninstallApplication(udid: String, bundleID: String) async throws {
        let command = SimulatorCommand.uninstallApp(udid: udid, bundleID: bundleID)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func launchApplication(udid: String, bundleID: String, args: [String]) async throws {
        let command = SimulatorCommand.launchApp(udid: udid, bundleID: bundleID, args: args)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    public func terminateApplication(udid: String, bundleID: String) async throws {
        let command = SimulatorCommand.terminateApp(udid: udid, bundleID: bundleID)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
    }

    
    
    public func captureScreenshot(udid: String) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftcode-screenshot-\(udid)-\(UUID().uuidString).png")
        try await captureScreenshot(udid: udid, to: url)
        return url
    }

    public func captureScreenshot(udid: String, to url: URL) async throws {
        let command = SimulatorCommand.screenshot(udid: udid, path: url.path)
        let result = try await executor.execute(command)
        if result.exitCode != 0 {
            throw SimulatorError.simctlFailed(reason: result.errorOutput)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SimulatorError.simctlFailed(reason: "simctl reported success but no screenshot file was created.")
        }
    }

    public func fetchInstalledApplications(udid: String, platform: String) async throws -> [SimulatorApplication] {
        let command = SimulatorCommand.listApps(udid: udid)
        let result = try await executor.execute(command)
        guard result.exitCode == 0 else {
            logger.error("List apps command returned non-zero code \(result.exitCode): \(result.errorOutput)")
            throw SimulatorError.simctlFailed(reason: "List apps command returned non-zero code. Output: \(result.errorOutput)")
        }
        guard let data = result.output.data(using: .utf8) else {
            throw SimulatorError.simctlFailed(reason: "Invalid listapps response encoding")
        }
        return try parseInstalledApplications(data: data, platform: platform)
    }

    public func parseInstalledApplications(data: Data, platform: String) throws -> [SimulatorApplication] {
        let plist: Any
        do {
            plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            logger.error("[FAILED] parsing simctl listapps output: \(error.localizedDescription)")
            throw SimulatorError.simctlFailed(reason: "listapps output is not a valid property list: \(error.localizedDescription)")
        }
        guard let appsByID = plist as? [String: Any] else {
            throw SimulatorError.simctlFailed(reason: "listapps output is not a dictionary keyed by bundle identifier.")
        }
        var apps: [SimulatorApplication] = []
        for (bundleID, record) in appsByID {
            guard !bundleID.isEmpty, let info = record as? [String: Any] else { continue }
            let displayName = (info["CFBundleDisplayName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let bundleName = (info["CFBundleName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let name = displayName ?? bundleName ?? bundleID
            let path = info["Path"] as? String ?? ""
            let shortVersion = (info["CFBundleShortVersionString"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let version = shortVersion ?? info["CFBundleVersion"] as? String ?? ""
            apps.append(SimulatorApplication(bundleIdentifier: bundleID, name: name, path: path, version: version, targetPlatform: platform))
        }
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return apps
    }

    public func cloneDevice(sourceUDID: String, newName: String) async throws -> String {
        let command = SimulatorCommand.clone(udid: sourceUDID, name: newName)
        let result = try await executor.execute(command)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.exitCode == 0 else {
            logger.error("Clone command returned non-zero code \(result.exitCode): \(result.errorOutput)")
            throw SimulatorError.simctlFailed(reason: result.errorOutput.isEmpty ? "simctl clone failed with exit code \(result.exitCode)." : result.errorOutput)
        }
        guard !output.isEmpty else {
            throw SimulatorError.simctlFailed(reason: "simctl clone succeeded but returned no UDID for the new device.")
        }
        return output
    }
}
