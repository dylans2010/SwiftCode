import Foundation

public struct PullRequestEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

public enum PullRequestStatus: String, Codable, CaseIterable {
    case open
    case closed
    case merged
}

public struct PullRequestComment: Identifiable, Codable, Equatable {
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

public struct PullRequest: Identifiable, Codable, Equatable {
    public let id: UUID
    public let sourceBranchID: UUID
    public let targetBranchID: UUID
    public var title: String
    public var description: String
    public var status: PullRequestStatus
    public var authorID: String
    public let createdAt: Date
    public var comments: [PullRequestComment]
    public var mergeCommitID: UUID?

    public init(sourceBranchID: UUID, targetBranchID: UUID, title: String, description: String, authorID: String) {
        self.id = UUID()
        self.sourceBranchID = sourceBranchID
        self.targetBranchID = targetBranchID
        self.title = title
        self.description = description
        self.status = .open
        self.authorID = authorID
        self.createdAt = Date()
        self.comments = []
    }
}

@MainActor
public final class PullRequestManager: ObservableObject {
    @Published public private(set) var pullRequests: [PullRequest] = []
    @Published public private(set) var lastEvent: PullRequestEvent?

    public init() {}

    public func createPullRequest(sourceBranchID: UUID, targetBranchID: UUID, title: String, description: String, actorID: String) -> PullRequest {
        let pr = PullRequest(sourceBranchID: sourceBranchID, targetBranchID: targetBranchID, title: title, description: description, authorID: actorID)
        pullRequests.append(pr)
        lastEvent = PullRequestEvent(actorID: actorID, title: "Pull Request created", detail: "#\(pullRequests.count) \(title)", notifies: true)
        return pr
    }

    public func addComment(to prID: UUID, authorID: String, text: String) {
        if let index = pullRequests.firstIndex(where: { $0.id == prID }) {
            let comment = PullRequestComment(authorID: authorID, text: text)
            pullRequests[index].comments.append(comment)
            lastEvent = PullRequestEvent(actorID: authorID, title: "PR comment added", detail: "New comment on #\(index + 1)", notifies: true)
        }
    }

    public func updateStatus(prID: UUID, status: PullRequestStatus, actorID: String, mergeCommitID: UUID? = nil) {
        if let index = pullRequests.firstIndex(where: { $0.id == prID }) {
            pullRequests[index].status = status
            if let mergeCommitID { pullRequests[index].mergeCommitID = mergeCommitID }
            lastEvent = PullRequestEvent(actorID: actorID, title: "PR status updated", detail: "PR #\(index + 1) is now \(status.rawValue)", notifies: true)
        }
    }

    public func close(prID: UUID, actorID: String) {
        updateStatus(prID: prID, status: .closed, actorID: actorID)
    }

    public func markMerged(prID: UUID, mergeCommitID: UUID, actorID: String) {
        updateStatus(prID: prID, status: .merged, actorID: actorID, mergeCommitID: mergeCommitID)
    }

    public func restoreState(pullRequests: [PullRequest]) {
        self.pullRequests = pullRequests
    }
}
