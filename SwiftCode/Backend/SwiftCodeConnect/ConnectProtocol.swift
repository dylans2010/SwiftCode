import Foundation

// MARK: - Protocol Constants & Versioning

public enum ConnectProtocolVersion {
    public static let current: Int = 1
    public static let serviceType = "_swiftcodeconnect._tcp"
    public static let domain = "local."
    public static let defaultPort: UInt16 = 8088
}

// MARK: - Permissions & Capabilities

public enum ConnectPermission: String, Codable, CaseIterable, Identifiable, Sendable {
    case projectInfo = "project.read"
    case gitRead = "git.read"
    case build = "build.execute"
    case tests = "tests.execute"
    case logs = "logs.read"
    case terminal = "terminal.execute"
    case fileModification = "files.write"
    case filesRead = "files.read"
    case assist = "assist.use"
    case deviceInfo = "device.read"
    case screenCapture = "screen.capture"
    case remoteControl = "remote.control"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .projectInfo: return "Project Information"
        case .gitRead: return "Git Operations"
        case .build: return "Build Control"
        case .tests: return "Test Execution"
        case .logs: return "Streaming Logs"
        case .terminal: return "Terminal Execution"
        case .fileModification: return "File Modifications"
        case .filesRead: return "Files Read"
        case .assist: return "Assist Context"
        case .deviceInfo: return "Device Metrics"
        case .screenCapture: return "Screen Capture"
        case .remoteControl: return "Remote Control"
        }
    }

    public var iconName: String {
        switch self {
        case .projectInfo: return "folder.fill"
        case .gitRead: return "arrow.triangle.branch"
        case .build: return "hammer.fill"
        case .tests: return "checkmark.seal.fill"
        case .logs: return "terminal.fill"
        case .terminal: return "command"
        case .fileModification: return "square.and.pencil"
        case .filesRead: return "doc.text.magnifyingglass"
        case .assist: return "sparkles"
        case .deviceInfo: return "desktopcomputer"
        case .screenCapture: return "display"
        case .remoteControl: return "iphone.and.arrow.forward"
        }
    }

    public var isSensitive: Bool {
        switch self {
        case .terminal, .fileModification, .remoteControl:
            return true
        default:
            return false
        }
    }
}

public enum ConnectCapability: String, Codable, CaseIterable, Sendable {
    case project
    case git
    case build
    case tests
    case logs
    case assist
    case terminal
    case files
    case devices
    case preview
}

// MARK: - Message Types

public enum ConnectMessageType: String, Codable, CaseIterable, Sendable {
    // Handshake & Authentication
    case pairingRequest = "pairing_request"
    case pairingResponse = "pairing_response"
    case authRequest = "auth_request"
    case authResponse = "auth_response"
    case ping = "ping"
    case pong = "pong"
    case disconnect = "disconnect"

    // Project & Workspace
    case projectRequest = "project_request"
    case projectResponse = "project_response"

    // Git
    case gitStatusRequest = "git_status_request"
    case gitStatusResponse = "git_status_response"
    case gitBranchesRequest = "git_branches_request"
    case gitBranchesResponse = "git_branches_response"
    case gitLogRequest = "git_log_request"
    case gitLogResponse = "git_log_response"

    // Build
    case buildRequest = "build_request"
    case buildResponse = "build_response"
    case cancelBuildRequest = "cancel_build_request"
    case buildStarted = "build_started"
    case buildProgress = "build_progress"
    case buildDiagnostic = "build_diagnostic"
    case buildOutput = "build_output"
    case buildCompleted = "build_completed"

    // Testing
    case testRequest = "test_request"
    case testResponse = "test_response"
    case cancelTestRequest = "cancel_test_request"
    case testStarted = "test_started"
    case testProgress = "test_progress"
    case testCompleted = "test_completed"

    // Logging
    case logsSubscribeRequest = "logs_subscribe_request"
    case logsUnsubscribeRequest = "logs_unsubscribe_request"
    case logEvent = "log_event"

    // Terminal
    case terminalExecuteRequest = "terminal_execute_request"
    case terminalCancelRequest = "terminal_cancel_request"
    case terminalOutput = "terminal_output"
    case terminalApprovalRequired = "terminal_approval_required"
    case terminalExit = "terminal_exit"

    // Assist / AI
    case assistQueryRequest = "assist_query_request"
    case assistActionRequest = "assist_action_request"
    case assistResponse = "assist_response"

    // Filesystem
    case fileListRequest = "file_list_request"
    case fileListResponse = "file_list_response"
    case fileReadRequest = "file_read_request"
    case fileReadResponse = "file_read_response"
    case fileWriteRequest = "file_write_request"
    case fileWriteResponse = "file_write_response"

    // Devices & Preview
    case deviceListRequest = "device_list_request"
    case deviceListResponse = "device_list_response"
    case screenCaptureRequest = "screen_capture_request"
    case screenCaptureResponse = "screen_capture_response"

    // Errors & Status
    case errorResponse = "error_response"
}

// MARK: - Canonical Message Envelope

public struct MessageEnvelope: Codable, Sendable {
    public let protocolVersion: Int
    public let messageID: String
    public let correlationID: String?
    public let type: ConnectMessageType
    public let timestamp: Date
    public let payload: Data

    public init(
        protocolVersion: Int = ConnectProtocolVersion.current,
        messageID: String = UUID().uuidString,
        correlationID: String? = nil,
        type: ConnectMessageType,
        timestamp: Date = Date(),
        payload: Data
    ) {
        self.protocolVersion = protocolVersion
        self.messageID = messageID
        self.correlationID = correlationID
        self.type = type
        self.timestamp = timestamp
        self.payload = payload
    }

    public static func encode<T: Encodable>(
        payload: T,
        type: ConnectMessageType,
        correlationID: String? = nil,
        messageID: String = UUID().uuidString
    ) throws -> MessageEnvelope {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        return MessageEnvelope(
            protocolVersion: ConnectProtocolVersion.current,
            messageID: messageID,
            correlationID: correlationID,
            type: type,
            timestamp: Date(),
            payload: data
        )
    }

    public func decodePayload<T: Decodable>(_ type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: payload)
    }
}

/// Backward compatibility alias
public typealias ConnectMessageEnvelope = MessageEnvelope

public extension ConnectMessageEnvelope {
    var id: String { messageID }
    var payloadData: Data? { payload }

    static func makeEnvelope<T: Codable>(
        type: ConnectMessageType,
        correlationID: String? = nil,
        payload: T
    ) throws -> ConnectMessageEnvelope {
        try MessageEnvelope.encode(payload: payload, type: type, correlationID: correlationID)
    }
}

// MARK: - Protocol Errors

public enum ConnectProtocolError: String, Error, Codable, LocalizedError, Sendable {
    case missingPayload = "missing_payload"
    case invalidPayload = "invalid_payload"
    case authenticationFailed = "authentication_failed"
    case pairingRejected = "pairing_rejected"
    case protocolMismatch = "protocol_mismatch"
    case permissionDenied = "permission_denied"
    case deviceUnavailable = "device_unavailable"
    case buildFailed = "build_failed"
    case connectionRefused = "connection_refused"
    case timeout = "timeout"
    case portUnavailable = "port_unavailable"
    case hostUnavailable = "host_unavailable"
    case bonjourMismatch = "bonjour_mismatch"
    case unknown = "unknown"

    public var errorDescription: String? {
        switch self {
        case .missingPayload:
            return "Message payload is missing from envelope."
        case .invalidPayload:
            return "Message payload could not be decoded."
        case .authenticationFailed:
            return "Authentication failed. Stored token was rejected by Mac."
        case .pairingRejected:
            return "Pairing verification request was rejected by the Mac."
        case .protocolMismatch:
            return "Incompatible SwiftCode Connect protocol version. Please update both apps."
        case .permissionDenied:
            return "Permission for this operation was not granted on Mac."
        case .deviceUnavailable:
            return "The Mac device is unavailable or offline."
        case .buildFailed:
            return "Remote Xcode build failed on Mac."
        case .connectionRefused:
            return "The Mac is reachable, but nothing is accepting connections on the configured port."
        case .timeout:
            return "The connection to the Mac timed out."
        case .portUnavailable:
            return "SwiftCode could not listen on the configured port because another application is using it."
        case .hostUnavailable:
            return "The target Mac host/IP address could not be reached."
        case .bonjourMismatch:
            return "The discovered SwiftCode service did not provide a valid connection endpoint."
        case .unknown:
            return "An unknown network error occurred."
        }
    }
}

public struct ConnectErrorPayload: Codable, Sendable {
    public let code: String
    public let message: String
    public let details: String?

    public init(code: String, message: String, details: String? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

// MARK: - Handshake & Pairing Payloads

public struct ConnectPairingRequestPayload: Codable, Sendable {
    public let deviceID: String
    public let deviceName: String
    public let deviceModel: String
    public let clientVersion: String
    public let publicKeyPem: String
    public let verificationCode: String

    public init(
        deviceID: String,
        deviceName: String,
        deviceModel: String = "iPhone",
        clientVersion: String = "1.0",
        publicKeyPem: String = "",
        verificationCode: String
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.clientVersion = clientVersion
        self.publicKeyPem = publicKeyPem
        self.verificationCode = verificationCode
    }
}

public struct ConnectPairingResponsePayload: Codable, Sendable {
    public let approved: Bool
    public let macName: String
    public let sessionToken: String?
    public let verificationCode: String?
    public let capabilities: [ConnectCapability]
    public let grantedPermissions: [ConnectPermission]

    public init(
        approved: Bool,
        macName: String,
        sessionToken: String?,
        verificationCode: String?,
        capabilities: [ConnectCapability] = [],
        grantedPermissions: [ConnectPermission] = []
    ) {
        self.approved = approved
        self.macName = macName
        self.sessionToken = sessionToken
        self.verificationCode = verificationCode
        self.capabilities = capabilities
        self.grantedPermissions = grantedPermissions
    }
}

public struct ConnectAuthRequestPayload: Codable, Sendable {
    public let deviceID: String
    public let sessionToken: String

    public init(deviceID: String, sessionToken: String) {
        self.deviceID = deviceID
        self.sessionToken = sessionToken
    }
}

public struct ConnectAuthResponsePayload: Codable, Sendable {
    public let authenticated: Bool
    public let sessionID: String?
    public let serverVersion: String
    public let capabilities: [ConnectCapability]
    public let permissions: [ConnectPermission]

    public init(
        authenticated: Bool,
        sessionID: String?,
        serverVersion: String = "1.0",
        capabilities: [ConnectCapability] = [],
        permissions: [ConnectPermission] = []
    ) {
        self.authenticated = authenticated
        self.sessionID = sessionID
        self.serverVersion = serverVersion
        self.capabilities = capabilities
        self.permissions = permissions
    }
}

// MARK: - Project & Git Payloads

public struct ConnectProjectInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let activeScheme: String?
    public let activeTarget: String?
    public let destinations: [String]
    public let swiftVersion: String?

    public init(
        id: String,
        name: String,
        path: String,
        activeScheme: String? = nil,
        activeTarget: String? = nil,
        destinations: [String] = [],
        swiftVersion: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.activeScheme = activeScheme
        self.activeTarget = activeTarget
        self.destinations = destinations
        self.swiftVersion = swiftVersion
    }
}

public struct ConnectProjectResponsePayload: Codable, Sendable {
    public let activeProject: ConnectProjectInfo?
    public let availableProjects: [ConnectProjectInfo]

    public init(activeProject: ConnectProjectInfo?, availableProjects: [ConnectProjectInfo] = []) {
        self.activeProject = activeProject
        self.availableProjects = availableProjects
    }
}

public struct ConnectGitStatusResponsePayload: Codable, Sendable {
    public let branch: String
    public let isClean: Bool
    public let ahead: Int
    public let behind: Int
    public let modifiedFiles: [String]
    public let stagedFiles: [String]
    public let untrackedFiles: [String]

    public init(
        branch: String,
        isClean: Bool,
        ahead: Int,
        behind: Int,
        modifiedFiles: [String] = [],
        stagedFiles: [String] = [],
        untrackedFiles: [String] = []
    ) {
        self.branch = branch
        self.isClean = isClean
        self.ahead = ahead
        self.behind = behind
        self.modifiedFiles = modifiedFiles
        self.stagedFiles = stagedFiles
        self.untrackedFiles = untrackedFiles
    }
}

/// Unified representation of project & git state for UI views
public struct RemoteProjectStatePayload: Codable, Equatable, Sendable {
    public let projectName: String
    public let projectPath: String
    public let activeScheme: String
    public let activeTarget: String
    public let activeBranch: String
    public let isGitDirty: Bool
    public let aheadCount: Int
    public let behindCount: Int
    public let totalFileCount: Int

    public init(
        projectName: String,
        projectPath: String,
        activeScheme: String,
        activeTarget: String,
        activeBranch: String,
        isGitDirty: Bool,
        aheadCount: Int,
        behindCount: Int,
        totalFileCount: Int = 0
    ) {
        self.projectName = projectName
        self.projectPath = projectPath
        self.activeScheme = activeScheme
        self.activeTarget = activeTarget
        self.activeBranch = activeBranch
        self.isGitDirty = isGitDirty
        self.aheadCount = aheadCount
        self.behindCount = behindCount
        self.totalFileCount = totalFileCount
    }
}

// MARK: - Build & Test Payloads

public struct ConnectBuildRequestPayload: Codable, Sendable {
    public let projectID: String?
    public let scheme: String?
    public let configuration: String?
    public let destinationSDK: String?

    public init(
        projectID: String? = nil,
        scheme: String? = nil,
        configuration: String? = "Debug",
        destinationSDK: String? = nil
    ) {
        self.projectID = projectID
        self.scheme = scheme
        self.configuration = configuration
        self.destinationSDK = destinationSDK
    }
}

public struct RemoteBuildRequestPayload: Codable, Sendable {
    public let projectPath: String
    public let scheme: String
    public let configuration: String
    public let cleanBuild: Bool

    public init(
        projectPath: String,
        scheme: String,
        configuration: String = "Debug",
        cleanBuild: Bool = false
    ) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.configuration = configuration
        self.cleanBuild = cleanBuild
    }
}

public enum RemoteBuildState: String, Codable, Sendable {
    case preparing
    case building
    case succeeded
    case failed
    case cancelled
}

public struct ConnectBuildProgressPayload: Codable, Sendable {
    public let phase: String
    public let completedSteps: Int
    public let totalSteps: Int
    public let message: String

    public init(phase: String, completedSteps: Int, totalSteps: Int, message: String) {
        self.phase = phase
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
        self.message = message
    }
}

public struct RemoteBuildProgressPayload: Codable, Identifiable, Sendable {
    public var id: String { buildID.uuidString }
    public let buildID: UUID
    public let state: RemoteBuildState
    public let progressFraction: Double
    public let currentTaskName: String
    public let elapsedTimeSeconds: Double
    public let errorCount: Int
    public let warningCount: Int

    public init(
        buildID: UUID = UUID(),
        state: RemoteBuildState,
        progressFraction: Double,
        currentTaskName: String,
        elapsedTimeSeconds: Double,
        errorCount: Int,
        warningCount: Int
    ) {
        self.buildID = buildID
        self.state = state
        self.progressFraction = progressFraction
        self.currentTaskName = currentTaskName
        self.elapsedTimeSeconds = elapsedTimeSeconds
        self.errorCount = errorCount
        self.warningCount = warningCount
    }
}

public enum DiagnosticSeverity: String, Codable, CaseIterable, Sendable {
    case error
    case warning
    case note
}

public struct ConnectBuildDiagnosticPayload: Codable, Sendable {
    public let severity: String
    public let message: String
    public let file: String?
    public let line: Int?
    public let column: Int?

    public init(severity: String, message: String, file: String? = nil, line: Int? = nil, column: Int? = nil) {
        self.severity = severity
        self.message = message
        self.file = file
        self.line = line
        self.column = column
    }
}

public struct RemoteBuildDiagnosticPayload: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let severity: DiagnosticSeverity
    public let message: String
    public let filePath: String?
    public let line: Int?
    public let column: Int?
    public let source: String?
    public let code: String?

    public init(
        id: UUID = UUID(),
        severity: DiagnosticSeverity,
        message: String,
        filePath: String? = nil,
        line: Int? = nil,
        column: Int? = nil,
        source: String? = nil,
        code: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.filePath = filePath
        self.line = line
        self.column = column
        self.source = source
        self.code = code
    }
}

public struct ConnectBuildCompletedPayload: Codable, Sendable {
    public let success: Bool
    public let duration: Double
    public let errorCount: Int
    public let warningCount: Int

    public init(success: Bool, duration: Double, errorCount: Int, warningCount: Int) {
        self.success = success
        self.duration = duration
        self.errorCount = errorCount
        self.warningCount = warningCount
    }
}

// MARK: - Log Streaming Payloads

public enum LogLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case debug
    case info
    case warning
    case error
    case fault

    private var rank: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .fault: return 4
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct ConnectLogEventPayload: Codable, Sendable {
    public let timestamp: Date
    public let level: String
    public let category: String
    public let message: String

    public init(timestamp: Date = Date(), level: String, category: String, message: String) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }
}

public struct RemoteLogEntryPayload: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let source: String
    public let category: String
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        source: String = "Mac",
        category: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.source = source
        self.category = category
        self.message = message
    }
}

public struct LogStreamSubscriptionPayload: Codable, Sendable {
    public let isEnabled: Bool
    public let minimumLogLevel: LogLevel
    public let categoryFilter: String?

    public init(isEnabled: Bool, minimumLogLevel: LogLevel = .info, categoryFilter: String? = nil) {
        self.isEnabled = isEnabled
        self.minimumLogLevel = minimumLogLevel
        self.categoryFilter = categoryFilter
    }
}

// MARK: - Device Info Payloads

public struct ConnectDeviceItem: Codable, Sendable {
    public let id: String
    public let name: String
    public let model: String
    public let platform: String
    public let osVersion: String
    public let isConnected: Bool

    public init(id: String, name: String, model: String, platform: String, osVersion: String, isConnected: Bool) {
        self.id = id
        self.name = name
        self.model = model
        self.platform = platform
        self.osVersion = osVersion
        self.isConnected = isConnected
    }
}

public struct ConnectDeviceListResponsePayload: Codable, Sendable {
    public let devices: [ConnectDeviceItem]

    public init(devices: [ConnectDeviceItem]) {
        self.devices = devices
    }
}

public struct RemoteDeviceStatePayload: Codable, Equatable, Sendable {
    public let macName: String
    public let modelName: String
    public let osVersion: String
    public let cpuUsagePercentage: Double
    public let memoryUsagePercentage: Double
    public let availableDiskSpaceGB: Double

    public init(
        macName: String,
        modelName: String,
        osVersion: String,
        cpuUsagePercentage: Double,
        memoryUsagePercentage: Double,
        availableDiskSpaceGB: Double
    ) {
        self.macName = macName
        self.modelName = modelName
        self.osVersion = osVersion
        self.cpuUsagePercentage = cpuUsagePercentage
        self.memoryUsagePercentage = memoryUsagePercentage
        self.availableDiskSpaceGB = availableDiskSpaceGB
    }
}

// MARK: - Assist Payloads

public struct ConnectAssistQueryRequestPayload: Codable, Sendable {
    public let prompt: String
    public let contextFiles: [String]?

    public init(prompt: String, contextFiles: [String]? = nil) {
        self.prompt = prompt
        self.contextFiles = contextFiles
    }
}

public struct ConnectAssistResponsePayload: Codable, Sendable {
    public let answer: String
    public let suggestedActions: [String]?

    public init(answer: String, suggestedActions: [String]? = nil) {
        self.answer = answer
        self.suggestedActions = suggestedActions
    }
}

public struct AssistContextRequestPayload: Codable, Sendable {
    public let userQuery: String
    public let projectPath: String?
    public let includeDiagnostics: Bool
    public let includeRecentLogs: Bool

    public init(userQuery: String, projectPath: String? = nil, includeDiagnostics: Bool = true, includeRecentLogs: Bool = true) {
        self.userQuery = userQuery
        self.projectPath = projectPath
        self.includeDiagnostics = includeDiagnostics
        self.includeRecentLogs = includeRecentLogs
    }
}

public struct AssistContextResponsePayload: Codable, Sendable {
    public let projectSummary: String
    public let activeBranch: String
    public let recentDiagnostics: [RemoteBuildDiagnosticPayload]
    public let recentLogEntries: [RemoteLogEntryPayload]
    public let contextSnippet: String?

    public init(
        projectSummary: String,
        activeBranch: String,
        recentDiagnostics: [RemoteBuildDiagnosticPayload] = [],
        recentLogEntries: [RemoteLogEntryPayload] = [],
        contextSnippet: String? = nil
    ) {
        self.projectSummary = projectSummary
        self.activeBranch = activeBranch
        self.recentDiagnostics = recentDiagnostics
        self.recentLogEntries = recentLogEntries
        self.contextSnippet = contextSnippet
    }
}

// MARK: - Terminal Payloads

public struct ConnectTerminalExecuteRequestPayload: Codable, Sendable {
    public let command: String
    public let workingDirectory: String?

    public init(command: String, workingDirectory: String? = nil) {
        self.command = command
        self.workingDirectory = workingDirectory
    }
}

public struct ConnectTerminalOutputPayload: Codable, Sendable {
    public let output: String
    public let isError: Bool

    public init(output: String, isError: Bool = false) {
        self.output = output
        self.isError = isError
    }
}

public struct RemoteTerminalCommandPayload: Codable, Sendable {
    public let command: String
    public let workingDirectory: String?

    public init(command: String, workingDirectory: String? = nil) {
        self.command = command
        self.workingDirectory = workingDirectory
    }
}

public struct RemoteTerminalOutputPayload: Codable, Sendable {
    public let output: String
    public let isError: Bool
    public let exitCode: Int32?

    public init(output: String, isError: Bool = false, exitCode: Int32? = nil) {
        self.output = output
        self.isError = isError
        self.exitCode = exitCode
    }
}

// MARK: - File Payloads

public struct ConnectFileItem: Codable, Sendable {
    public let path: String
    public let name: String
    public let isDirectory: Bool
    public let size: Int64?

    public init(path: String, name: String, isDirectory: Bool, size: Int64? = nil) {
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
    }
}

public struct ConnectFileListResponsePayload: Codable, Sendable {
    public let files: [ConnectFileItem]

    public init(files: [ConnectFileItem]) {
        self.files = files
    }
}

public struct ConnectTestCompletedPayload: Codable, Sendable {
    public let success: Bool
    public let message: String

    public init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
}
