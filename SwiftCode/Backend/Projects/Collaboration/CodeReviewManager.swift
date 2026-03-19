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

@MainActor
public final class CodeReviewManager: ObservableObject {
    @Published public private(set) var reviews: [UUID: CodeReview] = [:]
    @Published public private(set) var lastEvent: ReviewEvent?

    public func initiateReview(for commitID: UUID) {
        if reviews[commitID] == nil {
            reviews[commitID] = CodeReview(commitID: commitID)
        }
    }

    public func assignReviewer(_ reviewerID: String, to commitID: UUID, actorID: String) {
        initiateReview(for: commitID)
        if reviews[commitID]?.reviewerIDs.contains(reviewerID) == false {
            reviews[commitID]?.reviewerIDs.append(reviewerID)
            lastEvent = ReviewEvent(actorID: actorID, title: "Reviewer assigned", detail: "\(reviewerID) added to review.", notifies: true)
        }
    }

    public func approveReview(for commitID: UUID, actorID: String) {
        initiateReview(for: commitID)
        reviews[commitID]?.status = .approved
        lastEvent = ReviewEvent(actorID: actorID, title: "Review approved", detail: "Commit review approved.", notifies: true)
    }

    public func rejectReview(for commitID: UUID, actorID: String) {
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
}
