import Foundation

public struct ActivityFeedOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct Event: Codable, Sendable {
        public var timestamp: Int64
        public var type: String
        public var message: String
        public var oid: ObjectID?

        public init(timestamp: Int64, type: String, message: String, oid: ObjectID? = nil) {
            self.timestamp = timestamp
            self.type = type
            self.message = message
            self.oid = oid
        }
    }

    public static func typeForReflogMessage(_ message: String) -> String {
        if message.hasPrefix("commit") { return "commit" }
        if message.hasPrefix("merge") { return "merge" }
        if message.hasPrefix("branch") { return "branch" }
        if message.hasPrefix("checkout") { return "branch" }
        if message.hasPrefix("snapshot") { return "snapshot" }
        return "reflog"
    }

    public func activityFeed(limit: Int = 50) throws -> [Event] {
        guard limit > 0 else { return [] }
        var events: [Event] = []
        for entry in try repo.readReflog(limit: 200) {
            events.append(Event(timestamp: entry.timestamp,
                                type: Self.typeForReflogMessage(entry.message),
                                message: entry.message, oid: entry.new))
        }
        for commit in try HistoryOps(repo: repo).log(limit: 200) {
            events.append(Event(timestamp: commit.timestamp, type: "commit",
                                message: commit.summary, oid: commit.oid))
        }
        for snapshot in try SnapshotOps(repo: repo).list(limit: 200) {
            events.append(Event(timestamp: snapshot.timestamp, type: "snapshot",
                                message: snapshot.message, oid: snapshot.oid))
        }
        for review in try ReviewOps(repo: repo).listReviews() {
            events.append(Event(timestamp: review.created, type: "review",
                                message: "review \(review.title) (\(review.status.rawValue))"))
        }
        for step in repo.journal.unfinishedSteps() {
            events.append(Event(timestamp: CollaborationStore.now(), type: "maintenance",
                                message: "unfinished transaction step: \(step)"))
        }
        var seen = Set<String>()
        var unique: [Event] = []
        for event in events.sorted(by: { $0.timestamp > $1.timestamp }) {
            let key = event.oid.map { $0.hex }
                ?? "\(event.timestamp)|\(event.type)|\(event.message)"
            if seen.insert(key).inserted { unique.append(event) }
        }
        return Array(unique.prefix(limit))
    }
}
