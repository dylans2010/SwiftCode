import Foundation

public struct ReviewTrackingOps {
    public let repo: Repository
    public init(repo: Repository) { self.repo = repo }

    @discardableResult
    public func approveReview(id: String, reviewer: String) throws -> ReviewOps.Review {
        let name = reviewer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw SpacesError.invalidArgument("reviewer must not be empty")
        }
        return try repo.performTransaction(steps: ["review-approve:\(id)"]) {
            let reviews = ReviewOps(repo: repo)
            var stored = try reviews.review(id)
            stored.approvals.removeAll { $0.reviewer == name }
            stored.approvals.append(ReviewOps.Approval(
                reviewer: name, headRev: stored.headRev,
                timestamp: CollaborationStore.now()))
            stored.status = .approved
            try reviews.saveReview(stored)
            return stored
        }
    }

    public func latestApproval(review: String) throws -> ReviewOps.Approval? {
        let stored = try ReviewOps(repo: repo).review(review)
        return stored.approvals.max(by: { $0.timestamp < $1.timestamp })
    }

    public func changesSinceApproval(review: String) throws -> [String] {
        guard let approval = try latestApproval(review: review) else { return [] }
        guard let headOID = try repo.refs.headOID(objects: repo.objects) else {
            return []
        }
        let current = headOID.hex
        guard approval.headRev != current else { return [] }
        let diffs = try DiffOps(repo: repo).commitDiff(approval.headRev, current)
        return Array(Set(diffs.map { $0.newPath })).sorted()
    }
}
