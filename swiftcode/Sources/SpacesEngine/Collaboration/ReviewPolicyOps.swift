import Foundation

public struct ReviewPolicyOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    public struct Policy: Codable, Sendable {
        public var requiredApprovals: Int
        public var requiredReviewers: [String]
        public var requireValidation: Bool

        public init(requiredApprovals: Int = 1, requiredReviewers: [String] = [],
                    requireValidation: Bool = false) {
            self.requiredApprovals = requiredApprovals
            self.requiredReviewers = requiredReviewers
            self.requireValidation = requireValidation
        }
    }

    private var policyURL: URL {
        repo.metaURL.appendingPathComponent("reviews")
            .appendingPathComponent("policy.json")
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
}
