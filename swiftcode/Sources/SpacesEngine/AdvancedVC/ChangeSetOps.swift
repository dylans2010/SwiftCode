import Foundation

public struct ChangeSetOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct ChangeSetRecord: Sendable, Codable {
        public var id: String
        public var name: String
        public var paths: [String]
        public var description: String
        public var created: Int64
    }

    private var setsDir: URL {
        repo.metaURL.appendingPathComponent("changesets")
    }

    private func fileURL(id: String) -> URL {
        setsDir.appendingPathComponent("\(id).json")
    }

    @discardableResult
    public func createChangeSet(name: String, description: String) throws -> ChangeSetRecord {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SpacesError.invalidArgument("change set name must not be empty")
        }
        let record = ChangeSetRecord(id: UUID().uuidString, name: trimmed, paths: [],
                                     description: description, created: AdvancedVCStore.now())
        return try repo.withLock {
            try AdvancedVCStore.writeJSON(record, to: fileURL(id: record.id))
            return record
        }
    }

    public func changeSets() throws -> [ChangeSetRecord] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: setsDir.path) else {
            return []
        }
        var result: [ChangeSetRecord] = []
        for file in files where file.hasSuffix(".json") {
            if let record: ChangeSetRecord = try? AdvancedVCStore.readJSON(ChangeSetRecord.self, from: setsDir.appendingPathComponent(file)) {
                result.append(record)
            }
        }
        return result.sorted { $0.created < $1.created }
    }

    public func changeSet(id: String) throws -> ChangeSetRecord {
        guard let record: ChangeSetRecord = try AdvancedVCStore.readJSON(ChangeSetRecord.self, from: fileURL(id: id)) else {
            throw SpacesError.invalidArgument("no change set \(id)")
        }
        return record
    }

    public func changeSetPaths(id: String) throws -> [String] {
        try changeSet(id: id).paths
    }

    @discardableResult
    public func addToChangeSet(id: String, path: String) throws -> ChangeSetRecord {
        var record = try changeSet(id: id)
        let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !normalized.hasPrefix("/"), !normalized.contains("..") else {
            throw SpacesError.pathOutsideRepository(path)
        }
        let url = try repo.worktreeURL(forRelativePath: normalized)
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let tracked = (try? repo.trackedPaths().contains(normalized)) ?? false
        guard exists || tracked else {
            throw SpacesError.pathNotFound(path)
        }
        if !record.paths.contains(normalized) {
            record.paths.append(normalized)
            record.paths.sort()
        }
        return try repo.withLock {
            try AdvancedVCStore.writeJSON(record, to: fileURL(id: id))
            return record
        }
    }

    @discardableResult
    public func stageChangeSet(id: String) throws -> [String] {
        let record = try changeSet(id: id)
        guard !record.paths.isEmpty else {
            throw SpacesError.invalidArgument("change set \(id) has no paths")
        }
        var staged: [String] = []
        for path in record.paths {
            staged.append(contentsOf: try StagingOps(repo: repo).add(path))
        }
        return staged.sorted()
    }
}
