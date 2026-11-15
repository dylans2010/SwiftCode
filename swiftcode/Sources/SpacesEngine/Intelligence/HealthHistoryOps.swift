import Foundation

public struct HealthHistoryOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let scoreNote = "The health score is a heuristic: diagnostic severities are combined with fixed, arbitrary weights. It is not a measured reliability figure."

    public struct HealthSnapshot: Codable, Sendable {
        public var timestamp: Int64
        public var score: Int
        public var errors: Int
        public var warnings: Int
        public var okCount: Int
        public var scoreKind: String = "heuristic"
        public var scoreNote: String = HealthHistoryOps.scoreNote

        public init(timestamp: Int64, score: Int, errors: Int, warnings: Int, okCount: Int,
                    scoreKind: String = "heuristic",
                    scoreNote: String = HealthHistoryOps.scoreNote) {
            self.timestamp = timestamp
            self.score = score
            self.errors = errors
            self.warnings = warnings
            self.okCount = okCount
            self.scoreKind = scoreKind
            self.scoreNote = scoreNote
        }
    }

    private var historyURL: URL {
        get throws {
            try SpacesIntelligenceStore.intelligenceDirectory(repo: repo)
                .appendingPathComponent("health-history.jsonl")
        }
    }

    @discardableResult
    public func recordHealth() throws -> HealthSnapshot {
        try repo.withLock {
            let (score, _) = try MaintenanceOps(repo: repo).healthScore()
            let diagnostics = try MaintenanceOps(repo: repo).diagnose()
            let snapshot = HealthSnapshot(
                timestamp: Int64(Date().timeIntervalSince1970),
                score: score,
                errors: diagnostics.filter { $0.level == .error }.count,
                warnings: diagnostics.filter { $0.level == .warning }.count,
                okCount: diagnostics.filter { $0.level == .ok }.count,
                scoreKind: "heuristic",
                scoreNote: Self.scoreNote)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            var line = try encoder.encode(snapshot)
            line.append(contentsOf: [0x0A])
            try SpacesIntelligenceStore.appendLine(line, to: historyURL)
            return snapshot
        }
    }

    public func history(limit: Int = 100) throws -> [HealthSnapshot] {
        let url = try historyURL
        guard FileManager.default.fileExists(atPath: url.path),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        var snapshots: [HealthSnapshot] = []
        for line in text.components(separatedBy: "\n") where !line.isEmpty {
            guard let snapshot = try? JSONDecoder().decode(
                HealthSnapshot.self, from: Data(line.utf8)) else {
                throw SpacesError.ioError("cannot decode health history entry")
            }
            snapshots.append(snapshot)
        }
        return Array(snapshots.sorted { $0.timestamp > $1.timestamp }.prefix(max(0, limit)))
    }
}
