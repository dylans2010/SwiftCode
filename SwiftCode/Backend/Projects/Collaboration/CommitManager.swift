import Foundation

public struct Commit: Identifiable, Codable {
    public let id: UUID
    public let branchID: UUID
    public let authorID: String
    public let message: String
    public let timestamp: Date
    public let changes: [String: String] // Path: Content Hash or Diff

    public init(branchID: UUID, authorID: String, message: String, changes: [String: String]) {
        self.id = UUID()
        self.branchID = branchID
        self.authorID = authorID
        self.message = message
        self.timestamp = Date()
        self.changes = changes
    }
}

@MainActor
public final class CommitManager: ObservableObject {
    @Published public private(set) var commits: [Commit] = []
    private var undoStack: [Commit] = []
    private var redoStack: [Commit] = []

    public func recordCommit(branchID: UUID, authorID: String, message: String, changes: [String: String]) -> Commit {
        let commit = Commit(branchID: branchID, authorID: authorID, message: message, changes: changes)
        commits.append(commit)
        undoStack.append(commit)
        redoStack.removeAll()
        return commit
    }

    public func undo() -> Commit? {
        guard let last = undoStack.popLast() else { return nil }
        redoStack.append(last)
        commits.removeAll { $0.id == last.id }
        return last
    }

    public func redo() -> Commit? {
        guard let last = redoStack.popLast() else { return nil }
        undoStack.append(last)
        commits.append(last)
        return last
    }

    public func commits(for branchID: UUID) -> [Commit] {
        commits.filter { $0.branchID == branchID }.sorted { $0.timestamp > $1.timestamp }
    }
}
