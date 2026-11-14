import Foundation

public struct NotificationOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let deliveryDescription = "Notifications are delivered locally only: pendingNotifications lists repository events recorded in this repository, with no push service, network delivery, or external notification provider involved."

    public enum Event: String, Codable, Sendable, Equatable, CaseIterable {
        case commit
        case branch
        case merge
        case snapshot
        case review
    }

    public struct Rule: Codable, Sendable {
        public var event: Event
        public var enabled: Bool

        public init(event: Event, enabled: Bool) {
            self.event = event
            self.enabled = enabled
        }
    }

    public struct RulesFile: Codable, Sendable {
        public var rules: [Rule]

        public init(rules: [Rule] = []) { self.rules = rules }
    }

    public struct PendingNotification: Sendable {
        public var event: Event
        public var timestamp: Int64
        public var message: String
        public var oid: ObjectID?

        public init(event: Event, timestamp: Int64, message: String,
                    oid: ObjectID? = nil) {
            self.event = event
            self.timestamp = timestamp
            self.message = message
            self.oid = oid
        }
    }

    private var rulesURL: URL {
        repo.metaURL.appendingPathComponent("notifications.json")
    }

    private var lastSeenURL: URL {
        repo.metaURL.appendingPathComponent("notifications")
            .appendingPathComponent("last-seen")
    }

    public static func eventForReflogMessage(_ message: String) -> Event? {
        if message.hasPrefix("commit") { return .commit }
        if message.hasPrefix("merge") { return .merge }
        if message.hasPrefix("branch") { return .branch }
        if message.hasPrefix("checkout") { return .branch }
        if message.hasPrefix("snapshot") { return .snapshot }
        return nil
    }

    public func notificationRules() throws -> [Rule] {
        if let file: RulesFile = try CollaborationStore.load(rulesURL) {
            return file.rules
        }
        return Event.allCases.map { Rule(event: $0, enabled: true) }
    }

    public func setNotificationRules(_ rules: [Rule]) throws {
        var seen = Set<Event>()
        for rule in rules {
            guard seen.insert(rule.event).inserted else {
                throw SpacesError.invalidArgument(
                    "duplicate notification rule for \(rule.event.rawValue)")
            }
        }
        try repo.performTransaction(steps: ["notification-rules"]) {
            try CollaborationStore.save(RulesFile(rules: rules), to: rulesURL)
        }
    }

    public func lastSeenTimestamp() throws -> Int64 {
        guard let text = try? String(contentsOf: lastSeenURL, encoding: .utf8),
              let value = Int64(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return 0
        }
        return value
    }

    public func pendingNotifications() throws -> [PendingNotification] {
        let marker = try lastSeenTimestamp()
        let rules = try notificationRules()
        let enabled = Set(rules.filter { $0.enabled }.map { $0.event })
        var pending: [PendingNotification] = []
        for entry in try repo.readReflog(limit: 200) where entry.timestamp > marker {
            if let event = Self.eventForReflogMessage(entry.message),
               enabled.contains(event) {
                pending.append(PendingNotification(event: event,
                                                   timestamp: entry.timestamp,
                                                   message: entry.message,
                                                   oid: entry.new))
            }
        }
        for snapshot in try SnapshotOps(repo: repo).list(limit: 200)
        where snapshot.timestamp > marker && enabled.contains(.snapshot) {
            pending.append(PendingNotification(event: .snapshot,
                                               timestamp: snapshot.timestamp,
                                               message: snapshot.message,
                                               oid: snapshot.oid))
        }
        for review in try ReviewOps(repo: repo).listReviews()
        where review.created > marker && enabled.contains(.review) {
            pending.append(PendingNotification(
                event: .review, timestamp: review.created,
                message: "review \(review.title) (\(review.status.rawValue))"))
        }
        var seen = Set<String>()
        var unique: [PendingNotification] = []
        for note in pending.sorted(by: { $0.timestamp > $1.timestamp }) {
            let key = note.oid.map { $0.hex }
                ?? "\(note.timestamp)|\(note.event.rawValue)|\(note.message)"
            if seen.insert(key).inserted { unique.append(note) }
        }
        return unique
    }

    public func markNotificationsSeen() throws {
        let pending = try pendingNotifications()
        let latest = pending.map { $0.timestamp }.max() ?? 0
        let marker = max(CollaborationStore.now(), latest)
        try repo.performTransaction(steps: ["notifications-seen"]) {
            try CollaborationStore.saveText("\(marker)\n", to: lastSeenURL)
        }
    }
}
