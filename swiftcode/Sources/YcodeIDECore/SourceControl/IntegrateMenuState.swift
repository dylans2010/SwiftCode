import Foundation

public struct IntegrateMenuState: Equatable, Sendable {
    public var hasRepository = false
    public var hasRemote = false
    public var hasUnstaged = false
    public var hasStaged = false
    public var selectedStatus: GitRepository.FileStatus?
    public var selectedIsStaged = false
    public var selectedFileExists = false
    public var selectedCommit: String?
    public var integration: GitRepository.IntegrationState = .none
    public var conflictCount = 0
    public var otherBranchCount = 0
    public var unpushedCommitCount = 0
    public var behindCommitCount = 0
    public var isUpToDate = false

    public init() {}

    public var hasChanges: Bool { hasUnstaged || hasStaged }

    public func isEnabled(_ action: String) -> Bool {
        
        guard hasRepository else {
            if action == "scmClone:" { return true }
            if action == "scmNewRepository:" { return true }
            return false
        }

        switch action {
        case "showCommitSheet:":
            
            return hasChanges
        case "scmPush:":
            
            return hasRemote && unpushedCommitCount > 0
        case "scmPull:", "scmFetch:":
            return hasRemote
        case "refreshFileStatus:":
            return true
        case "scmStageAll:":
            
            return hasUnstaged
        case "scmUnstageAll:":
            return hasStaged
        case "scmStageSelected:":
            return selectedStatus != nil && selectedStatus != .untracked
        case "scmUnstageSelected:":
            return selectedIsStaged
        case "scmMarkResolved:":
            return selectedStatus == .conflicted
        case "scmAddSelected:":
            return selectedStatus == .untracked
        case "scmCherryPick:":
            return selectedCommit != nil
        case "scmMerge:":
            return !integration.isInProgress && otherBranchCount > 0
        case "scmStash:", "scmDiscardAll:":
            return hasChanges
        case "scmTrashSelected:":
            return selectedFileExists
        case "scmClone:":
            return true
        case "scmNewRepository:":
            return false
        case "scmResolveConflicts:":
            return conflictCount > 0
        case "scmContinueIntegration:":
            return integration.isInProgress && conflictCount == 0
        case "scmAbortIntegration:":
            return integration.isInProgress
        default:
            return true
        }
    }

    public static let actions = ["showCommitSheet:", "scmPush:", "scmPull:", "scmFetch:", "refreshFileStatus:", "scmStageAll:",
                                 "scmStageSelected:", "scmUnstageAll:", "scmUnstageSelected:", "scmMarkResolved:", "scmAddSelected:",
                                 "scmCherryPick:", "scmMerge:", "scmStash:", "scmDiscardAll:", "scmTrashSelected:", "scmClone:", "scmNewRepository:",
                                 "scmResolveConflicts:", "scmContinueIntegration:", "scmAbortIntegration:"]
}
