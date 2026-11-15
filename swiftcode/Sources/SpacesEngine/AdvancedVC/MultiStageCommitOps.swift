import Foundation

public struct MultiStageCommitOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum Stage: String, Sendable, Codable {
        case prepared, validated, previewed
    }

    public struct StageRecord: Sendable, Codable {
        public var tx: String
        public var stage: Stage
        public var message: String
        public var paths: [String]
        public var created: Int64
        public var violations: [ValidationPolicyOps.PolicyViolation]
        public var stagedOIDs: [String: String]

        public init(tx: String, stage: Stage, message: String, paths: [String],
                    created: Int64, violations: [ValidationPolicyOps.PolicyViolation],
                    stagedOIDs: [String: String] = [:]) {
            self.tx = tx
            self.stage = stage
            self.message = message
            self.paths = paths
            self.created = created
            self.violations = violations
            self.stagedOIDs = stagedOIDs
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tx = try container.decode(String.self, forKey: .tx)
            stage = try container.decode(Stage.self, forKey: .stage)
            message = try container.decode(String.self, forKey: .message)
            paths = try container.decode([String].self, forKey: .paths)
            created = try container.decode(Int64.self, forKey: .created)
            violations = try container.decode([ValidationPolicyOps.PolicyViolation].self, forKey: .violations)
            stagedOIDs = try container.decodeIfPresent([String: String].self, forKey: .stagedOIDs) ?? [:]
        }

        private enum CodingKeys: String, CodingKey {
            case tx, stage, message, paths, created, violations, stagedOIDs
        }
    }

    public struct StagePreview: Sendable, Codable {
        public var tx: String
        public var paths: [String]
        public var files: Int
        public var added: Int
        public var removed: Int
        public var patch: String
    }

    private var stagingDir: URL {
        repo.metaURL.appendingPathComponent("staging")
    }

    private func fileURL(tx: String) -> URL {
        stagingDir.appendingPathComponent("\(tx).json")
    }

    private func load(tx: String) throws -> StageRecord {
        guard let record: StageRecord = try AdvancedVCStore.readJSON(StageRecord.self, from: fileURL(tx: tx)) else {
            throw SpacesError.invalidArgument("no staged commit \(tx)")
        }
        return record
    }

    private func save(_ record: StageRecord) throws {
        try AdvancedVCStore.writeJSON(record, to: fileURL(tx: record.tx))
    }

    @discardableResult
    public func prepare(message: String, paths: [String]) throws -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SpacesError.invalidArgument("commit message must not be empty")
        }
        guard !paths.isEmpty else {
            throw SpacesError.invalidArgument("at least one path is required")
        }
        for path in paths {
            let url = try repo.worktreeURL(forRelativePath: path)
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            let tracked = (try? repo.trackedPaths().contains(path)) ?? false
            guard exists || tracked else {
                throw SpacesError.pathNotFound(path)
            }
        }
        let tx = UUID().uuidString
        var staged: [String] = []
        for path in paths {
            staged.append(contentsOf: try StagingOps(repo: repo).add(path))
        }
        let index = try repo.index()
        var stagedOIDs: [String: String] = [:]
        for path in staged {
            if let entry = index.entries[path] {
                stagedOIDs[path] = entry.oid.hex
            }
        }
        let record = StageRecord(tx: tx, stage: .prepared, message: trimmed,
                                 paths: staged.sorted(), created: AdvancedVCStore.now(), violations: [],
                                 stagedOIDs: stagedOIDs)
        return try repo.withLock {
            try save(record)
            return tx
        }
    }

    @discardableResult
    public func validate(tx: String) throws -> [ValidationPolicyOps.PolicyViolation] {
        var record = try load(tx: tx)
        let violations = try ValidationPolicyOps(repo: repo).validateCommit(message: record.message, stagedPaths: record.paths)
        record.violations = violations
        if violations.isEmpty {
            record.stage = .validated
        }
        return try repo.withLock {
            try save(record)
            return violations
        }
    }

    @discardableResult
    public func preview(tx: String) throws -> StagePreview {
        var record = try load(tx: tx)
        let diffs = try DiffOps(repo: repo).workingDiff(stagedOnly: true)
        let wanted = Set(record.paths)
        let matched = diffs.filter { wanted.contains($0.newPath) || wanted.contains($0.oldPath) }
        let preview = StagePreview(tx: tx, paths: record.paths, files: matched.count,
                                   added: matched.reduce(0) { $0 + $1.added },
                                   removed: matched.reduce(0) { $0 + $1.removed },
                                   patch: DiffOps.renderPatch(matched))
        record.stage = .previewed
        try repo.withLock {
            try save(record)
        }
        return preview
    }

    @discardableResult
    public func finalize(tx: String) throws -> ObjectID {
        let record = try load(tx: tx)
        guard record.stage == .validated || record.stage == .previewed else {
            throw SpacesError.invalidArgument("staged commit \(tx) must be validated and previewed before finalize")
        }
        let violations = try ValidationPolicyOps(repo: repo).validateCommit(message: record.message, stagedPaths: record.paths)
        guard violations.isEmpty else {
            throw SpacesError.invalidArgument("staged commit \(tx) fails validation: \(violations.map { $0.message }.joined(separator: "; "))")
        }
        repo.markIndexDirty()
        let index = try repo.index()
        for path in record.paths {
            let current = index.entries[path]?.oid.hex
            let recorded = record.stagedOIDs[path]
            guard current == recorded else {
                throw SpacesError.invalidArgument(
                    "staged content for '\(path)' changed since prepare; re-prepare staged commit \(tx)")
            }
        }
        let result = try StagingOps(repo: repo).commit(message: record.message, onlyPaths: record.paths)
        try repo.withLock {
            try? FileManager.default.removeItem(at: fileURL(tx: tx))
        }
        return result.oid
    }

    public func abort(tx: String) throws {
        let record = try load(tx: tx)
        for path in record.paths {
            try? StagingOps(repo: repo).unstage(path)
        }
        try repo.withLock {
            try? FileManager.default.removeItem(at: fileURL(tx: tx))
        }
    }
}
