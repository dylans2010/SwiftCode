import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public actor DeviceConnectCommandExecutor {
    public static let shared = DeviceConnectCommandExecutor()

    private var activeCommands: [UUID: Process] = [:]

    private init() {}

    public func registerActiveProcess(_ process: Process) -> UUID {
        let id = UUID()
        activeCommands[id] = process
        return id
    }

    public func terminateProcess(id: UUID) {
        if let proc = activeCommands[id] {
            if proc.isRunning {
                proc.terminate()
            }
            activeCommands.removeValue(forKey: id)
        }
    }

    public func terminateAll() {
        for id in activeCommands.keys {
            terminateProcess(id: id)
        }
    }
}

public actor DeploymentPipeline {
    private var isRunning = false

    public init() {}

    public func run(
        device: ConnectedDevice,
        projectName: String,
        projectPath: String,
        scheme: String,
        appBundleURL: URL,
        bundleIdentifier: String,
        onStateUpdate: @escaping @Sendable (DeploymentStatus, String) -> Void,
        onLogUpdate: @escaping @Sendable (String) -> Void
    ) async -> Bool {
        guard !isRunning else {
            onLogUpdate("Error: Pipeline is already running a deployment.")
            return false
        }
        isRunning = true
        defer { isRunning = false }

        let start = Date()

        onStateUpdate(.savingProject, "Saving project changes...")
        onLogUpdate("Save the workspace before deploying: this pipeline builds the files on disk as they are.")

        onStateUpdate(.validatingEnvironment, "Validating environment...")
        onLogUpdate("Running ValidateEnvironmentCommand...")
        do {
            let env = try await ValidateEnvironmentCommand().execute()
            if env.xcodePath == nil {
                onStateUpdate(.failed, "Environment validation failed.")
                onLogUpdate("[Error] Xcode path is empty or invalid. Check active developer directory.")
                return false
            }
        } catch {
            onStateUpdate(.failed, "Environment validation error.")
            onLogUpdate("[Error] \(error.localizedDescription)")
            return false
        }

        onStateUpdate(.resolvingBuildTarget, "Resolving build target...")
        onLogUpdate("Setting target destination to: id=\(device.udid)")

        onStateUpdate(.resolvingSigning, "Resolving signing configuration...")
        onLogUpdate("Validating signing identities with security find-identity...")
        do {
            let identities = try await SigningValidationCommand().execute()
            onLogUpdate("Found \(identities.count) code signing identit\(identities.count == 1 ? "y" : "ies").")
            if identities.isEmpty {
                let targetIsSimulator = await isSimulatorDevice(device.udid)
                if targetIsSimulator {
                    onLogUpdate("No signing identities found. Simulator targets build without signing, continuing.")
                } else {
                    onStateUpdate(.failed, "No signing identities found.")
                    onLogUpdate("[Error] No code signing identities are available for physical-device deployment. Create a signing identity in Xcode or SwiftCode Accounts settings.")
                    return false
                }
            }
        } catch {
            onStateUpdate(.failed, "Signing validation error.")
            onLogUpdate("[Error] \(error.localizedDescription)")
            return false
        }

        onStateUpdate(.buildingProject, "Building project...")
        onLogUpdate("Running BuildProjectCommand...")
        let buildSuccess = try? await BuildProjectCommand().execute(
            projectPath: projectPath,
            scheme: scheme,
            configuration: "Debug",
            destination: "id=\(device.udid)",
            onLog: onLogUpdate
        )

        if buildSuccess != true {
            onStateUpdate(.failed, "Build failed.")
            onLogUpdate("[Error] Compiler or linker error occurred during building.")
            return false
        }

        onStateUpdate(.validatingBuild, "Validating build artifacts...")
        var effectiveAppBundleURL = appBundleURL
        let fm = FileManager.default

        if !fm.fileExists(atPath: effectiveAppBundleURL.path) {
            let productsURL = URL(fileURLWithPath: projectPath).deletingLastPathComponent().appendingPathComponent("build/DerivedData/Build/Products")
            if let enumerator = fm.enumerator(at: productsURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                let files = enumerator.allObjects.compactMap { $0 as? URL }
                for fileURL in files {
                    if fileURL.pathExtension == "app" {
                        effectiveAppBundleURL = fileURL
                        break
                    }
                }
            }
        }

        guard fm.fileExists(atPath: effectiveAppBundleURL.path) else {
            onStateUpdate(.failed, "App bundle not found.")
            onLogUpdate("[Error] Could not locate compiled .app bundle. Checked: \(effectiveAppBundleURL.path)")
            return false
        }

        onLogUpdate("Located compiled app bundle at \(effectiveAppBundleURL.path)")

        onStateUpdate(.installingApplication, "Installing application...")
        onLogUpdate("Running InstallApplicationCommand...")
        let installSuccess = try? await InstallApplicationCommand().execute(
            deviceUDID: device.udid,
            appBundleURL: effectiveAppBundleURL,
            onProgress: onLogUpdate
        )

        if installSuccess != true {
            onStateUpdate(.failed, "Installation failed.")
            onLogUpdate("[Error] Failed to install application bundle onto the device.")
            return false
        }

        onStateUpdate(.launchingApplication, "Launching application...")
        onLogUpdate("Running LaunchApplicationCommand...")
        let pid = try? await LaunchApplicationCommand().execute(
            deviceUDID: device.udid,
            bundleIdentifier: bundleIdentifier
        )

        guard let actualPID = pid else {
            onStateUpdate(.failed, "Launch failed.")
            onLogUpdate("[Error] Failed to launch application with identifier: \(bundleIdentifier)")
            return false
        }

        onStateUpdate(.running, "Application running.")
        onLogUpdate("Application launched with PID \(actualPID). Starting syslog stream...")
        do {
            let syslogProcess = try RuntimeLogsCommand().execute(
                deviceUDID: device.udid,
                pid: actualPID,
                onLog: onLogUpdate
            )
            _ = await DeviceConnectCommandExecutor.shared.registerActiveProcess(syslogProcess)
            onLogUpdate("Syslog streaming started for PID \(actualPID).")
        } catch {
            onLogUpdate("Syslog streaming could not start (\(error.localizedDescription)). Deployment continues without live console output.")
        }

        let end = Date()
        let totalTime = end.timeIntervalSince(start)
        onStateUpdate(.completed, "Deployment completed successfully in \(String(format: "%.1f", totalTime))s.")

        return true
    }

    private func isSimulatorDevice(_ udid: String) async -> Bool {
        let xcrunURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        guard let result = try? await DeviceConnectProcessRunner.shared.run(
            executableURL: xcrunURL,
            arguments: ["simctl", "list", "devices", "-j"],
            timeout: 30
        ), result.exitCode == 0 else { return false }
        return result.stdout.contains(udid)
    }
}

public final class DeviceConnectEngine: Sendable {
    public static let shared = DeviceConnectEngine()

    private let discovery = DeviceDiscovery()
    private let pipeline = DeploymentPipeline()
    private let validator = EnvironmentValidator()

    private init() {}

    public func startDiscovery(onDiscover: @escaping @Sendable ([ConnectedDevice]) -> Void, onError: (@Sendable (Error) -> Void)? = nil) async {
        await discovery.startContinuousDiscovery(interval: 10, onDiscover: onDiscover, onError: onError)
    }

    public func stopDiscovery() async {
        await discovery.stopContinuousDiscovery()
    }

    public func validate() async -> (environment: DeviceEnvironment, diagnostics: [String]) {
        return await validator.validate()
    }

    public func deploy(
        device: ConnectedDevice,
        projectName: String,
        projectPath: String,
        scheme: String,
        appBundleURL: URL,
        bundleIdentifier: String,
        onStateUpdate: @escaping @Sendable (DeploymentStatus, String) -> Void,
        onLogUpdate: @escaping @Sendable (String) -> Void
    ) async -> Bool {
        return await pipeline.run(
            device: device,
            projectName: projectName,
            projectPath: projectPath,
            scheme: scheme,
            appBundleURL: appBundleURL,
            bundleIdentifier: bundleIdentifier,
            onStateUpdate: onStateUpdate,
            onLogUpdate: onLogUpdate
        )
    }
}

public actor DeviceDiscovery {
    private var isDiscovering = false
    private var timer: Task<Void, Never>?
    private var previousDevices: [ConnectedDevice] = []
    private var hasPreviousSnapshot = false

    public init() {}

    public static func disconnectedDevices(previous: [ConnectedDevice], current: [ConnectedDevice]) -> [ConnectedDevice] {
        let currentIDs = Set(current.map(\.udid))
        return previous.filter { !currentIDs.contains($0.udid) }
    }

    public static func newlyConnectedDevices(previous: [ConnectedDevice], current: [ConnectedDevice]) -> [ConnectedDevice] {
        let previousIDs = Set(previous.map(\.udid))
        return current.filter { !previousIDs.contains($0.udid) }
    }

    private func noteDiscovered(_ devices: [ConnectedDevice]) {
        if hasPreviousSnapshot {
            for gone in Self.disconnectedDevices(previous: previousDevices, current: devices) {
                DeviceConnectNotificationCenter.shared.post(name: DeviceConnectNotificationCenter.deviceDisconnected, userInfo: ["udid": gone.udid, "device": gone])
            }
            for arrived in Self.newlyConnectedDevices(previous: previousDevices, current: devices) {
                DeviceConnectNotificationCenter.shared.post(name: DeviceConnectNotificationCenter.deviceConnected, userInfo: ["udid": arrived.udid, "device": arrived])
            }
        }
        previousDevices = devices
        hasPreviousSnapshot = true
    }

    public func startContinuousDiscovery(interval: TimeInterval = 10, onDiscover: @escaping @Sendable ([ConnectedDevice]) -> Void, onError: (@Sendable (Error) -> Void)? = nil) {
        guard !isDiscovering else { return }
        isDiscovering = true

        timer = Task { [interval, onDiscover, onError] in
            while !Task.isCancelled {
                do {
                    let devices = try await DiscoverDevicesCommand().execute()
                    self.noteDiscovered(devices)
                    onDiscover(devices)
                } catch {
                    onError?(error)
                }

                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stopContinuousDiscovery() {
        timer?.cancel()
        timer = nil
        isDiscovering = false
        previousDevices = []
        hasPreviousSnapshot = false
    }
}

public struct EnvironmentValidator: Sendable {
    public init() {}

    public func validate() async -> (environment: DeviceEnvironment, diagnostics: [String]) {
        do {
            let env = try await ValidateEnvironmentCommand().execute()
            let diagnostics = DiagnosticsFormatter.formatEnvironmentDiagnostics(env)
            return (env, diagnostics)
        } catch {
            let fallback = DeviceEnvironment()
            return (fallback, ["Validation failed to execute: \(error.localizedDescription)"])
        }
    }
}

public final class DeviceConnectNotificationCenter: Sendable {
    public static let shared = DeviceConnectNotificationCenter()

    private init() {}

    public static let deviceConnected = Notification.Name("com.swiftcode.deviceconnect.connected")
    public static let deviceDisconnected = Notification.Name("com.swiftcode.deviceconnect.disconnected")
    public static let pipelineStateChanged = Notification.Name("com.swiftcode.deviceconnect.pipelineStateChanged")

    public func post(name: Notification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
    }
}

public actor RuntimeCoordinator {
    private var monitoringTasks: [String: Task<Void, Never>] = [:]

    public init() {}

    public func startMonitoring(deviceUDID: String, bundleID: String, pid: Int32, onStateChanged: @escaping @Sendable (RuntimeStatus) -> Void, onMetrics: @escaping @Sendable (DeviceMetrics) -> Void) {
        monitoringTasks[deviceUDID]?.cancel()

        monitoringTasks[deviceUDID] = Task { [deviceUDID, bundleID, pid, onStateChanged, onMetrics] in
            onStateChanged(.running)
            onMetrics(.unavailable(reason: "Apple exposes no per-process CPU, memory, battery, or thread telemetry for apps on a tethered device; only process liveness is observable via kill(pid, 0)."))

            while !Task.isCancelled {
                if !Self.processIsAlive(pid: pid) {
                    onStateChanged(.terminated)
                    break
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    public func stopMonitoring(deviceUDID: String) {
        monitoringTasks[deviceUDID]?.cancel()
        monitoringTasks.removeValue(forKey: deviceUDID)
    }

    private static func processIsAlive(pid: Int32) -> Bool {
#if canImport(Darwin) || canImport(Glibc)
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
#else
        return true
#endif
    }
}

public actor SessionCoordinator {
    public static let shared = SessionCoordinator()

    private static let pastSessionsKey = "SwiftCode.DeviceConnect.pastSessions"
    private static let pastSessionsLimit = 50

    private var activeSessions: [UUID: DeviceSession] = [:]
    private var pastSessions: [DeviceSession] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.pastSessionsKey),
           let stored = try? JSONDecoder().decode([DeviceSession].self, from: data) {
            pastSessions = stored
        }
    }

    private func savePastSessions() {
        guard let data = try? JSONEncoder().encode(pastSessions) else { return }
        UserDefaults.standard.set(data, forKey: Self.pastSessionsKey)
    }

    public func createSession(deviceUDID: String, deviceName: String, projectName: String, configuration: String) -> DeviceSession {
        let session = DeviceSession(
            deviceUDID: deviceUDID,
            deviceName: deviceName,
            projectName: projectName,
            configuration: configuration
        )
        activeSessions[session.id] = session
        return session
    }

    public func updateSession(_ session: DeviceSession) {
        activeSessions[session.id] = session
    }

    public func endSession(id: UUID, finalStatus: RuntimeStatus) -> DeviceSession? {
        guard var session = activeSessions[id] else { return nil }
        session.endTime = Date()
        session.runtimeStatus = finalStatus
        session.deploymentStatus = .completed
        activeSessions.removeValue(forKey: id)
        pastSessions.append(session)
        if pastSessions.count > Self.pastSessionsLimit {
            pastSessions.removeFirst(pastSessions.count - Self.pastSessionsLimit)
        }
        savePastSessions()
        return session
    }

    public func getActiveSession(id: UUID) -> DeviceSession? {
        return activeSessions[id]
    }

    public func getAllPastSessions() -> [DeviceSession] {
        return pastSessions
    }
}
