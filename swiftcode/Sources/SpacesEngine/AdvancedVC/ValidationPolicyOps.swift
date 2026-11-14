import Foundation

public struct ValidationPolicyOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public enum RuleKind: String, Sendable, Codable, CaseIterable {
        case messagePattern = "message-pattern"
        case maxFiles = "max-files"
        case maxBytesPerFile = "max-bytes-per-file"
        case noSecrets = "no-secrets"
        case requireCategory = "require-category"
    }

    public struct PolicyRule: Sendable, Codable {
        public var id: String
        public var kind: RuleKind
        public var pattern: String?
        public var value: Int?
        public var enabled: Bool

        public init(id: String, kind: RuleKind, pattern: String? = nil, value: Int? = nil, enabled: Bool = true) {
            self.id = id
            self.kind = kind
            self.pattern = pattern
            self.value = value
            self.enabled = enabled
        }
    }

    public struct PolicyViolation: Sendable, Codable {
        public var ruleId: String
        public var message: String
    }

    private struct PoliciesFile: Codable {
        var rules: [PolicyRule]
    }

    static let secretPatterns: [(String, String)] = [
        ("aws-access-key", #"AKIA[0-9A-Z]{16}"#),
        ("private-key", #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#),
        ("generic-secret", #"(?i)(api[_-]?key|secret|password|token)\s*[:=]\s*['\"][^'\"]{8,}"#),
        ("github-token", #"gh[pousr]_[A-Za-z0-9]{36,}"#),
        ("slack-token", #"xox[baprs]-[A-Za-z0-9-]{10,}"#)
    ]

    private var policiesURL: URL {
        repo.metaURL.appendingPathComponent("policies.json")
    }

    public func commitPolicies() throws -> [PolicyRule] {
        guard let file: PoliciesFile = try AdvancedVCStore.readJSON(PoliciesFile.self, from: policiesURL) else {
            return []
        }
        return file.rules
    }

    public func setCommitPolicies(_ rules: [PolicyRule]) throws {
        var seen = Set<String>()
        for rule in rules {
            let trimmed = rule.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else {
                throw SpacesError.invalidArgument("policy rule ids must be unique and non-empty")
            }
            if rule.kind == .messagePattern {
                guard let pattern = rule.pattern, !pattern.isEmpty else {
                    throw SpacesError.invalidArgument("message-pattern rule \(rule.id) needs a pattern")
                }
                guard (try? NSRegularExpression(pattern: pattern)) != nil else {
                    throw SpacesError.invalidArgument("message-pattern rule \(rule.id) has an invalid regex")
                }
            }
            if rule.kind == .maxFiles || rule.kind == .maxBytesPerFile {
                guard let value = rule.value, value > 0 else {
                    throw SpacesError.invalidArgument("rule \(rule.id) needs a positive value")
                }
            }
        }
        try repo.withLock {
            try AdvancedVCStore.writeJSON(PoliciesFile(rules: rules), to: policiesURL)
        }
    }

    public func validateCommit(message: String, stagedPaths: [String]) throws -> [PolicyViolation] {
        var violations: [PolicyViolation] = []
        for rule in try commitPolicies() where rule.enabled {
            switch rule.kind {
            case .messagePattern:
                guard let pattern = rule.pattern else { continue }
                guard let regex = try? NSRegularExpression(pattern: pattern) else {
                    violations.append(PolicyViolation(ruleId: rule.id, message: "rule \(rule.id) has an invalid regex"))
                    continue
                }
                let range = NSRange(message.startIndex..., in: message)
                if regex.firstMatch(in: message, options: [], range: range) == nil {
                    violations.append(PolicyViolation(ruleId: rule.id, message: "commit message does not match required pattern"))
                }
            case .maxFiles:
                if let max = rule.value, stagedPaths.count > max {
                    violations.append(PolicyViolation(ruleId: rule.id, message: "commit touches \(stagedPaths.count) files, maximum is \(max)"))
                }
            case .maxBytesPerFile:
                guard let max = rule.value else { continue }
                for path in stagedPaths {
                    let size = try stagedFileSize(path)
                    if size > max {
                        violations.append(PolicyViolation(ruleId: rule.id, message: "\(path) is \(size) bytes, maximum is \(max)"))
                    }
                }
            case .noSecrets:
                for path in stagedPaths {
                    guard let text = try stagedFileText(path) else { continue }
                    for (name, pattern) in Self.secretPatterns {
                        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                        let range = NSRange(text.startIndex..., in: text)
                        if regex.firstMatch(in: text, options: [], range: range) != nil {
                            violations.append(PolicyViolation(ruleId: rule.id, message: "\(path) may contain a \(name)"))
                        }
                    }
                }
            case .requireCategory:
                let firstLine = message.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
                let pattern = #"^\[[A-Za-z0-9][A-Za-z0-9 _-]*\]"#
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(firstLine.startIndex..., in: firstLine)
                if regex.firstMatch(in: firstLine, options: [], range: range) == nil {
                    violations.append(PolicyViolation(ruleId: rule.id, message: "commit message must start with a [category] prefix"))
                }
            }
        }
        return violations
    }

    private func stagedFileSize(_ path: String) throws -> Int {
        let url = try repo.worktreeURL(forRelativePath: path)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            return Int(size)
        }
        if let entry = try repo.index().entries[path] {
            return try repo.blobData(entry.oid).count
        }
        return 0
    }

    private func stagedFileText(_ path: String) throws -> String? {
        let url = try repo.worktreeURL(forRelativePath: path)
        if let data = try? Data(contentsOf: url) {
            return String(data: data, encoding: .utf8)
        }
        if let entry = try repo.index().entries[path],
           let data = try? repo.blobData(entry.oid) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
