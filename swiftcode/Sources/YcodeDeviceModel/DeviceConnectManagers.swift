import Foundation
import Observation

@Observable
@MainActor
public final class DeviceConnectBuildManager {
    public static let shared = DeviceConnectBuildManager()

    public private(set) var buildStatus: DeviceBuildStatus = .idle
    public private(set) var errors: [BuildParser.ParsedIssue] = []
    public private(set) var warnings: [BuildParser.ParsedIssue] = []
    public private(set) var buildDuration: TimeInterval = 0

    private init() {}

    public func startBuild() {
        buildStatus = .building
        errors.removeAll()
        warnings.removeAll()
        buildDuration = 0
    }

    public func finishBuild(success: Bool, rawLogs: String, duration: TimeInterval) {
        buildStatus = success ? .succeeded : .failed
        buildDuration = duration

        let issues = BuildParser.parseXcodebuildOutput(rawLogs)
        self.errors = issues.errors
        self.warnings = issues.warnings
    }
}

@Observable
@MainActor
public final class DeviceConnectConsoleManager {
    public static let shared = DeviceConnectConsoleManager()

    public private(set) var buildLogs: [DeviceLog] = []
    public private(set) var runtimeLogs: [DeviceLog] = []
    public private(set) var isPaused = false

    private var pausedLogs: [DeviceLog] = []

    public var selectedConsoleTab: Int = 0

    private init() {}

    public func appendLog(_ log: DeviceLog) {
        if isPaused {
            pausedLogs.append(log)
            return
        }
        if log.type == .build {
            buildLogs.append(log)
        } else {
            runtimeLogs.append(log)
        }
    }

    public func pause() {
        isPaused = true
    }

    public func resume() {
        isPaused = false
        let buffered = pausedLogs
        pausedLogs.removeAll()
        for log in buffered {
            if log.type == .build {
                buildLogs.append(log)
            } else {
                runtimeLogs.append(log)
            }
        }
    }

    public func clearLogs() {
        if selectedConsoleTab == 0 {
            buildLogs.removeAll()
            pausedLogs.removeAll { $0.type == .build }
        } else {
            runtimeLogs.removeAll()
            pausedLogs.removeAll { $0.type != .build }
        }
    }

    public func clearAllLogs() {
        buildLogs.removeAll()
        runtimeLogs.removeAll()
        pausedLogs.removeAll()
    }

    public static func filteredLogs(_ logs: [DeviceLog], searchText: String, severity: DeviceLog.Severity?) -> [DeviceLog] {
        logs.filter { log in
            (searchText.isEmpty || log.message.localizedCaseInsensitiveContains(searchText)) &&
            (severity == nil || log.severity == severity)
        }
    }

    public static func formattedText(_ logs: [DeviceLog]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return logs.map { log in
            "[\(formatter.string(from: log.timestamp))] [\(log.severity.rawValue)] \(log.message)"
        }.joined(separator: "\n")
    }

    public func visibleLogs(searchText: String, severity: DeviceLog.Severity?) -> [DeviceLog] {
        let logs = selectedConsoleTab == 0 ? buildLogs : runtimeLogs
        return Self.filteredLogs(logs, searchText: searchText, severity: severity)
    }

    public func exportText(searchText: String, severity: DeviceLog.Severity?) -> String {
        Self.formattedText(visibleLogs(searchText: searchText, severity: severity))
    }
}

@Observable
@MainActor
public final class DeviceConnectDeploymentManager {
    public static let shared = DeviceConnectDeploymentManager()

    public private(set) var deploymentStatus: DeploymentStatus = .idle
    public private(set) var currentStageDescription = "Idle"
    public private(set) var isDeploying = false
    public private(set) var logs: [DeviceLog] = []
    public private(set) var lastFailureReport: String?

    private init() {}

    public func startDeployment(
        device: ConnectedDevice,
        projectName: String,
        projectPath: String,
        scheme: String,
        appBundleURL: URL,
        bundleIdentifier: String
    ) async {
        guard !isDeploying else { return }
        isDeploying = true
        logs.removeAll()

        let session = DeviceConnectSessionManager.shared.createSession(
            device: device,
            projectName: projectName,
            configuration: "Debug"
        )

        let success = await DeviceConnectEngine.shared.deploy(
            device: device,
            projectName: projectName,
            projectPath: projectPath,
            scheme: scheme,
            appBundleURL: appBundleURL,
            bundleIdentifier: bundleIdentifier,
            onStateUpdate: { [weak self] status, desc in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.deploymentStatus = status
                    self.currentStageDescription = desc

                    var updatedSession = session
                    updatedSession.deploymentStatus = status
                    if status == .running {
                        updatedSession.runtimeStatus = .running
                    } else if status == .completed {
                        updatedSession.endTime = Date()
                    } else if status == .failed {
                        updatedSession.endTime = Date()
                        updatedSession.buildStatus = .failed
                    }
                    DeviceConnectSessionManager.shared.updateActiveSession(updatedSession)

                    if status == .completed || status == .failed || status == .cancelled {
                        self.isDeploying = false
                        let historyItem = DeploymentHistory(
                            projectName: projectName,
                            deviceName: device.name,
                            deviceUDID: device.udid,
                            duration: Date().timeIntervalSince(session.startTime),
                            buildResult: status == .failed ? .failed : .succeeded,
                            deployResult: status,
                            runResult: status == .completed ? .running : .idle
                        )
                        DeviceConnectHistoryManager.shared.addHistoryItem(historyItem)
                    }
                }
            },
            onLogUpdate: { [weak self] logLine in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    let parsedLog = LogParser.parseLogLine(logLine, type: .build)
                    self.logs.append(parsedLog)
                    DeviceConnectConsoleManager.shared.appendLog(parsedLog)
                }
            }
        )

        if success {
            DeviceConnectNotificationService.shared.postNotification(
                title: "Deployment Successful",
                subtitle: device.name,
                body: "Successfully deployed and launched \(projectName)."
            )
        } else {
            let report = await DiagnosticsFormatter.formatPipelineFailure(
                stage: deploymentStatus,
                error: "Deployment to \(device.name) failed.",
                deviceUDID: device.udid
            )
            lastFailureReport = report
            let failureLog = DeviceLog(type: .build, severity: .error, message: report)
            logs.append(failureLog)
            DeviceConnectConsoleManager.shared.appendLog(failureLog)
            DeviceConnectNotificationService.shared.postNotification(
                title: "Deployment Failed",
                subtitle: device.name,
                body: "Failed to deploy \(projectName). See the deployment log for the detected device state."
            )
        }
    }
}

@Observable
@MainActor
public final class DeviceConnectRuntimeManager {
    public static let shared = DeviceConnectRuntimeManager()

    public private(set) var runtimeStatus: RuntimeStatus = .idle
    public private(set) var metrics: DeviceMetrics = DeviceMetrics.unavailable
    public private(set) var activePID: Int32? = nil

    private var coordinator: RuntimeCoordinator?

    private init() {}

    public func updateRuntimeStatus(_ status: RuntimeStatus) {
        self.runtimeStatus = status
    }

    public func updateMetrics(_ metrics: DeviceMetrics) {
        self.metrics = metrics
    }

    public func startMonitoring(deviceUDID: String, bundleID: String, pid: Int32) {
        self.activePID = pid
        self.runtimeStatus = .running

        let coordinator = RuntimeCoordinator()
        self.coordinator = coordinator
        Task {
            await coordinator.startMonitoring(
                deviceUDID: deviceUDID,
                bundleID: bundleID,
                pid: pid,
                onStateChanged: { [weak self] status in
                    Task { @MainActor [weak self] in
                        self?.runtimeStatus = status
                    }
                },
                onMetrics: { [weak self] nextMetrics in
                    Task { @MainActor [weak self] in
                        self?.metrics = nextMetrics
                    }
                }
            )
        }
    }

    public func stopMonitoring(deviceUDID: String) {
        self.activePID = nil
        self.runtimeStatus = .idle
        if let coordinator {
            self.coordinator = nil
            Task { await coordinator.stopMonitoring(deviceUDID: deviceUDID) }
        }
    }
}

@Observable
@MainActor
public final class DeviceConnectDeviceManager {
    public static let shared = DeviceConnectDeviceManager()

    public private(set) var devices: [ConnectedDevice] = []
    public var selectedDevice: ConnectedDevice?
    public var isDiscovering = false
    public private(set) var discoveryError: String?

    private let service = DeviceConnectDeviceService()

    private var disconnectObserver: NSObjectProtocol?

    private init() {
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: DeviceConnectNotificationCenter.deviceDisconnected,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let udid = note.userInfo?["udid"] as? String else { return }
            Task { @MainActor [weak self] in
                self?.markDeviceDisconnected(udid: udid)
            }
        }
    }

    public func markDeviceDisconnected(udid: String) {
        devices = devices.map { device in
            device.udid == udid ? device.markingDisconnected() : device
        }
    }

    public func startDiscovery() async {
        guard !isDiscovering else { return }
        isDiscovering = true

        await DeviceConnectEngine.shared.startDiscovery { [weak self] discovered in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.discoveryError = nil
                self.devices = discovered
                if self.selectedDevice == nil, let first = discovered.first {
                    self.selectedDevice = first
                }
            }
        } onError: { [weak self] error in
            Task { @MainActor [weak self] in
                self?.discoveryError = error.localizedDescription
            }
        }
    }

    public func stopDiscovery() async {
        await DeviceConnectEngine.shared.stopDiscovery()
        isDiscovering = false
    }

    public func refreshDevices() async {
        do {
            let discovered = try await service.discover()
            self.discoveryError = nil
            self.devices = discovered
            if self.selectedDevice == nil || !discovered.contains(where: { $0.udid == self.selectedDevice?.udid }) {
                self.selectedDevice = discovered.first
            }
        } catch {
            self.discoveryError = error.localizedDescription
        }
    }

    public func selectDevice(_ device: ConnectedDevice) {
        self.selectedDevice = device
        DeviceConnectNotificationCenter.shared.post(
            name: DeviceConnectNotificationCenter.deviceConnected,
            userInfo: ["device": device]
        )
    }
}

@Observable
@MainActor
public final class DeviceConnectEnvironmentManager {
    public static let shared = DeviceConnectEnvironmentManager()

    public private(set) var currentEnvironment: DeviceEnvironment = DeviceEnvironment()
    public private(set) var diagnostics: [String] = []
    public private(set) var isValidating = false
    public private(set) var isDerivedDataClearing = false
    public private(set) var derivedDataSize: Double = 0

    private init() {}

    public func validateEnvironment() async {
        isValidating = true
        let result = await DeviceConnectEngine.shared.validate()
        self.currentEnvironment = result.environment
        self.diagnostics = result.diagnostics

        do {
            self.derivedDataSize = try await DerivedDataCommand().getDerivedDataSize()
        } catch {
            self.derivedDataSize = 0
        }

        isValidating = false
    }

    public func clearDerivedData() async {
        isDerivedDataClearing = true
        do {
            _ = try await DerivedDataCommand().clearDerivedData()
            self.derivedDataSize = 0
        } catch {}
        isDerivedDataClearing = false
    }
}

@Observable
@MainActor
public final class DeviceConnectHistoryManager {
    public static let shared = DeviceConnectHistoryManager()

    private static let historyKey = "SwiftCode.DeviceConnect.history"
    private static let historyLimit = 50

    public private(set) var historyItems: [DeploymentHistory] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let stored = try? JSONDecoder().decode([DeploymentHistory].self, from: data) {
            historyItems = stored
        }
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(historyItems) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyKey)
    }

    public func addHistoryItem(_ item: DeploymentHistory) {
        historyItems.insert(item, at: 0)
        if historyItems.count > Self.historyLimit {
            historyItems.removeLast(historyItems.count - Self.historyLimit)
        }
        saveHistory()
    }

    public func removeHistoryItem(_ item: DeploymentHistory) {
        historyItems.removeAll(where: { $0.id == item.id })
        saveHistory()
    }

    public func clearHistory() {
        historyItems.removeAll()
        saveHistory()
    }
}

@Observable
@MainActor
public final class DeviceConnectPreferencesManager {
    public static let shared = DeviceConnectPreferencesManager()

    public var autoDiscover: Bool {
        didSet { UserDefaults.standard.set(autoDiscover, forKey: "com.swiftcode.deviceconnect.autoDiscover") }
    }
    public var autoValidate: Bool {
        didSet { UserDefaults.standard.set(autoValidate, forKey: "com.swiftcode.deviceconnect.autoValidate") }
    }
    public var autoSaveBeforeDeploy: Bool {
        didSet { UserDefaults.standard.set(autoSaveBeforeDeploy, forKey: "com.swiftcode.deviceconnect.autoSaveBeforeDeploy") }
    }
    public var autoLaunch: Bool {
        didSet { UserDefaults.standard.set(autoLaunch, forKey: "com.swiftcode.deviceconnect.autoLaunch") }
    }
    public var autoStreamLogs: Bool {
        didSet { UserDefaults.standard.set(autoStreamLogs, forKey: "com.swiftcode.deviceconnect.autoStreamLogs") }
    }
    public var showNotifications: Bool {
        didSet { UserDefaults.standard.set(showNotifications, forKey: "com.swiftcode.deviceconnect.showNotifications") }
    }
    public var keepHistory: Bool {
        didSet { UserDefaults.standard.set(keepHistory, forKey: "com.swiftcode.deviceconnect.keepHistory") }
    }
    public var maxSessionCount: Int {
        didSet { UserDefaults.standard.set(maxSessionCount, forKey: "com.swiftcode.deviceconnect.maxSessionCount") }
    }

    private init() {
        self.autoDiscover = UserDefaults.standard.object(forKey: "com.swiftcode.deviceconnect.autoDiscover") as? Bool ?? true
        self.autoValidate = UserDefaults.standard.object(forKey: "com.swiftcode.deviceconnect.autoValidate") as? Bool ?? true
        self.autoSaveBeforeDeploy = UserDefaults.standard.object(forKey: "com.swiftcode.deviceconnect.autoSaveBeforeDeploy") as? Bool ?? true
        self.autoLaunch = UserDefaults.standard.object(forKey: "com.swiftcode.deviceconnect.autoLaunch") as? Bool ?? true
        self.autoStreamLogs = UserDefaults.standard.object(forKey: "com.swiftcode.deviceconnect.autoStreamLogs") as? Bool ?? true
        self.showNotifications = UserDefaults.standard.object(forKey: "com.swiftcode.deviceconnect.showNotifications") as? Bool ?? true
        self.keepHistory = UserDefaults.standard.object(forKey: "com.swiftcode.deviceconnect.keepHistory") as? Bool ?? true
        self.maxSessionCount = UserDefaults.standard.object(forKey: "com.swiftcode.deviceconnect.maxSessionCount") as? Int ?? 50
    }
}

@Observable
@MainActor
public final class DeviceConnectSessionManager {
    public static let shared = DeviceConnectSessionManager()

    private static let sessionsKey = "SwiftCode.DeviceConnect.sessions"
    private static let sessionsLimit = 50

    public private(set) var activeSession: DeviceSession?
    public private(set) var sessionsHistory: [DeviceSession] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.sessionsKey),
           let stored = try? JSONDecoder().decode([DeviceSession].self, from: data) {
            sessionsHistory = stored
        }
    }

    private func saveSessionsHistory() {
        guard let data = try? JSONEncoder().encode(sessionsHistory) else { return }
        UserDefaults.standard.set(data, forKey: Self.sessionsKey)
    }

    public func createSession(device: ConnectedDevice, projectName: String, configuration: String) -> DeviceSession {
        let session = DeviceSession(
            deviceUDID: device.udid,
            deviceName: device.name,
            projectName: projectName,
            configuration: configuration
        )
        activeSession = session
        sessionsHistory.append(session)
        if sessionsHistory.count > Self.sessionsLimit {
            sessionsHistory.removeFirst(sessionsHistory.count - Self.sessionsLimit)
        }
        saveSessionsHistory()
        return session
    }

    public func updateActiveSession(_ session: DeviceSession) {
        self.activeSession = session
        if let idx = sessionsHistory.firstIndex(where: { $0.id == session.id }) {
            sessionsHistory[idx] = session
        } else {
            sessionsHistory.append(session)
        }
        saveSessionsHistory()
    }

    public func endActiveSession(finalStatus: RuntimeStatus) {
        guard var session = activeSession else { return }
        session.endTime = Date()
        session.runtimeStatus = finalStatus
        session.deploymentStatus = .completed
        updateActiveSession(session)
        activeSession = nil
    }

    public func clearHistory() {
        sessionsHistory.removeAll()
        saveSessionsHistory()
    }
}

@Observable
@MainActor
public final class DeviceConnectSigningManager {
    public static let shared = DeviceConnectSigningManager()

    public private(set) var signingStatus: SigningStatus = .idle
    public private(set) var availableIdentities: [String] = []

    private let service = DeviceConnectSigningService()

    private init() {}

    public func verifySigning() async {
        signingStatus = .verifying
        do {
            let identities = try await service.validateIdentities()
            self.availableIdentities = identities
            if !identities.isEmpty {
                self.signingStatus = .valid
            } else {
                self.signingStatus = .invalid
            }
        } catch {
            self.availableIdentities = []
            self.signingStatus = .invalid
        }
    }
}
