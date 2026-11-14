import Foundation

public struct ProtectedHistoryOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let rulesRelativePath = "security/protected.json"

    public struct ProtectedRefRule: Codable, Sendable {
        public var pattern: String
        public var allowForcePush: Bool
        public var allowDelete: Bool
        public var requireReview: Bool

        public init(pattern: String, allowForcePush: Bool = false, allowDelete: Bool = false,
                    requireReview: Bool = false) {
            self.pattern = pattern
            self.allowForcePush = allowForcePush
            self.allowDelete = allowDelete
            self.requireReview = requireReview
        }
    }

    public struct ProtectedHistoryRules: Codable, Sendable {
        public var refs: [ProtectedRefRule]

        public init(refs: [ProtectedRefRule] = []) {
            self.refs = refs
        }
    }

    public func protectedHistoryRules() throws -> ProtectedHistoryRules {
        try SecurityFileStore.load(repo: repo, relativePath: Self.rulesRelativePath)
            ?? ProtectedHistoryRules()
    }

    public func setProtectedHistoryRules(_ rules: ProtectedHistoryRules) throws {
        try repo.withLock {
            try SecurityFileStore.save(repo: repo, relativePath: Self.rulesRelativePath, value: rules)
        }
    }

    public func checkProtectedHistory(ref: String, operation: String) throws -> (allowed: Bool, reasons: [String]) {
        let rules = try protectedHistoryRules()
        let short = ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
        var reasons: [String] = []
        for rule in rules.refs where securityGlobMatch(pattern: rule.pattern, value: ref)
            || securityGlobMatch(pattern: rule.pattern, value: short) {
            switch operation {
            case "force-push":
                if !rule.allowForcePush {
                    reasons.append("force-push to \(ref) is denied by protected-history rule \(rule.pattern)")
                }
            case "delete":
                if !rule.allowDelete {
                    reasons.append("deleting \(ref) is denied by protected-history rule \(rule.pattern)")
                }
            case "rewrite":
                if rule.requireReview {
                    reasons.append("rewriting \(ref) requires review under protected-history rule \(rule.pattern)")
                }
            default:
                reasons.append("unknown protected-history operation \(operation)")
            }
        }
        return (allowed: reasons.isEmpty, reasons: reasons)
    }
}
