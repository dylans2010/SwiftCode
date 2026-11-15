import Foundation
import Observation
import os
import YcodeDeviceModel
#if canImport(AppKit)
import AppKit
#endif

@Observable
@MainActor
public final class SimulatorManager {
    public static let shared = SimulatorManager()

    public private(set) var state: SimulatorDiscoveryState = .idle
    public private(set) var diagnostics: SimulatorDiagnosticsSnapshot = .initial

    public private(set) var devices: [SimulatorDevice] = []
    public private(set) var runtimes: [SimulatorRuntime] = []
    public private(set) var installedApps: [SimulatorApplication] = []
    public private(set) var consoleLogs: [String] = []

    public var selectedDeviceID: String? {
        didSet {
            DeviceGroupStore(defaults: .standard).saveSimulatorSelection(selectedDeviceID)
            Task { await refreshInstalledApplications() }
        }
    }
    public var selectedRuntimeID: String?

    public var selectedDevice: SimulatorDevice? {
        devices.first { $0.udid == selectedDeviceID }
    }

    public var selectedRuntime: SimulatorRuntime? {
        runtimes.first { $0.identifier == selectedRuntimeID }
    }

    public var isRefreshing: Bool {
        switch state {
        case .discovering:
            return true
        default:
            return false
        }
    }

    public var configuration = SimulatorConfiguration()

    private var activeRefreshTask: Task<Void, Never>?

    private let simctlService = SimctlService()
    private let installationService = SimulatorInstallationService()
    private let loggingService = SimulatorLoggingService()

    private init() {
        self.state = .discovering(stage: .initializing)
        self.selectedDeviceID = DeviceGroupStore(defaults: .standard).savedSimulatorSelection()
        Task {
            await refreshAll()
        }
    }

    public func refresh() async {
        await refreshAll()
    }

    public func refreshAll() async {
        activeRefreshTask?.cancel()

        let task = Task {
            let refreshStartedAt = Date()
            Logger.discovery.info("[MANAGER] Kicking off unified discovery refresh...")

            do {
                let snapshot = try await SimulatorDiscoveryPipeline.shared.runPipeline { [weak self] stage in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.state = .discovering(stage: stage)
                        self.updateDiagnostics(stage: stage, snapshot: nil, error: nil)
                    }
                }

                if !Task.isCancelled {
                    self.devices = snapshot.devices
                    self.runtimes = snapshot.runtimes

                    if self.selectedDeviceID == nil, let firstBooted = snapshot.devices.first(where: { $0.state == .booted }) ?? snapshot.devices.first {
                        self.selectedDeviceID = firstBooted.udid
                    }
                    if self.selectedRuntimeID == nil, let firstRuntime = snapshot.runtimes.first {
                        self.selectedRuntimeID = firstRuntime.identifier
                    }

                    await self.refreshInstalledApplications()
                    if snapshot.runtimes.isEmpty {
                        self.state = .empty(reason: .noRuntimesInstalled)
                        self.log("No simulator runtimes discovered on this developer workstation.")
                    } else {
                        self.state = .loaded(snapshot)
                        self.log("Discovery complete. Resolved \(snapshot.devices.count) devices and \(snapshot.runtimes.count) runtimes.")
                    }

                    self.updateDiagnostics(stage: .complete, snapshot: snapshot, error: nil)
                }

            } catch let error as SimulatorDiscoveryError {
                if !Task.isCancelled {
                    self.state = .failed(error: error)
                    self.log("Discovery pipeline failed at stage '\(error.stage.rawValue)': \(error.underlyingMessage)", isError: true)
                    self.updateDiagnostics(stage: error.stage, snapshot: nil, error: error)
                }
            } catch {
                if !Task.isCancelled {
                    let wrappedError = SimulatorDiscoveryError(stage: .initializing, underlyingMessage: error.localizedDescription)
                    self.state = .failed(error: wrappedError)
                    self.log("Unexpected pipeline error: \(error.localizedDescription)", isError: true)
                    self.updateDiagnostics(stage: .initializing, snapshot: nil, error: wrappedError)
                }
            }
        }

        activeRefreshTask = task
        await task.value
    }

    private func updateDiagnostics(stage: DiscoveryStage, snapshot: SimulatorSnapshot?, error: SimulatorDiscoveryError?) {
        Task {
            let envProbe = await DeveloperEnvironmentProbe.shared.runProbe()
            let history = await CommandExecutionEngine.shared.getHistory()

            await MainActor.run {
                let rCount = snapshot?.runtimes.count ?? self.runtimes.count
                let dCount = snapshot?.devices.count ?? self.devices.count
                let bCount = snapshot?.bootedDeviceIDs.count ?? self.devices.filter({ $0.state == .booted }).count

                self.diagnostics = SimulatorDiagnosticsSnapshot(
                    developerDirectory: envProbe.developerDirectory,
                    xcodeVersion: envProbe.xcodeVersion,
                    xcrunLocation: envProbe.xcrunVersion != nil ? "/usr/bin/xcrun" : nil,
                    simctlAvailable: envProbe.xcrunVersion != nil,
                    runtimeCount: rCount,
                    deviceCount: dCount,
                    runningSimulatorCount: bCount,
                    lastRefreshDate: snapshot?.generatedAt ?? Date(),
                    lastDiscoveryDuration: snapshot?.discoveryDuration ?? .zero,
                    recentCommands: history
                )
            }
        }
    }

    public func bootSelectedDevice() async {
        guard let udid = selectedDeviceID, let device = selectedDevice else { return }

        let runtimeID = device.runtimeIdentifier
        let runtimeExists = runtimes.contains { $0.identifier == runtimeID }
        guard runtimeExists else {
            updateDeviceState(udid: udid, to: .failed)
            log("Failed to boot: The SDK runtime '\(runtimeID)' for this simulator does not exist.", isError: true)
            return
        }

        log("Booting device '\(udid)'...")
        updateDeviceState(udid: udid, to: .booting)

        do {
            try await simctlService.bootDevice(udid: udid)
            updateDeviceState(udid: udid, to: .booted)
            log("Device booted successfully in simctl.")

            log("Waiting for simulator boot completion...")
            let bootstatusSpec = CommandSpec(
                executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
                arguments: ["simctl", "bootstatus", udid]
            )
            _ = try? await CommandExecutionEngine.shared.execute(bootstatusSpec)

            updateDeviceState(udid: udid, to: .launchingSimulator)
            log("Launching Apple's native Simulator application...")

            #if os(macOS)
            let workspace = NSWorkspace.shared
            let bundleID = "com.apple.iphonesimulator"
            if let simulatorAppURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                try await workspace.openApplication(at: simulatorAppURL, configuration: config)
            } else if let fallbackURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.CoreSimulator.SimulatorTrampoline") {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                try await workspace.openApplication(at: fallbackURL, configuration: config)
            } else {
                let openSpec = CommandSpec(
                    executableURL: URL(fileURLWithPath: "/usr/bin/open"),
                    arguments: ["-a", "Simulator"]
                )
                _ = try? await CommandExecutionEngine.shared.execute(openSpec)
            }
            #endif

            updateDeviceState(udid: udid, to: .ready)
            log("Simulator is ready and frontmost.")

            await refreshAll()
        } catch {
            updateDeviceState(udid: udid, to: .failed)
            log("Failed to boot/launch simulator: \(error.localizedDescription)", isError: true)
        }
    }

    public func shutdownSelectedDevice() async {
        guard let udid = selectedDeviceID else { return }
        log("Shutting down device '\(udid)'...")
        updateDeviceState(udid: udid, to: .shuttingDown)

        do {
            try await simctlService.shutdownDevice(udid: udid)
            updateDeviceState(udid: udid, to: .shutdown)
            log("Device shutdown complete.")
            await refreshAll()
        } catch {
            updateDeviceState(udid: udid, to: .booted)
            log("Failed to shutdown: \(error.localizedDescription)", isError: true)
        }
    }

    public func restartSelectedDevice() async {
        await shutdownSelectedDevice()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await bootSelectedDevice()
    }

    public func eraseSelectedDevice() async {
        guard let udid = selectedDeviceID else { return }
        log("Erasing contents and settings for device '\(udid)'...")
        updateDeviceState(udid: udid, to: .erasing)

        do {
            try await simctlService.eraseDevice(udid: udid)
            updateDeviceState(udid: udid, to: .shutdown)
            log("Erase completed.")
            await refreshAll()
        } catch {
            updateDeviceState(udid: udid, to: .shutdown)
            log("Failed to erase: \(error.localizedDescription)", isError: true)
        }
    }

    public func deleteSelectedDevice() async {
        guard let udid = selectedDeviceID else { return }
        log("Deleting device '\(udid)' permanently...")

        do {
            try await simctlService.deleteDevice(udid: udid)
            log("Device deleted.")
            self.selectedDeviceID = nil
            await refreshAll()
        } catch {
            log("Failed to delete device: \(error.localizedDescription)", isError: true)
        }
    }

    public func createNewDevice(name: String, deviceType: String, runtime: String) async {
        log("Creating custom device '\(name)' (\(deviceType)) with runtime \(runtime)...")
        do {
            try await simctlService.createDevice(name: name, deviceType: deviceType, runtime: runtime)
            log("New simulator created successfully.")
            await refreshAll()
        } catch {
            log("Failed to create device: \(error.localizedDescription)", isError: true)
        }
    }

    public func installApplication(at url: URL) async {
        guard let udid = selectedDeviceID else { return }
        log("Deploying bundle '\(url.lastPathComponent)' to '\(udid)'...")

        do {
            try await installationService.installApp(at: url.path, onDeviceUDID: udid)
            log("Bundle installed successfully.")
            await refreshInstalledApplications()
        } catch {
            log("Deployment failed: \(error.localizedDescription)", isError: true)
        }
    }

    public func launchApplication(bundleID: String, args: [String] = []) async {
        guard let udid = selectedDeviceID else { return }
        log("Launching '\(bundleID)'...")
        do {
            try await simctlService.launchApplication(udid: udid, bundleID: bundleID, args: args)
            log("App launched.")
        } catch {
            log("Launch failed: \(error.localizedDescription)", isError: true)
        }
    }

    public func terminateApplication(bundleID: String) async {
        guard let udid = selectedDeviceID else { return }
        log("Terminating '\(bundleID)'...")
        do {
            try await simctlService.terminateApplication(udid: udid, bundleID: bundleID)
            log("App terminated.")
        } catch {
            log("Termination failed: \(error.localizedDescription)", isError: true)
        }
    }

    public func uninstallApplication(bundleID: String) async {
        guard let udid = selectedDeviceID else { return }
        log("Uninstalling '\(bundleID)'...")
        do {
            try await simctlService.uninstallApplication(udid: udid, bundleID: bundleID)
            log("App uninstalled.")
            await refreshInstalledApplications()
        } catch {
            log("Uninstall failed: \(error.localizedDescription)", isError: true)
        }
    }

    public func clearConsoleLogs() {
        Task {
            await loggingService.clear()
            self.consoleLogs = []
        }
    }

    private func log(_ message: String, isError: Bool = false) {
        Task {
            await loggingService.log(message, type: isError ? .error : .default)
            let currentLogs = await loggingService.getLogs()
            await MainActor.run {
                self.consoleLogs = currentLogs
            }
        }
    }

    private func updateDeviceState(udid: String, to newState: SimulatorState) {
        if let idx = devices.firstIndex(where: { $0.udid == udid }) {
            var updated = devices[idx]
            updated.state = newState
            devices[idx] = updated
        }
    }

    public func captureScreenshot() async throws -> URL {
        guard let udid = selectedDeviceID else {
            throw SimulatorError.simctlFailed(reason: "No simulator device is selected.")
        }
        return try await simctlService.captureScreenshot(udid: udid)
    }

    public func captureScreenshot(udid: String, to url: URL) async throws {
        try await simctlService.captureScreenshot(udid: udid, to: url)
    }

    nonisolated public static func captureScreenshotSync(udid: String, to url: URL) throws {
        let command = SimulatorCommand.screenshot(udid: udid, path: url.path)
        let result = try DeviceConnectProcessRunner.shared.runBlocking(
            executableURL: URL(fileURLWithPath: command.executable),
            arguments: command.arguments,
            timeout: command.timeout
        )
        guard result.exitCode == 0 else {
            throw SimulatorError.simctlFailed(reason: result.stderr.isEmpty ? "simctl screenshot failed with exit code \(result.exitCode)." : result.stderr)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SimulatorError.simctlFailed(reason: "simctl reported success but no screenshot file was created.")
        }
    }

    nonisolated public static func startScreenRecording(udid: String, deviceName: String, into directory: URL) throws -> (process: Process, url: URL) {
        let stamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current,
                                                formatOptions: [.withYear, .withMonth, .withDay, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime])
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("\(deviceName) Recording \(stamp).mov")
        let command = SimulatorCommand.recordVideo(udid: udid, path: url.path)
        let process = try DeviceConnectProcessRunner.shared.runStreaming(
            executableURL: URL(fileURLWithPath: command.executable),
            arguments: command.arguments,
            onStdout: { _ in },
            onStderr: { _ in }
        )
        return (process, url)
    }

    nonisolated public static func stopScreenRecording(_ process: Process) {
        if process.isRunning {
            #if canImport(Darwin)
            Darwin.kill(process.processIdentifier, SIGINT)
            #else
            process.terminate()
            #endif
            let deadline = Date().addingTimeInterval(10)
            while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
            if process.isRunning { process.terminate() }
        }
    }

    nonisolated public static func devicePlistURL(udid: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices/\(udid)/device.plist")
    }

    nonisolated public static func writeDeviceName(plistURL: URL, name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SimulatorError.simctlFailed(reason: "Device name must not be empty.")
        }
        let data: Data
        do {
            data = try Data(contentsOf: plistURL)
        } catch {
            throw SimulatorError.simctlFailed(reason: "Could not read \(plistURL.path): \(error.localizedDescription)")
        }
        let plist: Any
        do {
            plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw SimulatorError.simctlFailed(reason: "Could not parse \(plistURL.path): \(error.localizedDescription)")
        }
        guard var dict = plist as? [String: Any] else {
            throw SimulatorError.simctlFailed(reason: "Unexpected device.plist format at \(plistURL.path).")
        }
        dict["name"] = trimmed
        let newData: Data
        do {
            newData = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        } catch {
            throw SimulatorError.simctlFailed(reason: "Could not serialize device.plist: \(error.localizedDescription)")
        }
        do {
            try newData.write(to: plistURL, options: .atomic)
        } catch {
            throw SimulatorError.simctlFailed(reason: "Could not write \(plistURL.path): \(error.localizedDescription)")
        }
        let verificationData: Data
        do {
            verificationData = try Data(contentsOf: plistURL)
        } catch {
            throw SimulatorError.simctlFailed(reason: "Could not re-read \(plistURL.path) to verify the rename: \(error.localizedDescription)")
        }
        do {
            let verification = try PropertyListSerialization.propertyList(from: verificationData, options: [], format: nil)
            guard let verificationDict = verification as? [String: Any],
                  let verifiedName = verificationDict["name"] as? String,
                  verifiedName == trimmed else {
                throw SimulatorError.simctlFailed(reason: "Rename did not persist: re-read of \(plistURL.path) does not contain the new name.")
            }
            return verifiedName
        } catch let error as SimulatorError {
            throw error
        } catch {
            throw SimulatorError.simctlFailed(reason: "Could not parse \(plistURL.path) to verify the rename: \(error.localizedDescription)")
        }
    }

    public func renameDevice(udid: String, to newName: String) async throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SimulatorError.simctlFailed(reason: "Device name must not be empty.")
        }
        guard let device = devices.first(where: { $0.udid == udid }) else {
            throw SimulatorError.deviceNotAvailable(udid: udid)
        }
        guard device.state == .shutdown else {
            throw SimulatorError.simctlFailed(reason: "Device '\(device.name)' must be shut down before renaming.")
        }
        let plistURL = Self.devicePlistURL(udid: udid)
        let verifiedName = try await Task.detached(priority: .userInitiated) {
            try Self.writeDeviceName(plistURL: plistURL, name: trimmed)
        }.value
        if let idx = devices.firstIndex(where: { $0.udid == udid }) {
            devices[idx] = SimulatorDevice(
                udid: device.udid,
                name: verifiedName,
                runtimeIdentifier: device.runtimeIdentifier,
                platform: device.platform,
                osVersion: device.osVersion,
                architecture: device.architecture,
                state: device.state,
                isAvailable: device.isAvailable,
                dateCreated: device.dateCreated
            )
        }
        log("Renamed device '\(udid)' to '\(verifiedName)'.")
    }

    public func cloneDevice(sourceUDID: String, newName: String) async throws -> String {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SimulatorError.simctlFailed(reason: "Clone name must not be empty.")
        }
        guard let source = devices.first(where: { $0.udid == sourceUDID }) else {
            throw SimulatorError.deviceNotAvailable(udid: sourceUDID)
        }
        log("Cloning device '\(source.name)' as '\(trimmed)'...")
        let newUDID = try await simctlService.cloneDevice(sourceUDID: sourceUDID, newName: trimmed)
        log("Clone created with UDID '\(newUDID)'.")
        await refreshAll()
        return newUDID
    }

    private func refreshInstalledApplications() async {
        guard let device = selectedDevice, device.state == .booted else {
            self.installedApps = []
            return
        }
        do {
            let apps = try await simctlService.fetchInstalledApplications(udid: device.udid, platform: device.platform)
            guard selectedDeviceID == device.udid else { return }
            self.installedApps = apps
        } catch {
            guard selectedDeviceID == device.udid else { return }
            self.installedApps = []
            log("Failed to list installed applications: \(error.localizedDescription)", isError: true)
        }
    }
}
