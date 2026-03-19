import Foundation

public struct ReviewEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

public enum ReviewStatus: String, Codable {
    case pending
    case approved
    case rejected
}

public struct ReviewComment: Identifiable, Codable, Equatable {
    public let id: UUID
    public let authorID: String
    public let filePath: String
    public let lineNumber: Int
    public let text: String
    public let timestamp: Date

    public init(authorID: String, filePath: String, lineNumber: Int, text: String) {
        self.id = UUID()
        self.authorID = authorID
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.text = text
        self.timestamp = Date()
    }
}

public struct CodeReview: Identifiable, Codable, Equatable {
    public let id: UUID
    public let commitID: UUID
    public var status: ReviewStatus
    public var comments: [ReviewComment]
    public var reviewerIDs: [String]

    public init(commitID: UUID) {
        self.id = UUID()
        self.commitID = commitID
        self.status = .pending
        self.comments = []
        self.reviewerIDs = []
    }
}

public struct PullRequest: Identifiable, Codable, Equatable {
    public enum PRStatus: String, Codable {
        case open
        case merged
        case closed
    }

    public let id: UUID
    public let title: String
    public let description: String
    public let sourceBranchID: UUID
    public let targetBranchID: UUID
    public let authorID: String
    public var status: PRStatus
    public let createdAt: Date
    public var reviewers: [String]
    public var comments: [ReviewComment]

    public init(title: String, description: String, sourceBranchID: UUID, targetBranchID: UUID, authorID: String) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.sourceBranchID = sourceBranchID
        self.targetBranchID = targetBranchID
        self.authorID = authorID
        self.status = .open
        self.createdAt = Date()
        self.reviewers = []
        self.comments = []
    }
}

@MainActor
public final class CodeReviewManager: ObservableObject {
    @Published public private(set) var reviews: [UUID: CodeReview] = [:]
    @Published public private(set) var pullRequests: [PullRequest] = []
    @Published public private(set) var lastEvent: ReviewEvent?

    public init() {}

    public func restore(reviews: [UUID: CodeReview], pullRequests: [PullRequest]) {
        self.reviews = reviews
        self.pullRequests = pullRequests
    }

    public func initiateReview(for commitID: UUID) {
        if reviews[commitID] == nil {
            reviews[commitID] = CodeReview(commitID: commitID)
        }
    }

    public func assignReviewer(_ reviewerID: String, to commitID: UUID, actorID: String, permissions: PermissionsManager? = nil) {
        if let permissions = permissions {
             guard permissions.canManageMembers(actorID: actorID) else { return }
        }

        initiateReview(for: commitID)
        if reviews[commitID]?.reviewerIDs.contains(reviewerID) == false {
            reviews[commitID]?.reviewerIDs.append(reviewerID)
            lastEvent = ReviewEvent(actorID: actorID, title: "Reviewer assigned", detail: "\(reviewerID) added to review.", notifies: true)
        }
    }

    public func approveReview(for commitID: UUID, actorID: String, permissions: PermissionsManager? = nil) {
        if let permissions = permissions {
             guard permissions.hasPermission(.merge, for: actorID, projectPermission: .owner) else { return }
        }

        initiateReview(for: commitID)
        reviews[commitID]?.status = .approved
        lastEvent = ReviewEvent(actorID: actorID, title: "Review approved", detail: "Commit review approved.", notifies: true)
    }

    public func rejectReview(for commitID: UUID, actorID: String, permissions: PermissionsManager? = nil) {
        if let permissions = permissions {
             guard permissions.hasPermission(.merge, for: actorID, projectPermission: .owner) else { return }
        }

        initiateReview(for: commitID)
        reviews[commitID]?.status = .rejected
        lastEvent = ReviewEvent(actorID: actorID, title: "Review rejected", detail: "Commit review rejected.", notifies: true)
    }

    public func addComment(to commitID: UUID, authorID: String, filePath: String, lineNumber: Int, text: String) {
        initiateReview(for: commitID)
        let comment = ReviewComment(authorID: authorID, filePath: filePath, lineNumber: lineNumber, text: text)
        reviews[commitID]?.comments.append(comment)
        lastEvent = ReviewEvent(actorID: authorID, title: "Inline comment added", detail: "\(filePath):\(lineNumber)", notifies: false)
    }

    // MARK: - Pull Request Logic

    public func createPR(title: String, description: String, sourceBranchID: UUID, targetBranchID: UUID, authorID: String, permissions: PermissionsManager? = nil) -> PullRequest? {
        if let permissions = permissions {
             guard permissions.hasPermission(.commit, for: authorID, projectPermission: .owner) else { return nil }
        }

        let pr = PullRequest(title: title, description: description, sourceBranchID: sourceBranchID, targetBranchID: targetBranchID, authorID: authorID)
        pullRequests.append(pr)
        lastEvent = ReviewEvent(actorID: authorID, title: "Pull Request opened", detail: title, notifies: true)
        return pr
    }

    public func mergePR(_ prID: UUID, actorID: String, permissions: PermissionsManager? = nil) {
        if let permissions = permissions {
             guard permissions.hasPermission(.merge, for: actorID, projectPermission: .owner) else { return }
        }

        if let index = pullRequests.firstIndex(where: { $0.id == prID }) {
            pullRequests[index].status = .merged
            lastEvent = ReviewEvent(actorID: actorID, title: "Pull Request merged", detail: pullRequests[index].title, notifies: true)
        }
    }

    public func closePR(_ prID: UUID, actorID: String, permissions: PermissionsManager? = nil) {
        if let permissions = permissions {
             guard permissions.hasPermission(.merge, for: actorID, projectPermission: .owner) else { return }
        }

        if let index = pullRequests.firstIndex(where: { $0.id == prID }) {
            pullRequests[index].status = .closed
            lastEvent = ReviewEvent(actorID: actorID, title: "Pull Request closed", detail: pullRequests[index].title, notifies: true)
        }
    }

    public func addCommentToPR(_ prID: UUID, comment: ReviewComment) {
        if let index = pullRequests.firstIndex(where: { $0.id == prID }) {
            pullRequests[index].comments.append(comment)
            lastEvent = ReviewEvent(actorID: comment.authorID, title: "PR comment added", detail: comment.text, notifies: false)
        }
    }
}
