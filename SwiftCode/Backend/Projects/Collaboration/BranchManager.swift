import Foundation

public struct BranchEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

public struct BranchMerge: Identifiable, Codable, Equatable {
    public let id: UUID
    public let sourceBranchID: UUID
    public let targetBranchID: UUID
    public let commitID: UUID
    public let timestamp: Date

    public init(sourceBranchID: UUID, targetBranchID: UUID, commitID: UUID) {
        self.id = UUID()
        self.sourceBranchID = sourceBranchID
        self.targetBranchID = targetBranchID
        self.commitID = commitID
        self.timestamp = Date()
    }
}

public struct Branch: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var lastCommitID: UUID?
    public let createdAt: Date

    public init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

public enum BranchAction {
    case create(Branch)
    case delete(Branch)
    case rename(UUID, String, String)
}

@MainActor
public final class BranchManager: ObservableObject {
    @Published public private(set) var branches: [Branch] = []
    @Published public private(set) var currentBranch: Branch
    @Published public private(set) var merges: [BranchMerge] = []
    @Published public private(set) var lastEvent: BranchEvent?

    private var undoStack: [BranchAction] = []
    private var redoStack: [BranchAction] = []

    public init(mainBranchName: String = "main") {
        let main = Branch(name: mainBranchName)
        self.branches = [main]
        self.currentBranch = main
    }

    public func restore(branches: [Branch], currentBranch: Branch, merges: [BranchMerge]) {
        self.branches = branches
        self.currentBranch = currentBranch
        self.merges = merges
    }

    public func createBranch(name: String, actorID: String = "System", permissions: PermissionsManager? = nil) -> Branch? {
        if let permissions = permissions {
             guard permissions.hasPermission(.branchCreateDelete, for: actorID, projectPermission: .owner) else { return nil }
        }

        let newBranch = Branch(name: name)
        branches.append(newBranch)
        undoStack.append(.create(newBranch))
        redoStack.removeAll()
        lastEvent = BranchEvent(actorID: actorID, title: "Branch created", detail: "\(name) was created.", notifies: true)
        return newBranch
    }

    public func switchBranch(to branchID: UUID, actorID: String = "System") {
        if let branch = branches.first(where: { $0.id == branchID }) {
            currentBranch = branch
            lastEvent = BranchEvent(actorID: actorID, title: "Branch switched", detail: "Now working on \(branch.name).", notifies: false)
        }
    }

    public func deleteBranch(_ branchID: UUID, actorID: String = "System", permissions: PermissionsManager? = nil) {
        if let permissions = permissions {
             guard permissions.hasPermission(.branchCreateDelete, for: actorID, projectPermission: .owner) else { return }
        }

        guard branches.count > 1 else { return }
        guard let branch = branches.first(where: { $0.id == branchID }) else { return }

        undoStack.append(.delete(branch))
        redoStack.removeAll()

        if currentBranch.id == branchID, let fallback = branches.first(where: { $0.id != branchID }) {
            currentBranch = fallback
        }
        branches.removeAll { $0.id == branchID }
        merges.removeAll { $0.sourceBranchID == branchID || $0.targetBranchID == branchID }
        lastEvent = BranchEvent(actorID: actorID, title: "Branch deleted", detail: "\(branch.name) was removed.", notifies: true)
    }

    public func renameBranch(_ branchID: UUID, to newName: String, actorID: String = "System", permissions: PermissionsManager? = nil) {
        if let permissions = permissions {
             guard permissions.hasPermission(.renameFiles, for: actorID, projectPermission: .owner) else { return }
        }

        if let index = branches.firstIndex(where: { $0.id == branchID }) {
            let oldName = branches[index].name
            undoStack.append(.rename(branchID, oldName, newName))
            redoStack.removeAll()

            branches[index].name = newName
            if currentBranch.id == branchID { currentBranch = branches[index] }
            lastEvent = BranchEvent(actorID: actorID, title: "Branch renamed", detail: "\(oldName) is now \(newName).", notifies: false)
        }
    }

    public func undo() {
        guard let action = undoStack.popLast() else { return }
        redoStack.append(action)
        applyAction(action, reverse: true)
    }

    public func redo() {
        guard let action = redoStack.popLast() else { return }
        undoStack.append(action)
        applyAction(action, reverse: false)
    }

    private func applyAction(_ action: BranchAction, reverse: Bool) {
        switch action {
        case .create(let branch):
            if reverse { branches.removeAll { $0.id == branch.id } }
            else { branches.append(branch) }
        case .delete(let branch):
            if reverse { branches.append(branch) }
            else { branches.removeAll { $0.id == branch.id } }
        case .rename(let id, let old, let new):
            if let index = branches.firstIndex(where: { $0.id == id }) {
                branches[index].name = reverse ? old : new
                if currentBranch.id == id { currentBranch = branches[index] }
            }
        }
    }

    public func updateLastCommit(for branchID: UUID, commitID: UUID) {
        if let index = branches.firstIndex(where: { $0.id == branchID }) {
            branches[index].lastCommitID = commitID
            if currentBranch.id == branchID { currentBranch = branches[index] }
        }
    }

    public func registerMerge(from sourceID: UUID, into targetID: UUID, commitID: UUID, actorID: String) {
        updateLastCommit(for: targetID, commitID: commitID)
        let merge = BranchMerge(sourceBranchID: sourceID, targetBranchID: targetID, commitID: commitID)
        merges.insert(merge, at: 0)
        let sourceName = branches.first(where: { $0.id == sourceID })?.name ?? "source"
        let targetName = branches.first(where: { $0.id == targetID })?.name ?? "target"
        lastEvent = BranchEvent(actorID: actorID, title: "Branches merged", detail: "Merged \(sourceName) into \(targetName).", notifies: true)
    }
}
