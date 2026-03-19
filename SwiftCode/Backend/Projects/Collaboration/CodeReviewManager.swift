import Foundation

public enum ReviewStatus: String, Codable {
    case pending
    case approved
    case rejected
}

public struct CodeReview: Identifiable, Codable {
    public let id: UUID
    public let commitID: UUID
    public var status: ReviewStatus
    public var comments: [ReviewComment]

    public init(commitID: UUID) {
        self.id = UUID()
        self.commitID = commitID
        self.status = .pending
        self.comments = []
    }
}

public struct ReviewComment: Identifiable, Codable {
    public let id: UUID
    public let authorID: String
    public let text: String
    public let timestamp: Date

    public init(authorID: String, text: String) {
        self.id = UUID()
        self.authorID = authorID
        self.text = text
        self.timestamp = Date()
    }
}

@MainActor
public final class CodeReviewManager: ObservableObject {
    @Published public private(set) var reviews: [UUID: CodeReview] = [:]

    public func initiateReview(for commitID: UUID) {
        reviews[commitID] = CodeReview(commitID: commitID)
    }

    public func approveReview(for commitID: UUID) {
        reviews[commitID]?.status = .approved
    }

    public func rejectReview(for commitID: UUID) {
        reviews[commitID]?.status = .rejected
    }

    public func addComment(to commitID: UUID, authorID: String, text: String) {
        let comment = ReviewComment(authorID: authorID, text: text)
        reviews[commitID]?.comments.append(comment)
    }
}
