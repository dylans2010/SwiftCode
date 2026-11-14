import Foundation

public struct OwnershipOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let historyScanLimit = 200

    public struct Rule: Codable, Sendable {
        public var pattern: String
        public var owners: [String]

        public init(pattern: String, owners: [String]) {
            self.pattern = pattern
            self.owners = owners
        }
    }

    public struct RulesFile: Codable, Sendable {
        public var rules: [Rule]

        public init(rules: [Rule] = []) { self.rules = rules }
    }

    private var rulesURL: URL {
        repo.metaURL.appendingPathComponent("ownership.json")
    }

    public func ownershipRules() throws -> [Rule] {
        if let file: RulesFile = try CollaborationStore.load(rulesURL) {
            return file.rules
        }
        return []
    }

    public func setOwnershipRules(_ rules: [Rule]) throws {
        for rule in rules {
            guard !rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SpacesError.invalidArgument("ownership rule pattern must not be empty")
            }
            guard !rule.owners.isEmpty,
                  rule.owners.allSatisfy({
                      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  }) else {
                throw SpacesError.invalidArgument(
                    "ownership rule for \(rule.pattern) requires at least one owner")
            }
        }
        try repo.performTransaction(steps: ["ownership-rules"]) {
            try CollaborationStore.save(RulesFile(rules: rules), to: rulesURL)
        }
    }

    public func ownersOf(path: String) throws -> [String] {
        let rules = try ownershipRules()
        var matched: [String]?
        for rule in rules {
            var engine = IgnoreEngine()
            engine.addRules(from: rule.pattern, basePath: "")
            if engine.isIgnored(path, isDirectory: false) {
                matched = rule.owners
            }
        }
        if let matched { return matched }
        return try mostFrequentCommitter(path: path)
    }

    private func mostFrequentCommitter(path: String) throws -> [String] {
        let history = try SearchOps(repo: repo).historyOf(
            path: path, limit: Self.historyScanLimit)
        var counts: [String: Int] = [:]
        for commit in history {
            counts[commit.author.name, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return [] }
        return [top.key]
    }
}
