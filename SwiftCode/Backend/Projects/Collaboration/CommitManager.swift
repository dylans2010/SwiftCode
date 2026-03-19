import Foundation

public struct CommitEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

public struct Commit: Identifiable, Codable, Equatable {
    public let id: UUID
    public let branchID: UUID
    public let authorID: String
    public let message: String
    public let timestamp: Date
    public let changes: [String: String]
    public let parentCommitID: UUID?
    public let mergedFromBranchID: UUID?

    public init(branchID: UUID, authorID: String, message: String, changes: [String: String], parentCommitID: UUID? = nil, mergedFromBranchID: UUID? = nil) {
        self.id = UUID()
        self.branchID = branchID
        self.authorID = authorID
        self.message = message
        self.timestamp = Date()
        self.changes = changes
        self.parentCommitID = parentCommitID
        self.mergedFromBranchID = mergedFromBranchID
    }
}

@MainActor
public final class CommitManager: ObservableObject {
    @Published public private(set) var commits: [Commit] = []
    @Published public private(set) var stagedChanges: [String: String] = [:]
    @Published public private(set) var lastEvent: CommitEvent?

    private var undoStack: [Commit] = []
    private var redoStack: [Commit] = []

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public init() {}

    public func restore(commits: [Commit]) {
        self.commits = commits
    }

    public func stage(path: String, diff: String, actorID: String, permissions: PermissionsManager? = nil) {
        if let permissions = permissions {
             guard permissions.hasPermission(.editFiles, for: actorID, projectPermission: .owner) else { return }
        }
        stagedChanges[path] = diff
    }

    public func unstage(path: String) {
        stagedChanges.removeValue(forKey: path)
    }

    public func recordCommit(branchID: UUID, authorID: String, message: String, changes: [String: String], permissions: PermissionsManager? = nil) -> Commit? {
        if let permissions = permissions {
             guard permissions.hasPermission(.commit, for: authorID, projectPermission: .owner) else { return nil }
        }

        let parent = commits(for: branchID).first?.id
        let payload = changes.isEmpty ? stagedChanges : changes
        let commit = Commit(branchID: branchID, authorID: authorID, message: message, changes: payload, parentCommitID: parent)
        commits.append(commit)
        undoStack.append(commit)
        redoStack.removeAll()
        stagedChanges.removeAll()
        lastEvent = CommitEvent(actorID: authorID, title: "Commit created", detail: message, notifies: true)
        return commit
    }

    public func merge(branchID sourceID: UUID, into targetID: UUID, authorID: String, permissions: PermissionsManager? = nil) -> Commit? {
        if let permissions = permissions {
             guard permissions.hasPermission(.merge, for: actorID, projectPermission: .owner) else { return nil }
        }

        let sourceCommits = commits(for: sourceID)
        guard sourceCommits.isEmpty == false else { return nil }
        let combinedChanges = sourceCommits.reduce(into: [String: String]()) { partialResult, commit in
            commit.changes.forEach { partialResult[$0.key] = $0.value }
        }
        let commit = Commit(branchID: targetID, authorID: authorID, message: "Merge branch changes", changes: combinedChanges, parentCommitID: commits(for: targetID).first?.id, mergedFromBranchID: sourceID)
        commits.append(commit)
        undoStack.append(commit)
        redoStack.removeAll()
        lastEvent = CommitEvent(actorID: authorID, title: "Merge commit created", detail: "Merged \(sourceCommits.count) commits into target branch.", notifies: true)
        return commit
    }

    public func undo() -> Commit? {
        guard let last = undoStack.popLast() else { return nil }
        redoStack.append(last)
        commits.removeAll { $0.id == last.id }
        lastEvent = CommitEvent(actorID: last.authorID, title: "Commit undone", detail: last.message, notifies: true)
        return last
    }

    public func redo() -> Commit? {
        guard let last = redoStack.popLast() else { return nil }
        undoStack.append(last)
        commits.append(last)
        lastEvent = CommitEvent(actorID: last.authorID, title: "Commit restored", detail: last.message, notifies: true)
        return last
    }

    public func commits(for branchID: UUID) -> [Commit] {
        commits.filter { $0.branchID == branchID }.sorted { $0.timestamp > $1.timestamp }
    }
}
