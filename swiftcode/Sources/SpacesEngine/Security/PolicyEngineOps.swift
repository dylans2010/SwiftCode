import Foundation

enum SecurityFileStore {
    static func url(repo: Repository, relative: String) -> URL {
        repo.metaURL.appendingPathComponent(relative)
    }

    static func load<T: Decodable>(repo: Repository, relative: String) throws -> T? {
        let file = url(repo: repo, relative: relative)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: file))
        } catch {
            throw SpacesError.configError("cannot parse \(relative): \(error.localizedDescription)")
        }
    }

    static func save<T: Encodable>(repo: Repository, relative: String, value: T) throws {
        let file = url(repo: repo, relative: relative)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(value).write(to: file, options: .atomic)
    }

    static func appendLine(repo: Repository, relative: String, line: String) throws {
        let file = url(repo: repo, relative: relative)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: file.path) {
            FileManager.default.createFile(atPath: file.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((line + "\n").utf8))
    }

    static func readLines(repo: Repository, relative: String) -> [String] {
        let file = url(repo: repo, relative: relative)
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return text.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
}

func securityGlobMatch(pattern: String, value: String) -> Bool {
    var regex = "^"
    for ch in pattern {
        switch ch {
        case "*": regex += ".*"
        case "?": regex += "."
        default: regex += NSRegularExpression.escapedPattern(for: String(ch))
        }
    }
    regex += "$"
    guard let re = try? NSRegularExpression(pattern: regex) else { return false }
    let range = NSRange(value.startIndex..., in: value)
    return re.firstMatch(in: value, range: range) != nil
}

func securityRegexMatches(pattern: String, text: String) -> Bool {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return false }
    let range = NSRange(text.startIndex..., in: text)
    return re.firstMatch(in: text, range: range) != nil
}

let securitySecretPatterns: [(name: String, pattern: String)] = [
    (name: "aws-access-key", pattern: #"AKIA[0-9A-Z]{16}"#),
    (name: "private-key", pattern: #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#),
    (name: "generic-secret", pattern: #"(?i)(api[_-]?key|secret|password|token)\s*[:=]\s*['"][^'"]{8,}"#),
    (name: "github-token", pattern: #"gh[pousr]_[A-Za-z0-9]{36,}"#),
    (name: "slack-token", pattern: #"xox[baprs]-[A-Za-z0-9-]{10,}"#),
]

func securitySplitList(_ value: String) -> [String] {
    value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

public struct PolicyEngineOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let policyRelativePath = "security/policy.json"

    public enum PolicyOperation: String, Codable, Sendable {
        case commit
        case branchCreate = "branch-create"
        case branchDelete = "branch-delete"
        case merge
        case push
        case tag
    }

    public enum PolicyRuleKind: String, Codable, Sendable {
        case protectedBranches
        case maxFileSizeBytes
        case requireSignedCommits
        case forbiddenPaths
        case requireMessagePattern
    }

    public struct PolicyRule: Codable, Sendable {
        public var id: String
        public var kind: PolicyRuleKind
        public var value: String
        public var enabled: Bool

        public init(id: String, kind: PolicyRuleKind, value: String, enabled: Bool = true) {
            self.id = id
            self.kind = kind
            self.value = value
            self.enabled = enabled
        }
    }

    public struct RepositoryPolicy: Codable, Sendable {
        public var rules: [PolicyRule]

        public init(rules: [PolicyRule] = []) {
            self.rules = rules
        }
    }

    public struct PolicyViolation: Codable, Sendable {
        public var ruleID: String
        public var message: String

        public init(ruleID: String, message: String) {
            self.ruleID = ruleID
            self.message = message
        }
    }

    public struct PolicyOperationDetails: Sendable {
        public var message: String?
        public var paths: [String]
        public var branch: String?
        public var fileSizes: [String: Int64]
        public var signed: Bool

        public init(message: String? = nil, paths: [String] = [], branch: String? = nil,
                    fileSizes: [String: Int64] = [:], signed: Bool = false) {
            self.message = message
            self.paths = paths
            self.branch = branch
            self.fileSizes = fileSizes
            self.signed = signed
        }
    }

    public func repositoryPolicy() throws -> RepositoryPolicy {
        try SecurityFileStore.load(repo: repo, relativePath: Self.policyRelativePath)
            ?? RepositoryPolicy()
    }

    public func setRepositoryPolicy(_ policy: RepositoryPolicy) throws {
        for rule in policy.rules {
            switch rule.kind {
            case .maxFileSizeBytes:
                guard let size = Int64(rule.value.trimmingCharacters(in: .whitespaces)), size >= 0 else {
                    throw SpacesError.invalidArgument(
                        "rule \(rule.id): maxFileSizeBytes value must be a non-negative integer")
                }
            case .requireMessagePattern:
                guard (try? NSRegularExpression(pattern: rule.value)) != nil else {
                    throw SpacesError.invalidArgument(
                        "rule \(rule.id): requireMessagePattern value is not a valid regex")
                }
            default:
                break
            }
        }
        try repo.withLock {
            try SecurityFileStore.save(repo: repo, relativePath: Self.policyRelativePath, value: policy)
        }
    }

    public func checkPolicy(operation: PolicyOperation,
                            details: PolicyOperationDetails = PolicyOperationDetails()) throws -> [PolicyViolation] {
        let policy = try repositoryPolicy()
        var violations: [PolicyViolation] = []
        for rule in policy.rules where rule.enabled {
            switch rule.kind {
            case .protectedBranches:
                guard operation == .branchDelete || operation == .push || operation == .merge,
                      let branch = details.branch else { continue }
                let patterns = securitySplitList(rule.value)
                let matched = patterns.contains {
                    securityGlobMatch(pattern: $0, value: branch)
                        || securityGlobMatch(pattern: $0, value: "refs/heads/" + branch)
                }
                if matched {
                    violations.append(PolicyViolation(
                        ruleID: rule.id,
                        message: "branch \(branch) is protected by rule \(rule.id)"))
                }
            case .maxFileSizeBytes:
                guard operation == .commit,
                      let max = Int64(rule.value.trimmingCharacters(in: .whitespaces)) else { continue }
                for path in details.paths {
                    let size: Int64
                    if let known = details.fileSizes[path] {
                        size = known
                    } else if let url = try? repo.worktreeURL(forRelativePath: path),
                              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                              let fileSize = attrs[.size] as? Int64 {
                        size = fileSize
                    } else {
                        continue
                    }
                    if size > max {
                        violations.append(PolicyViolation(
                            ruleID: rule.id,
                            message: "file \(path) is \(size) bytes, exceeding the \(max) byte limit of rule \(rule.id)"))
                    }
                }
            case .requireSignedCommits:
                guard operation == .commit,
                      rule.value.trimmingCharacters(in: .whitespaces).lowercased() == "true",
                      !details.signed else { continue }
                violations.append(PolicyViolation(
                    ruleID: rule.id,
                    message: "commit must be signed (rule \(rule.id))"))
            case .forbiddenPaths:
                guard operation == .commit else { continue }
                let patterns = securitySplitList(rule.value)
                for path in details.paths where patterns.contains(where: { securityGlobMatch(pattern: $0, value: path) }) {
                    violations.append(PolicyViolation(
                        ruleID: rule.id,
                        message: "path \(path) is forbidden by rule \(rule.id)"))
                }
            case .requireMessagePattern:
                guard operation == .commit else { continue }
                guard let message = details.message else {
                    violations.append(PolicyViolation(
                        ruleID: rule.id,
                        message: "commit message is missing, required by rule \(rule.id)"))
                    continue
                }
                if (try? NSRegularExpression(pattern: rule.value)) == nil {
                    violations.append(PolicyViolation(
                        ruleID: rule.id,
                        message: "rule \(rule.id) has an invalid message pattern"))
                } else if !securityRegexMatches(pattern: rule.value, text: message) {
                    violations.append(PolicyViolation(
                        ruleID: rule.id,
                        message: "commit message does not match the pattern required by rule \(rule.id)"))
                }
            }
        }
        return violations
    }
}
