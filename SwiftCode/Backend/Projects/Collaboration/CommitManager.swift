import Foundation

public struct CommitEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

public enum CommitChangeKind: String, Codable, CaseIterable {
    case added
    case modified
    case deleted
}

public struct CommitFileChange: Identifiable, Codable, Equatable {
    public let id: UUID
    public var path: String
    public var diff: String
    public var kind: CommitChangeKind
    public var isStaged: Bool
    public var authorID: String
    public var timestamp: Date

    public init(path: String, diff: String, kind: CommitChangeKind, isStaged: Bool = true, authorID: String = "System", timestamp: Date = Date()) {
        self.id = UUID()
        self.path = path
        self.diff = diff
        self.kind = kind
        self.isStaged = isStaged
        self.authorID = authorID
        self.timestamp = timestamp
    }
}

public struct Commit: Identifiable, Codable, Equatable {
    public let id: UUID
    public let branchID: UUID
    public var authorID: String
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
    @Published public private(set) var workingChanges: [CommitFileChange] = []
    @Published public private(set) var lastEvent: CommitEvent?

    private var undoStack: [Commit] = []
    private var redoStack: [Commit] = []

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func seedWorkingChangesIfNeeded(authorID: String) {
        guard workingChanges.isEmpty else { return }
        workingChanges = [
            CommitFileChange(path: "Sources/Editor/CollabSession.swift", diff: "@@ -10,3 +10,8 @@\n+ let reviewers = assignedReviewers\n+ session.refresh()", kind: .modified, isStaged: false, authorID: authorID),
            CommitFileChange(path: "Views/Projects/Toolbar.swift", diff: "@@ -1,1 +1,4 @@\n+ Button(\"Collaborate\") { openCollaboration() }", kind: .added, isStaged: false, authorID: authorID),
            CommitFileChange(path: "Docs/OldWorkflow.md", diff: "@@ -1,4 +0,0 @@\n- Legacy workflow guidance", kind: .deleted, isStaged: false, authorID: authorID)
        ]
    }

    public func updateWorkingChange(path: String, diff: String, kind: CommitChangeKind, authorID: String) {
        if let index = workingChanges.firstIndex(where: { $0.path == path }) {
            workingChanges[index].diff = diff
            workingChanges[index].kind = kind
            workingChanges[index].authorID = authorID
            workingChanges[index].timestamp = Date()
        } else {
            workingChanges.append(CommitFileChange(path: path, diff: diff, kind: kind, isStaged: false, authorID: authorID))
        }
    }

    public func stage(path: String, diff: String? = nil, kind: CommitChangeKind? = nil, authorID: String = "System") {
        if let index = workingChanges.firstIndex(where: { $0.path == path }) {
            if let diff { workingChanges[index].diff = diff }
            if let kind { workingChanges[index].kind = kind }
            workingChanges[index].isStaged = true
            stagedChanges[path] = workingChanges[index].diff
        } else {
            let entry = CommitFileChange(path: path, diff: diff ?? "", kind: kind ?? .modified, isStaged: true, authorID: authorID)
            workingChanges.append(entry)
            stagedChanges[path] = entry.diff
        }
        lastEvent = CommitEvent(actorID: authorID, title: "Change staged", detail: path, notifies: false)
    }

    public func unstage(path: String, actorID: String = "System") {
        stagedChanges.removeValue(forKey: path)
        if let index = workingChanges.firstIndex(where: { $0.path == path }) {
            workingChanges[index].isStaged = false
        }
        lastEvent = CommitEvent(actorID: actorID, title: "Change unstaged", detail: path, notifies: false)
    }

    public func recordCommit(branchID: UUID, authorID: String, message: String, changes: [String: String]) -> Commit {
        let parent = commits(for: branchID).first?.id
        let payload = changes.isEmpty ? stagedChanges : changes
        let normalizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Update collaboration changes" : message
        let commit = Commit(branchID: branchID, authorID: authorID, message: normalizedMessage, changes: payload, parentCommitID: parent)
        commits.insert(commit, at: 0)
        undoStack.append(commit)
        redoStack.removeAll()
        let stagedPaths = Set(payload.keys)
        workingChanges.removeAll { stagedPaths.contains($0.path) }
        stagedChanges.removeAll()
        lastEvent = CommitEvent(actorID: authorID, title: "Commit created", detail: normalizedMessage, notifies: true)
        return commit
    }

    public func merge(branchID sourceID: UUID, into targetID: UUID, authorID: String) -> Commit? {
        let sourceCommits = commits(for: sourceID)
        let combinedChanges = sourceCommits.reduce(into: [String: String]()) { partialResult, commit in
            commit.changes.forEach { partialResult[$0.key] = $0.value }
        }
        let commit = Commit(branchID: targetID, authorID: authorID, message: "Merge branch changes", changes: combinedChanges, parentCommitID: commits(for: targetID).first?.id, mergedFromBranchID: sourceID)
        commits.insert(commit, at: 0)
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
        commits.insert(last, at: 0)
        lastEvent = CommitEvent(actorID: last.authorID, title: "Commit restored", detail: last.message, notifies: true)
        return last
    }

    public func revert(commitID: UUID, actorID: String) -> Commit? {
        guard let commit = commits.first(where: { $0.id == commitID }) else { return nil }
        let reverted = commit.changes.reduce(into: [String: String]()) { result, entry in
            let lines = entry.value.split(separator: "\n").map(String.init)
            let reversed = lines.map { line -> String in
                if line.hasPrefix("+") { return "-" + line.dropFirst() }
                if line.hasPrefix("-") { return "+" + line.dropFirst() }
                return line
            }.joined(separator: "\n")
            result[entry.key] = reversed
        }
        let revertCommit = Commit(branchID: commit.branchID, authorID: actorID, message: "Revert \(commit.message)", changes: reverted, parentCommitID: commits(for: commit.branchID).first?.id)
        commits.insert(revertCommit, at: 0)
        undoStack.append(revertCommit)
        redoStack.removeAll()
        lastEvent = CommitEvent(actorID: actorID, title: "Commit reverted", detail: commit.message, notifies: true)
        return revertCommit
    }

    public func restoreState(commits: [Commit]) {
        self.commits = commits.sorted { $0.timestamp > $1.timestamp }
        self.undoStack = Array(self.commits.reversed())
        self.redoStack = []
    }

    public func commits(for branchID: UUID) -> [Commit] {
        commits.filter { $0.branchID == branchID }.sorted { $0.timestamp > $1.timestamp }
    }
}
