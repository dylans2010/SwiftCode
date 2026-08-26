import Foundation

// MARK: - Protocol Constants & Versioning

public enum ConnectProtocolVersion {
    public static let current = "1.0.0"
    public static let serviceType = "_swiftcodeconnect._tcp"
    public static let domain = "local."
    public static let defaultPort: UInt16 = 9480
}

// MARK: - Message Types

public enum ConnectMessageType: String, Codable, CaseIterable {
    // Pairing & Auth Handshake
    case pairRequest = "pair_request"
    case pairResponse = "pair_response"
    case authRequest = "auth_request"
    case authResponse = "auth_response"

    // Session Management & Heartbeat
    case ping = "ping"
    case pong = "pong"
    case disconnect = "disconnect"
    case error = "error"

    // Project Information & Git State
    case getProjectState = "get_project_state"
    case projectStateUpdate = "project_state_update"

    // Remote Build System
    case buildStart = "build_start"
    case buildCancel = "build_cancel"
    case buildProgress = "build_progress"
    case buildCompleted = "build_completed"
    case buildDiagnostic = "build_diagnostic"

    // Streaming Logs
    case logStreamSubscribe = "log_stream_subscribe"
    case logStreamUnsubscribe = "log_stream_unsubscribe"
    case logEntry = "log_entry"

    // Assist Remote Integration
    case assistContextRequest = "assist_context_request"
    case assistContextResponse = "assist_context_response"

    // Mac Device Info
    case getDeviceInfo = "get_device_info"
    case deviceInfoResponse = "device_info_response"

    // Permissions System
    case permissionRequest = "permission_request"
    case permissionResponse = "permission_response"

    // Terminal Protocol Architecture
    case terminalCommand = "terminal_command"
    case terminalOutput = "terminal_output"
}

// MARK: - Typed Message Envelope

public struct ConnectMessageEnvelope: Codable, Identifiable {
    public let id: UUID
    public let protocolVersion: String
    public let type: ConnectMessageType
    public let correlationID: UUID?
    public let timestamp: Date
    public let payloadData: Data?

    public init(
        id: UUID = UUID(),
        protocolVersion: String = ConnectProtocolVersion.current,
        type: ConnectMessageType,
        correlationID: UUID? = nil,
        timestamp: Date = Date(),
        payloadData: Data? = nil
    ) {
        self.id = id
        self.protocolVersion = protocolVersion
        self.type = type
        self.correlationID = correlationID
        self.timestamp = timestamp
        self.payloadData = payloadData
    }

    public func decodePayload<T: Codable>(_ type: T.Type) throws -> T {
        guard let data = payloadData else {
            throw ConnectProtocolError.missingPayload
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    public static func makeEnvelope<T: Codable>(
        type: ConnectMessageType,
        correlationID: UUID? = nil,
        payload: T
    ) throws -> ConnectMessageEnvelope {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        return ConnectMessageEnvelope(
            type: type,
            correlationID: correlationID,
            payloadData: data
        )
    }
}

// MARK: - Protocol Errors

public enum ConnectProtocolError: String, Error, Codable, LocalizedError {
    case missingPayload = "missing_payload"
    case invalidPayload = "invalid_payload"
    case authenticationFailed = "authentication_failed"
    case pairingRejected = "pairing_rejected"
    case protocolMismatch = "protocol_mismatch"
    case permissionDenied = "permission_denied"
    case deviceUnavailable = "device_unavailable"
    case buildFailed = "build_failed"
    case timeout = "timeout"
    case unknown = "unknown"

    public var errorDescription: String? {
        switch self {
        case .missingPayload: return "Message payload is missing."
        case .invalidPayload: return "Message payload could not be decoded."
        case .authenticationFailed: return "Authentication failed. Invalid auth token."
        case .pairingRejected: return "Pairing request was rejected by the Mac."
        case .protocolMismatch: return "Incompatible SwiftCode Connect protocol version."
        case .permissionDenied: return "Permission for this operation was denied."
        case .deviceUnavailable: return "The Mac device is unavailable or offline."
        case .buildFailed: return "Remote build failed on Mac."
        case .timeout: return "Operation timed out."
        case .unknown: return "An unknown error occurred."
        }
    }
}

public struct ConnectErrorPayload: Codable {
    public let errorCode: String
    public let message: String
    public let details: String?

    public init(errorCode: String, message: String, details: String? = nil) {
        self.errorCode = errorCode
        self.message = message
        self.details = details
    }
}

// MARK: - Payload Models

// MARK: Pairing & Auth Payload
public struct PairingHandshakeRequest: Codable {
    public let deviceID: String
    public let deviceName: String
    public let pairingCode: String

    public init(deviceID: String, deviceName: String, pairingCode: String) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.pairingCode = pairingCode
    }
}

public struct PairingHandshakeResponse: Codable {
    public let isSuccess: Bool
    public let macID: String
    public let macName: String
    public let authToken: String?
    public let errorMessage: String?

    public init(isSuccess: Bool, macID: String, macName: String, authToken: String? = nil, errorMessage: String? = nil) {
        self.isSuccess = isSuccess
        self.macID = macID
        self.macName = macName
        self.authToken = authToken
        self.errorMessage = errorMessage
    }
}

public struct AuthTokenPayload: Codable {
    public let deviceID: String
    public let authToken: String
    public let clientVersion: String

    public init(deviceID: String, authToken: String, clientVersion: String = ConnectProtocolVersion.current) {
        self.deviceID = deviceID
        self.authToken = authToken
        self.clientVersion = clientVersion
    }
}

// MARK: Project State Payload
public struct RemoteProjectStatePayload: Codable, Equatable {
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
        totalFileCount: Int
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

// MARK: Remote Build Payload
public struct RemoteBuildRequestPayload: Codable {
    public let projectPath: String
    public let scheme: String
    public let configuration: String
    public let cleanBuild: Bool

    public init(projectPath: String, scheme: String, configuration: String = "Debug", cleanBuild: Bool = false) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.configuration = configuration
        self.cleanBuild = cleanBuild
    }
}

public enum RemoteBuildState: String, Codable {
    case preparing
    case building
    case succeeded
    case failed
    case cancelled
}

public struct RemoteBuildProgressPayload: Codable, Identifiable {
    public var id: String { buildID.uuidString }
    public let buildID: UUID
    public let state: RemoteBuildState
    public let progressFraction: Double
    public let currentTaskName: String
    public let elapsedTimeSeconds: Double
    public let errorCount: Int
    public let warningCount: Int

    public init(
        buildID: UUID,
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

public enum DiagnosticSeverity: String, Codable, CaseIterable {
    case error
    case warning
    case note
}

public struct RemoteBuildDiagnosticPayload: Codable, Identifiable, Equatable {
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

// MARK: Log Streaming Payload
public enum LogLevel: String, Codable, CaseIterable, Comparable {
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

public struct RemoteLogEntryPayload: Codable, Identifiable, Equatable {
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
        source: String,
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

public struct LogStreamSubscriptionPayload: Codable {
    public let isEnabled: Bool
    public let minimumLogLevel: LogLevel
    public let categoryFilter: String?

    public init(isEnabled: Bool, minimumLogLevel: LogLevel = .info, categoryFilter: String? = nil) {
        self.isEnabled = isEnabled
        self.minimumLogLevel = minimumLogLevel
        self.categoryFilter = categoryFilter
    }
}

// MARK: Assist Integration Payload
public struct AssistContextRequestPayload: Codable {
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

public struct AssistContextResponsePayload: Codable {
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

// MARK: Device Info Payload
public struct RemoteDeviceStatePayload: Codable, Equatable {
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

// MARK: Permissions Payload
public struct RemotePermissionRequestPayload: Codable {
    public let permissionID: String
    public let reason: String

    public init(permissionID: String, reason: String) {
        self.permissionID = permissionID
        self.reason = reason
    }
}

public struct RemotePermissionResponsePayload: Codable {
    public let permissionID: String
    public let isGranted: Bool

    public init(permissionID: String, isGranted: Bool) {
        self.permissionID = permissionID
        self.isGranted = isGranted
    }
}

// MARK: Terminal Payload
public struct RemoteTerminalCommandPayload: Codable {
    public let command: String
    public let workingDirectory: String?

    public init(command: String, workingDirectory: String? = nil) {
        self.command = command
        self.workingDirectory = workingDirectory
    }
}

public struct RemoteTerminalOutputPayload: Codable {
    public let output: String
    public let isError: Bool
    public let exitCode: Int32?

    public init(output: String, isError: Bool = false, exitCode: Int32? = nil) {
        self.output = output
        self.isError = isError
        self.exitCode = exitCode
    }
}
