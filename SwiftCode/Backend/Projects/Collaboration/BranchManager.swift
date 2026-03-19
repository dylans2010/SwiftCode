import Foundation

public struct Branch: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var lastCommitID: UUID?

    public init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

@MainActor
public final class BranchManager: ObservableObject {
    @Published public private(set) var branches: [Branch] = []
    @Published public private(set) var currentBranch: Branch

    public init(mainBranchName: String = "main") {
        let main = Branch(name: mainBranchName)
        self.branches = [main]
        self.currentBranch = main
    }

    public func createBranch(name: String) -> Branch {
        let newBranch = Branch(name: name)
        branches.append(newBranch)
        return newBranch
    }

    public func switchBranch(to branchID: UUID) {
        if let branch = branches.first(where: { $0.id == branchID }) {
            currentBranch = branch
        }
    }

    public func deleteBranch(_ branchID: UUID) {
        guard branches.count > 1 else { return }
        if currentBranch.id == branchID {
            currentBranch = branches.first { $0.id != branchID }!
        }
        branches.removeAll { $0.id == branchID }
    }

    public func renameBranch(_ branchID: UUID, to newName: String) {
        if let index = branches.firstIndex(where: { $0.id == branchID }) {
            branches[index].name = newName
            if currentBranch.id == branchID {
                currentBranch.name = newName
            }
        }
    }

    public func updateLastCommit(for branchID: UUID, commitID: UUID) {
        if let index = branches.firstIndex(where: { $0.id == branchID }) {
            branches[index].lastCommitID = commitID
            if currentBranch.id == branchID {
                currentBranch.lastCommitID = commitID
            }
        }
    }
}
