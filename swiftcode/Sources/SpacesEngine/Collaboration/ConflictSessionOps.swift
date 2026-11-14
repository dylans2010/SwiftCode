import Foundation

public struct ConflictSessionOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let synchronizationDescription = "Conflict sessions are stored as JSON files under .spaces/conflicts/sessions, so they live inside the repository, travel with it, and every collaborator reading the same worktree sees the same session, claims, and resolutions. The repository files are the synchronization mechanism."

    public struct Session: Codable, Sendable {
        public var id: String
        public var paths: [String]
        public var ownerByPath: [String: String]
        public var resolutionsByPath: [String: String]
        public var created: Int64

        public init(id: String, paths: [String],
                    ownerByPath: [String: String] = [:],
                    resolutionsByPath: [String: String] = [:],
                    created: Int64) {
            self.id = id
            self.paths = paths
            self.ownerByPath = ownerByPath
            self.resolutionsByPath = resolutionsByPath
            self.created = created
        }
    }

    public struct SessionStatus: Sendable {
        public var total: Int
        public var claimed: Int
        public var resolved: Int
        public var unclaimed: [String]
        public var unresolved: [String]

        public init(total: Int, claimed: Int, resolved: Int,
                    unclaimed: [String], unresolved: [String]) {
            self.total = total
            self.claimed = claimed
            self.resolved = resolved
            self.unclaimed = unclaimed
            self.unresolved = unresolved
        }
    }

    private var sessionsDirectory: URL {
        repo.metaURL.appendingPathComponent("conflicts")
            .appendingPathComponent("sessions")
    }

    private func url(for id: String) -> URL {
        sessionsDirectory.appendingPathComponent("\(id).json")
    }

    @discardableResult
    public func createSession(paths: [String]) throws -> Session {
        var unique: [String] = []
        for path in paths where !path.isEmpty && !unique.contains(path) {
            unique.append(path)
        }
        guard !unique.isEmpty else {
            throw SpacesError.invalidArgument("conflict session requires at least one path")
        }
        let session = Session(id: UUID().uuidString, paths: unique,
                              created: CollaborationStore.now())
        try repo.performTransaction(steps: ["conflict-session-create:\(session.id)"]) {
            try CollaborationStore.save(session, to: url(for: session.id))
        }
        return session
    }

    public func loadSession(id: String) throws -> Session {
        try CollaborationStore.loadRequired(url(for: id), label: "conflict session \(id)")
    }

    public func listSessions() throws -> [Session] {
        var result: [Session] = []
        for file in try CollaborationStore.listJSONFiles(in: sessionsDirectory) {
            if let stored: Session = try CollaborationStore.load(file) {
                result.append(stored)
            }
        }
        return result.sorted { $0.created > $1.created }
    }

    @discardableResult
    public func claimPath(session: String, path: String, owner: String) throws -> Session {
        let name = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw SpacesError.invalidArgument("conflict owner must not be empty")
        }
        return try repo.performTransaction(steps: ["conflict-session-claim:\(session)"]) {
            var stored = try loadSession(id: session)
            guard stored.paths.contains(path) else {
                throw SpacesError.invalidArgument(
                    "path \(path) is not part of conflict session \(session)")
            }
            stored.ownerByPath[path] = name
            try CollaborationStore.save(stored, to: url(for: session))
            return stored
        }
    }

    @discardableResult
    public func recordResolution(session: String, path: String,
                                 resolution: String) throws -> Session {
        let text = resolution.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw SpacesError.invalidArgument("conflict resolution must not be empty")
        }
        return try repo.performTransaction(steps: ["conflict-session-resolve:\(session)"]) {
            var stored = try loadSession(id: session)
            guard stored.paths.contains(path) else {
                throw SpacesError.invalidArgument(
                    "path \(path) is not part of conflict session \(session)")
            }
            stored.resolutionsByPath[path] = text
            try CollaborationStore.save(stored, to: url(for: session))
            return stored
        }
    }

    public func sessionStatus(session: String) throws -> SessionStatus {
        let stored = try loadSession(id: session)
        let unclaimed = stored.paths.filter { stored.ownerByPath[$0] == nil }
        let unresolved = stored.paths.filter { stored.resolutionsByPath[$0] == nil }
        return SessionStatus(total: stored.paths.count,
                             claimed: stored.paths.count - unclaimed.count,
                             resolved: stored.paths.count - unresolved.count,
                             unclaimed: unclaimed, unresolved: unresolved)
    }
}
