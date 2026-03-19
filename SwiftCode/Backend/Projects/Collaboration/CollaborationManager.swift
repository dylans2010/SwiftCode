import Foundation
import Combine

@MainActor
public final class CollaborationManager: ObservableObject {
    public let projectID: UUID
    public let permissions: PermissionsManager
    public let branches: BranchManager
    public let commits: CommitManager
    public let pushes: PushManager
    public let reviews: CodeReviewManager

    private var cancellables = Set<AnyCancellable>()

    public init(projectID: UUID, creatorID: String) {
        self.projectID = projectID
        self.permissions = PermissionsManager(creatorID: creatorID)
        self.branches = BranchManager()
        self.commits = CommitManager()
        self.pushes = PushManager()
        self.reviews = CodeReviewManager()

        setupBindings()
    }

    private func setupBindings() {
        // Coordinate between managers if needed
        branches.$currentBranch
            .sink { _ in
                // Handle branch switch effects
            }
            .store(in: &cancellables)
    }

    public func commit(message: String, authorID: String, changes: [String: String]) {
        guard permissions.hasPermission(.commit, for: authorID, projectPermission: TransferPermission.owner) else { return }
        let commit = commits.recordCommit(branchID: branches.currentBranch.id, authorID: authorID, message: message, changes: changes)
        branches.updateLastCommit(for: branches.currentBranch.id, commitID: commit.id)
    }
}
