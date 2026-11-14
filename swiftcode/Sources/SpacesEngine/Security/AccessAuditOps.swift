import Foundation

public struct AccessAuditOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let auditRelativePath = "security/audit.jsonl"

    public struct AuditEvent: Codable, Sendable {
        public var timestamp: Int64
        public var actor: String
        public var operation: String
        public var details: String
        public var result: String

        public init(timestamp: Int64, actor: String, operation: String, details: String, result: String) {
            self.timestamp = timestamp
            self.actor = actor
            self.operation = operation
            self.details = details
            self.result = result
        }
    }

    public func recordAuditEvent(operation: String, details: String, result: String) throws {
        let identity = repo.identity()
        let event = AuditEvent(
            timestamp: Int64(Date().timeIntervalSince1970),
            actor: "\(identity.name) <\(identity.email)>",
            operation: operation,
            details: details,
            result: result)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let line = String(decoding: try encoder.encode(event), as: UTF8.self)
        try repo.withLock {
            try SecurityFileStore.appendLine(repo: repo, relativePath: Self.auditRelativePath, line: line)
        }
    }

    public func auditEvents(limit: Int = 100) throws -> [AuditEvent] {
        let lines = SecurityFileStore.readLines(repo: repo, relativePath: Self.auditRelativePath)
        let decoder = JSONDecoder()
        var events: [AuditEvent] = []
        for line in lines.reversed() {
            guard let event = try? decoder.decode(AuditEvent.self, from: Data(line.utf8)) else { continue }
            events.append(event)
            if events.count >= limit { break }
        }
        return events
    }
}
