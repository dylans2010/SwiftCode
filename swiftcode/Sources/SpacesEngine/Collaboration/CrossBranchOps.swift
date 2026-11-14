import Foundation

public struct CrossBranchOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct Tracking: Codable, Sendable {
        public var changeId: String
        public var branches: [String]

        public init(changeId: String, branches: [String]) {
            self.changeId = changeId
            self.branches = branches
        }
    }

    public enum Status: String, Codable, Sendable, Equatable {
        case reached
        case pending
    }

    public struct BranchStatus: Sendable {
        public var branch: String
        public var status: Status
        public var headRev: String

        public init(branch: String, status: Status, headRev: String) {
            self.branch = branch
            self.status = status
            self.headRev = headRev
        }
    }

    private var trackingDirectory: URL {
        repo.metaURL.appendingPathComponent("cross-branch")
    }

    private func url(for changeId: String) -> URL {
        trackingDirectory.appendingPathComponent("\(changeId).json")
    }

    public static func fileName(for changeId: String) -> String? {
        guard !changeId.isEmpty, !changeId.contains("/"),
              !changeId.contains("..") else { return nil }
        return changeId
    }

    @discardableResult
    public func trackChangeAcrossBranches(changeId: String,
                                          branches: [String]) throws -> Tracking {
        let trimmed = changeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.fileName(for: trimmed) != nil else {
            throw SpacesError.invalidArgument("invalid change id \(changeId)")
        }
        _ = try repo.resolveRevision(trimmed)
        var unique: [String] = []
        for branch in branches where !branch.isEmpty && !unique.contains(branch) {
            unique.append(branch)
        }
        guard !unique.isEmpty else {
            throw SpacesError.invalidArgument("tracking requires at least one branch")
        }
        let tracking = Tracking(changeId: trimmed, branches: unique)
        try repo.performTransaction(steps: ["cross-branch-track:\(trimmed)"]) {
            try CollaborationStore.save(tracking, to: url(for: trimmed))
        }
        return tracking
    }

    public func tracking(changeId: String) throws -> Tracking {
        try CollaborationStore.loadRequired(url(for: changeId),
                                           label: "cross-branch tracking \(changeId)")
    }

    public func crossBranchStatus(changeId: String) throws -> [BranchStatus] {
        let stored = try tracking(changeId: changeId)
        let changeOID = try repo.resolveRevision(stored.changeId)
        var result: [BranchStatus] = []
        for branch in stored.branches {
            guard let headOID = try repo.refs.readRef("refs/heads/\(branch)") else {
                throw SpacesError.branchNotFound(branch)
            }
            let reached = try isAncestor(changeOID, of: headOID)
            result.append(BranchStatus(branch: branch,
                                       status: reached ? .reached : .pending,
                                       headRev: headOID.hex))
        }
        return result
    }

    private func isAncestor(_ ancestor: ObjectID, of descendant: ObjectID) throws -> Bool {
        var visited = Set<ObjectID>()
        var queue = [descendant]
        while !queue.isEmpty {
            let oid = queue.removeFirst()
            if oid == ancestor { return true }
            guard visited.insert(oid).inserted else { continue }
            queue.append(contentsOf: try repo.commitObject(oid).parents)
        }
        return false
    }
}
