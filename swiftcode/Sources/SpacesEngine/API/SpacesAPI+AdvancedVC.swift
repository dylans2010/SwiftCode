import Foundation

extension SpacesAPI {
    @discardableResult
    public func multiRepoCommit(repos: [URL], message: String, allowEmpty: Bool = false) throws -> MultiRepoCommitOps.MultiRepoCommitResult {
        try MultiRepoCommitOps(repo: repo).multiRepoCommit(repos: repos, message: message, allowEmpty: allowEmpty)
    }

    public func multiRepoRecover(tx: String) throws -> MultiRepoCommitOps.MultiRepoRecoveryReport {
        try MultiRepoCommitOps(repo: repo).multiRepoRecover(tx: tx)
    }

    @discardableResult
    public func createBranchCheckpoint(branch: String, name: String) throws -> ObjectID {
        try BranchCheckpointOps(repo: repo).create(branch: branch, name: name)
    }

    public func branchCheckpoints(branch: String) throws -> [BranchCheckpointOps.CheckpointInfo] {
        try BranchCheckpointOps(repo: repo).list(branch: branch)
    }

    public func restoreBranchCheckpoint(branch: String, name: String) throws {
        try BranchCheckpointOps(repo: repo).restore(branch: branch, name: name)
    }

    public func branchStates(branch: String, limit: Int = 50) throws -> [BranchTimeTravelOps.BranchState] {
        try BranchTimeTravelOps(repo: repo).states(branch: branch, limit: limit)
    }

    @discardableResult
    public func timeTravelBranch(branch: String, to: String, force: Bool = false) throws -> ObjectID {
        try BranchTimeTravelOps(repo: repo).timeTravel(branch: branch, to: to, force: force)
    }

    @discardableResult
    public func createBranchStack(name: String, branches: [String], base: String) throws -> BranchStackOps.StackRecord {
        try BranchStackOps(repo: repo).createStack(name: name, branches: branches, base: base)
    }

    public func branchStacks() throws -> [BranchStackOps.StackRecord] {
        try BranchStackOps(repo: repo).stacks()
    }

    public func branchStackStatus(name: String) throws -> BranchStackOps.StackStatus {
        try BranchStackOps(repo: repo).stackStatus(name: name)
    }

    @discardableResult
    public func updateBranchStack(name: String, branches: [String]) throws -> BranchStackOps.StackRecord {
        try BranchStackOps(repo: repo).updateStack(name: name, branches: branches)
    }

    @discardableResult
    public func createChangeSet(name: String, description: String) throws -> ChangeSetOps.ChangeSetRecord {
        try ChangeSetOps(repo: repo).createChangeSet(name: name, description: description)
    }

    public func changeSets() throws -> [ChangeSetOps.ChangeSetRecord] {
        try ChangeSetOps(repo: repo).changeSets()
    }

    public func changeSetPaths(id: String) throws -> [String] {
        try ChangeSetOps(repo: repo).changeSetPaths(id: id)
    }

    @discardableResult
    public func addToChangeSet(id: String, path: String) throws -> ChangeSetOps.ChangeSetRecord {
        try ChangeSetOps(repo: repo).addToChangeSet(id: id, path: path)
    }

    @discardableResult
    public func stageChangeSet(id: String) throws -> [String] {
        try ChangeSetOps(repo: repo).stageChangeSet(id: id)
    }

    @discardableResult
    public func partialRestore(rev: String, paths: [String]) throws -> [String] {
        try PartialRestoreOps(repo: repo).restoreFrom(rev: rev, paths: paths)
    }

    @discardableResult
    public func addCommitDependency(from: String, to: String, kind: CommitGraphOps.DependencyKind) throws -> CommitGraphOps.Dependency {
        try CommitGraphOps(repo: repo).addDependency(from: from, to: to, kind: kind)
    }

    public func commitDependencies(of rev: String) throws -> [CommitGraphOps.Dependency] {
        try CommitGraphOps(repo: repo).dependencies(of: rev)
    }

    public func commitDependents(of rev: String) throws -> [CommitGraphOps.Dependency] {
        try CommitGraphOps(repo: repo).dependents(of: rev)
    }

    public func commitPolicies() throws -> [ValidationPolicyOps.PolicyRule] {
        try ValidationPolicyOps(repo: repo).commitPolicies()
    }

    public func setCommitPolicies(_ rules: [ValidationPolicyOps.PolicyRule]) throws {
        try ValidationPolicyOps(repo: repo).setCommitPolicies(rules)
    }

    public func validateCommit(message: String) throws -> [ValidationPolicyOps.PolicyViolation] {
        let staged = try status().staged.map { $0.path }
        return try ValidationPolicyOps(repo: repo).validateCommit(message: message, stagedPaths: staged)
    }

    @discardableResult
    public func commitValidated(message: String) throws -> StagingOps.CommitResult {
        let violations = try validateCommit(message: message)
        guard violations.isEmpty else {
            throw SpacesError.invalidArgument("commit blocked by policy: \(violations.map { $0.message }.joined(separator: "; "))")
        }
        return try commit(message: message)
    }

    @discardableResult
    public func prepareCommit(message: String, paths: [String]) throws -> String {
        try MultiStageCommitOps(repo: repo).prepare(message: message, paths: paths)
    }

    @discardableResult
    public func validateStagedCommit(tx: String) throws -> [ValidationPolicyOps.PolicyViolation] {
        try MultiStageCommitOps(repo: repo).validate(tx: tx)
    }

    @discardableResult
    public func previewStagedCommit(tx: String) throws -> MultiStageCommitOps.StagePreview {
        try MultiStageCommitOps(repo: repo).preview(tx: tx)
    }

    @discardableResult
    public func finalizeStagedCommit(tx: String) throws -> ObjectID {
        try MultiStageCommitOps(repo: repo).finalize(tx: tx)
    }

    public func abortStagedCommit(tx: String) throws {
        try MultiStageCommitOps(repo: repo).abort(tx: tx)
    }

    public func undoableOperations() throws -> [OperationUndoOps.UndoRecord] {
        try OperationUndoOps(repo: repo).undoableOperations()
    }

    @discardableResult
    public func undoLast() throws -> OperationUndoOps.UndoRecord {
        try OperationUndoOps(repo: repo).undoLast()
    }

    @discardableResult
    public func createBranchUndoable(name: String, at rev: String = "HEAD") throws -> ObjectID {
        try OperationUndoOps(repo: repo).createBranchUndoable(name: name, at: rev)
    }

    public func deleteBranchUndoable(name: String, force: Bool = false) throws {
        try OperationUndoOps(repo: repo).deleteBranchUndoable(name: name, force: force)
    }

    @discardableResult
    public func createTagUndoable(name: String, at rev: String = "HEAD", annotated: Bool = false, message: String = "") throws -> ObjectID {
        try OperationUndoOps(repo: repo).createTagUndoable(name: name, at: rev, annotated: annotated, message: message)
    }

    public func deleteTagUndoable(name: String) throws {
        try OperationUndoOps(repo: repo).deleteTagUndoable(name: name)
    }

    @discardableResult
    public func createSnapshotUndoable(message: String) throws -> ObjectID {
        try OperationUndoOps(repo: repo).createSnapshotUndoable(message: message)
    }

    @discardableResult
    public func createStashUndoable(message: String? = nil) throws -> StashOps.StashEntry {
        try OperationUndoOps(repo: repo).createStashUndoable(message: message)
    }
}
