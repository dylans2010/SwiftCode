import Foundation

public struct CommitGraphOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum DependencyKind: String, Sendable, Codable, CaseIterable {
        case dependsOn = "depends-on"
        case relatesTo = "relates-to"
        case supersedes
    }

    public struct Dependency: Sendable, Codable {
        public var from: ObjectID
        public var to: ObjectID
        public var kind: DependencyKind
        public var created: Int64
    }

    private struct GraphFile: Codable {
        var deps: [Dependency]
    }

    private var graphURL: URL {
        repo.metaURL.appendingPathComponent("commit-graph.json")
    }

    private func load() throws -> [Dependency] {
        guard let file: GraphFile = try AdvancedVCStore.readJSON(GraphFile.self, from: graphURL) else {
            return []
        }
        return file.deps
    }

    private func save(_ deps: [Dependency]) throws {
        try AdvancedVCStore.writeJSON(GraphFile(deps: deps), to: graphURL)
    }

    @discardableResult
    public func addDependency(from: String, to: String, kind: DependencyKind) throws -> Dependency {
        let fromOID = try repo.resolveRevision(from)
        let toOID = try repo.resolveRevision(to)
        _ = try repo.commitObject(fromOID)
        _ = try repo.commitObject(toOID)
        guard fromOID != toOID else {
            throw SpacesError.invalidArgument("a commit cannot depend on itself")
        }
        return try repo.withLock {
            var deps = try load()
            if deps.contains(where: { $0.from == fromOID && $0.to == toOID && $0.kind == kind }) {
                throw SpacesError.invalidArgument("dependency already recorded")
            }
            let record = Dependency(from: fromOID, to: toOID, kind: kind, created: AdvancedVCStore.now())
            deps.append(record)
            try save(deps)
            return record
        }
    }

    public func dependencies(of rev: String) throws -> [Dependency] {
        let oid = try repo.resolveRevision(rev)
        return try load().filter { $0.from == oid }.sorted { $0.created < $1.created }
    }

    public func dependents(of rev: String) throws -> [Dependency] {
        let oid = try repo.resolveRevision(rev)
        return try load().filter { $0.to == oid }.sorted { $0.created < $1.created }
    }

    public func allDependencies() throws -> [Dependency] {
        try load().sorted { $0.created < $1.created }
    }
}
