import Foundation

public struct SecretHistoryOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let maxCommitsScanned = 200

    public struct SecretFinding: Codable, Sendable {
        public var commit: String
        public var path: String
        public var patternName: String

        public init(commit: String, path: String, patternName: String) {
            self.commit = commit
            self.path = path
            self.patternName = patternName
        }
    }

    public func secretHistory(limit: Int = 100) throws -> [SecretFinding] {
        let bound = max(0, min(limit, Self.maxCommitsScanned))
        guard bound > 0 else { return [] }
        let commits = try HistoryOps(repo: repo).log(limit: bound)
        var findings: [SecretFinding] = []
        for commitInfo in commits {
            let commit = try repo.commitObject(commitInfo.oid)
            let flat = try TreeBuilder.flattenTree(repo: repo, treeOID: commit.tree)
            for (path, entry) in flat.sorted(by: { $0.key < $1.key }) {
                let data: Data
                do {
                    data = try repo.blobData(entry.oid)
                } catch {
                    continue
                }
                guard !DiffEngine.isBinary(data),
                      let text = String(data: data, encoding: .utf8) else { continue }
                for secret in securitySecretPatterns where securityRegexMatches(pattern: secret.pattern, text: text) {
                    findings.append(SecretFinding(commit: commitInfo.oid.hex, path: path,
                                                  patternName: secret.name))
                }
            }
        }
        return findings
    }
}
