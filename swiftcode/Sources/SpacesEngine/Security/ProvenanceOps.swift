import Foundation

public struct ProvenanceOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public static let trustRelativePath = "security/trust.json"

    public struct TrustPolicy: Codable, Sendable {
        public var trustedSigners: [String]

        public init(trustedSigners: [String] = []) {
            self.trustedSigners = trustedSigners
        }
    }

    public struct ProvenanceCheck: Codable, Sendable {
        public var name: String
        public var passed: Bool
        public var detail: String

        public init(name: String, passed: Bool, detail: String) {
            self.name = name
            self.passed = passed
            self.detail = detail
        }
    }

    public func trustPolicy() throws -> TrustPolicy {
        try SecurityFileStore.load(repo: repo, relativePath: Self.trustRelativePath)
            ?? TrustPolicy()
    }

    public func setTrustPolicy(_ policy: TrustPolicy) throws {
        try repo.withLock {
            try SecurityFileStore.save(repo: repo, relativePath: Self.trustRelativePath, value: policy)
        }
    }

    public func verifyProvenance(rev: String) throws -> [ProvenanceCheck] {
        let oid = try repo.resolveRevision(rev)
        var checks: [ProvenanceCheck] = []
        let commit: CommitPayload
        do {
            commit = try repo.commitObject(oid)
            checks.append(ProvenanceCheck(
                name: "commit-exists",
                passed: true,
                detail: "commit \(oid.hex) exists and its stored hash verifies"))
        } catch {
            checks.append(ProvenanceCheck(
                name: "commit-exists",
                passed: false,
                detail: "commit \(oid.hex) cannot be read: \(error.localizedDescription)"))
            return checks
        }
        var ancestryPassed = true
        var ancestryDetail = "all ancestors exist"
        var visited = Set<ObjectID>()
        var queue = commit.parents
        while let parent = queue.popLast() {
            guard visited.insert(parent).inserted else { continue }
            do {
                let parentCommit = try repo.commitObject(parent)
                queue.append(contentsOf: parentCommit.parents)
            } catch {
                ancestryPassed = false
                ancestryDetail = "ancestor \(parent.hex) is missing or corrupt: \(error.localizedDescription)"
                break
            }
        }
        checks.append(ProvenanceCheck(name: "ancestry-intact", passed: ancestryPassed, detail: ancestryDetail))
        if let signature = commit.metadata.signature {
            let result: Ed25519Signing.Verification
            do {
                result = try Ed25519Signing(repo: repo).verifyCommit(oid: oid, payload: commit)
            } catch {
                result = Ed25519Signing.Verification(valid: false, method: "", fingerprint: nil,
                                                      reason: "signature verification failed: \(error.localizedDescription)")
            }
            checks.append(ProvenanceCheck(
                name: "signature",
                passed: result.valid,
                detail: result.reason))
        } else {
            let policy = try PolicyEngineOps(repo: repo).repositoryPolicy()
            let required = policy.rules.contains {
                $0.enabled && $0.kind == .requireSignedCommits
                    && $0.value.trimmingCharacters(in: .whitespaces).lowercased() == "true"
            }
            checks.append(ProvenanceCheck(
                name: "signature",
                passed: !required,
                detail: required ? "commit is unsigned but repository policy requires signed commits"
                    : "commit carries no signature"))
        }
        let trust = try trustPolicy()
        if trust.trustedSigners.isEmpty {
            checks.append(ProvenanceCheck(
                name: "author-trusted",
                passed: true,
                detail: "no trust policy configured; author \(commit.author.email) is not checked"))
        } else {
            let trusted = trust.trustedSigners.contains(commit.author.email)
            checks.append(ProvenanceCheck(
                name: "author-trusted",
                passed: trusted,
                detail: trusted ? "author \(commit.author.email) is in the trust policy"
                    : "author \(commit.author.email) is not in the trust policy"))
        }
        return checks
    }
}
