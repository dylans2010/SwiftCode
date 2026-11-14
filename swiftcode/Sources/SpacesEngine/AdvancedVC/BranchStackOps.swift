import Foundation

public struct BranchStackOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct StackRecord: Sendable, Codable {
        public var name: String
        public var branches: [String]
        public var base: String
        public var created: Int64
    }

    public struct BranchStackStatus: Sendable, Codable {
        public var branch: String
        public var parent: String
        public var oid: ObjectID
        public var ahead: Int
        public var behind: Int
    }

    public struct StackStatus: Sendable, Codable {
        public var name: String
        public var base: String
        public var branches: [BranchStackStatus]
    }

    private var stacksDir: URL {
        repo.metaURL.appendingPathComponent("stacks")
    }

    private func fileURL(name: String) -> URL {
        stacksDir.appendingPathComponent("\(name).json")
    }

    private func validateBranches(_ branches: [String]) throws {
        guard !branches.isEmpty else {
            throw SpacesError.invalidArgument("a stack needs at least one branch")
        }
        for branch in branches {
            guard try repo.refs.readRef("refs/heads/\(branch)") != nil else {
                throw SpacesError.branchNotFound(branch)
            }
        }
    }

    @discardableResult
    public func createStack(name: String, branches: [String], base: String) throws -> StackRecord {
        try AdvancedVCStore.requireNameComponent(name)
        try validateBranches(branches)
        guard try repo.refs.readRef("refs/heads/\(base)") != nil else {
            throw SpacesError.branchNotFound(base)
        }
        let url = fileURL(name: name)
        if FileManager.default.fileExists(atPath: url.path) {
            throw SpacesError.invalidArgument("stack already exists: \(name)")
        }
        let record = StackRecord(name: name, branches: branches, base: base, created: AdvancedVCStore.now())
        return try repo.withLock {
            try AdvancedVCStore.writeJSON(record, to: url)
            return record
        }
    }

    public func stacks() throws -> [StackRecord] {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: stacksDir.path) else {
            return []
        }
        var result: [StackRecord] = []
        for file in files where file.hasSuffix(".json") {
            if let record: StackRecord = try? AdvancedVCStore.readJSON(StackRecord.self, from: stacksDir.appendingPathComponent(file)) {
                result.append(record)
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    public func stack(_ name: String) throws -> StackRecord {
        try AdvancedVCStore.requireNameComponent(name)
        guard let record: StackRecord = try AdvancedVCStore.readJSON(StackRecord.self, from: fileURL(name: name)) else {
            throw SpacesError.invalidArgument("no stack named \(name)")
        }
        return record
    }

    public func stackStatus(name: String) throws -> StackStatus {
        let record = try stack(name)
        let scanner = WorktreeScanner(repo: repo)
        var statuses: [BranchStackStatus] = []
        for (index, branch) in record.branches.enumerated() {
            guard let oid = try repo.refs.readRef("refs/heads/\(branch)") else {
                throw SpacesError.branchNotFound(branch)
            }
            let parentName = index == 0 ? record.base : record.branches[index - 1]
            guard let parentOID = try repo.refs.readRef("refs/heads/\(parentName)") else {
                throw SpacesError.branchNotFound(parentName)
            }
            let counts = try scanner.countAheadBehind(head: oid, upstream: parentOID)
            statuses.append(BranchStackStatus(branch: branch, parent: parentName, oid: oid,
                                              ahead: counts.ahead, behind: counts.behind))
        }
        return StackStatus(name: record.name, base: record.base, branches: statuses)
    }

    @discardableResult
    public func updateStack(name: String, branches: [String]) throws -> StackRecord {
        try AdvancedVCStore.requireNameComponent(name)
        try validateBranches(branches)
        var record = try stack(name)
        record.branches = branches
        return try repo.withLock {
            try AdvancedVCStore.writeJSON(record, to: fileURL(name: name))
            return record
        }
    }
}
