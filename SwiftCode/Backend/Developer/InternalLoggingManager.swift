import Foundation
import Combine

public enum LogLevel: String, Codable, CaseIterable, Identifiable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    var id: String { self.rawValue }
}

public enum LogCategory: String, CaseIterable, Identifiable {
    case networking = "Networking"
    case githubAPI = "GitHub API"
    case deployments = "Deployments"
    case aiProcessing = "AI Processing"
    case storeKit = "StoreKit"
    case extensions = "Extensions"
    case buildSystem = "Build System"
    case general = "General"

    public var id: String { self.rawValue }
}

public struct LogEntry: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let category: LogCategory
    public let level: LogLevel
    public let message: String

    public init(timestamp: Date, category: LogCategory, level: LogLevel, message: String) {
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
    }
}

public struct NetworkRequestLog: Identifiable {
    public let id: UUID
    public let url: String
    public let method: String
    public var requestHeaders: [String: String]?
    public var requestBody: String?
    public var responseHeaders: [String: String]?
    public var responseBody: String?
    public var statusCode: Int?
    public var duration: TimeInterval?
    public let timestamp: Date

    public init(id: UUID = UUID(), url: String, method: String, requestHeaders: [String: String]? = nil, requestBody: String? = nil, timestamp: Date) {
        self.id = id
        self.url = url
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.timestamp = timestamp
    }
}

public final class InternalLoggingManager: ObservableObject {
    public static let shared = InternalLoggingManager()

    @Published public private(set) var logs: [LogEntry] = []
    @Published public private(set) var networkLogs: [NetworkRequestLog] = []

    private init() {}

    public func log(_ message: String, category: LogCategory, level: LogLevel = .info) {
        // Fallback if FeatureFlags is not yet updated or accessible
        // In real app we check FeatureFlags.shared.verbose_logging

        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: Date(), category: category, level: level, message: message)
            self.logs.append(entry)

            if self.logs.count > 1000 {
                self.logs.removeFirst()
            }
        }
    }

    public func logNetworkRequest(url: String, method: String, headers: [String: String]? = nil, body: String? = nil) -> UUID {
        let entry = NetworkRequestLog(url: url, method: method, requestHeaders: headers, requestBody: body, timestamp: Date())
        let id = entry.id
        DispatchQueue.main.async {
            self.networkLogs.append(entry)
            if self.networkLogs.count > 100 {
                self.networkLogs.removeFirst()
            }
        }
        return id
    }

    public func updateNetworkRequest(id: UUID, statusCode: Int, duration: TimeInterval, responseHeaders: [String: String]? = nil, responseBody: String? = nil) {
        DispatchQueue.main.async {
            if let index = self.networkLogs.firstIndex(where: { $0.id == id }) {
                self.networkLogs[index].statusCode = statusCode
                self.networkLogs[index].duration = duration
                self.networkLogs[index].responseHeaders = responseHeaders
                self.networkLogs[index].responseBody = responseBody
            }
        }
    }

    public func clearLogs() {
        logs = []
        networkLogs = []
    }

    public func exportLogs() -> String {
        logs.map { "[\($0.timestamp)] [\($0.level.rawValue)] [\($0.category.rawValue)] \($0.message)" }.joined(separator: "\n")
    }
}
