import Foundation

public struct ReviewPolicyOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct Policy: Codable, Sendable {
        public var requiredApprovals: Int
        public var requiredReviewers: [String]
        public var requireValidation: Bool
        public var branch: String?

        public init(requiredApprovals: Int = 1, requiredReviewers: [String] = [],
                    requireValidation: Bool = false, branch: String? = nil) {
            self.requiredApprovals = requiredApprovals
            self.requiredReviewers = requiredReviewers
            self.requireValidation = requireValidation
            self.branch = branch
        }
    }

    private var policyURL: URL {
        repo.metaURL.appendingPathComponent("reviews")
            .appendingPathComponent("policy.json")
    }

    public func isReviewPolicyConfigured() -> Bool {
        FileManager.default.fileExists(atPath: policyURL.path)
    }

    public func reviewPolicy() throws -> Policy {
        if let stored: Policy = try CollaborationStore.load(policyURL) {
            return stored
        }
        return Policy()
    }

    public func setReviewPolicy(_ policy: Policy) throws {
        guard policy.requiredApprovals >= 0 else {
            throw SpacesError.invalidArgument("requiredApprovals must not be negative")
        }
        for reviewer in policy.requiredReviewers {
            guard !reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SpacesError.invalidArgument("required reviewer must not be empty")
            }
        }
        try repo.performTransaction(steps: ["review-policy"]) {
            try CollaborationStore.save(policy, to: policyURL)
        }
    }

    public func reviewMergeCheck(id: String) throws -> (allowed: Bool, reasons: [String]) {
        let review = try ReviewOps(repo: repo).review(id)
        let policy = try reviewPolicy()
        var reasons: [String] = []
        if review.status == .merged {
            reasons.append("review is already merged")
        }
        if review.status == .changesRequested {
            reasons.append("review has requested changes")
        }
        let approvers = Set(review.approvals.map { $0.reviewer })
        if approvers.count < policy.requiredApprovals {
            reasons.append("requires \(policy.requiredApprovals) approval(s), has \(approvers.count)")
        }
        for required in policy.requiredReviewers where !approvers.contains(required) {
            reasons.append("missing required reviewer \(required)")
        }
        if policy.requireValidation {
            let changed = try ReviewTrackingOps(repo: repo).changesSinceApproval(review: id)
            if !changed.isEmpty {
                reasons.append("changes since last approval: \(changed.joined(separator: ", "))")
            }
        }
        return (reasons.isEmpty, reasons)
    }

    public func reviewMergeCheckForTarget(_ target: String) throws -> (allowed: Bool, reasons: [String]) {
        guard isReviewPolicyConfigured() else { return (true, []) }
        let policy = try reviewPolicy()
        if let branch = policy.branch, branch != target { return (true, []) }
        guard let targetOID = try? repo.resolveRevision(target) else { return (true, []) }
        let reviews = try ReviewOps(repo: repo).listReviews()
            .filter { $0.headRev == targetOID.hex && $0.status != .merged }
        var reasons: [String] = []
        for review in reviews {
            let check = try reviewMergeCheck(id: review.id)
            if !check.allowed {
                reasons.append(contentsOf: check.reasons.map { "review \(review.id): \($0)" })
            }
        }
        return (reasons.isEmpty, reasons)
    }
}
