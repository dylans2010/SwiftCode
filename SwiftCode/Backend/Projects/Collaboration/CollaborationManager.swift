import Foundation
import Combine
import UIKit

public struct CollaborationState: Codable {
    let memberRoles: [String: CollaborationRole]
    let branches: [Branch]
    let currentBranch: Branch
    let merges: [BranchMerge]
    let commits: [Commit]
    let reviews: [UUID: CodeReview]
    let pullRequests: [PullRequest]
    let invites: [CollaborationInvite]
    let activityLog: [CollaborationActivity]
    let notifications: [CollaborationNotificationItem]
    let fileLocks: [FileLock]
    let conflicts: [BranchConflict]
}

@MainActor
public final class CollaborationManager: ObservableObject {
    public let projectID: UUID
    public let creatorID: String
    public let projectName: String

    public let permissions: PermissionsManager
    public let branches: BranchManager
    public let commits: CommitManager
    public let sync: PushPullManager
    public let reviews: CodeReviewManager
    public let invites: InviteManager
    public let activity: ActivityLogManager
    public let locks: FileLockManager
    public let conflicts: ConflictResolverManager

    private var cancellables = Set<AnyCancellable>()
    private var stateFileURL: URL?

    public init(projectID: UUID, creatorID: String, projectName: String) {
        self.projectID = projectID
        self.creatorID = creatorID
        self.projectName = projectName

        self.permissions = PermissionsManager(creatorID: creatorID)
        self.branches = BranchManager()
        self.commits = CommitManager()
        self.sync = PushPullManager()
        self.reviews = CodeReviewManager()
        self.invites = InviteManager()
        self.activity = ActivityLogManager()
        self.locks = FileLockManager()
        self.conflicts = ConflictResolverManager()

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let projectsDir = docs.appendingPathComponent("Projects", isDirectory: true)
            let projectDir = projectsDir.appendingPathComponent(projectName)

            // Ensure directory exists
            try? FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

            self.stateFileURL = projectDir.appendingPathComponent(".collaboration.json")
        }

        setupBindings()
        loadState()

        if activity.activityLog.isEmpty {
            addActivity(actorID: creatorID, title: "Collaboration enabled", detail: "Project collaboration workspace is ready.", kind: .permissions, notify: true)
        }
    }

    private func setupBindings() {
        branches.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        commits.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        sync.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        reviews.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        permissions.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        invites.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        activity.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        locks.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        conflicts.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)

        branches.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .branch, notify: event.notifies)
                self?.saveState()
            }
            .store(in: &cancellables)

        commits.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .commit, notify: event.notifies)
                self?.saveState()
            }
            .store(in: &cancellables)

        sync.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .sync, notify: event.notifies)
                self?.saveState()
            }
            .store(in: &cancellables)

        reviews.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                let kind: CollaborationActivity.Kind = event.title.contains("PR") || event.title.contains("Pull Request") ? .pr : .review
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: kind, notify: event.notifies)
                self?.saveState()
            }
            .store(in: &cancellables)

        permissions.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .permissions, notify: event.notifies)
                self?.saveState()
            }
            .store(in: &cancellables)

        invites.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .invite, notify: event.notifies)
                self?.saveState()
            }
            .store(in: &cancellables)

        locks.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .fileLock, notify: event.notifies)
                self?.saveState()
            }
            .store(in: &cancellables)

        conflicts.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .conflict, notify: event.notifies)
                self?.saveState()
            }
            .store(in: &cancellables)

        sync.onReceiveState = { [weak self] state in
            self?.applyReceivedState(state)
        }
    }

    public func commit(message: String, authorID: String, changes: [String: String]) {
        if let commit = commits.recordCommit(branchID: branches.currentBranch.id, authorID: authorID, message: message, changes: changes, permissions: permissions) {
            branches.updateLastCommit(for: branches.currentBranch.id, commitID: commit.id)
            reviews.initiateReview(for: commit.id)
            saveState()
        }
    }

    public func merge(branch sourceID: UUID, into targetID: UUID, actorID: String) {
        if let mergedCommit = commits.merge(branchID: sourceID, into: targetID, authorID: actorID, permissions: permissions) {
            branches.registerMerge(from: sourceID, into: targetID, commitID: mergedCommit.id, actorID: actorID)
            reviews.initiateReview(for: mergedCommit.id)
            saveState()
        }
    }

    public func syncCurrentBranch(actorID: String) async {
        guard permissions.hasPermission(.push, for: actorID, projectPermission: .owner) else { return }
        let state = buildState()
        await sync.push(state: state, actorID: actorID)
        saveState()
    }

    public func resolveConflict(_ conflictID: UUID, using resolution: ConflictResolutionChoice, actorID: String) {
        conflicts.resolveConflict(conflictID, using: resolution, actorID: actorID)
        saveState()
    }

    public func lockFile(path: String, actorID: String) {
        guard permissions.hasPermission(.editFiles, for: actorID, projectPermission: .owner) else { return }
        locks.lockFile(path: path, actorID: actorID)
        saveState()
    }

    public func unlockFile(path: String, actorID: String) {
        let isAdmin = permissions.memberRoles[actorID] == .owner || permissions.memberRoles[actorID] == .admin
        locks.unlockFile(path: path, actorID: actorID, isAdmin: isAdmin)
        saveState()
    }

    public func invite(memberID: String, role: CollaborationRole, actorID: String) {
        guard permissions.canManageMembers(actorID: actorID) else { return }
        invites.createInvite(memberID: memberID, role: role, actorID: actorID)
        _ = permissions.assignRole(role, to: memberID, by: actorID)
        saveState()
    }

    public func createPR(title: String, description: String, sourceBranchID: UUID, targetBranchID: UUID, authorID: String) {
        _ = reviews.createPR(title: title, description: description, sourceBranchID: sourceBranchID, targetBranchID: targetBranchID, authorID: authorID, permissions: permissions)
        saveState()
    }

    public func markNotificationRead(_ notificationID: UUID) {
        activity.markNotificationRead(notificationID)
        saveState()
    }

    public func addActivity(actorID: String, title: String, detail: String, kind: CollaborationActivity.Kind, notify: Bool) {
        activity.addActivity(actorID: actorID, title: title, detail: detail, kind: kind, notify: notify)
    }

    public func undo(actorID: String) {
        commits.undo()
        branches.undo()
        saveState()
    }

    public func redo(actorID: String) {
        commits.redo()
        branches.redo()
        saveState()
    }

    // MARK: - Persistence & Sync

    private func buildState() -> CollaborationState {
        CollaborationState(
            memberRoles: permissions.memberRoles,
            branches: branches.branches,
            currentBranch: branches.currentBranch,
            merges: branches.merges,
            commits: commits.commits,
            reviews: reviews.reviews,
            pullRequests: reviews.pullRequests,
            invites: invites.invites,
            activityLog: activity.activityLog,
            notifications: activity.notifications,
            fileLocks: locks.fileLocks,
            conflicts: conflicts.pendingConflicts
        )
    }

    public func saveState() {
        guard let url = stateFileURL else { return }
        let state = buildState()

        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: url)
        } catch {
            print("Failed to save collaboration state: \(error)")
        }
    }

    public func loadState() {
        guard let url = stateFileURL, FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let state = try JSONDecoder().decode(CollaborationState.self, from: data)
            restoreState(state)
        } catch {
            print("Failed to load collaboration state: \(error)")
        }
    }

    private func restoreState(_ state: CollaborationState) {
        permissions.restore(memberRoles: state.memberRoles)
        branches.restore(branches: state.branches, currentBranch: state.currentBranch, merges: state.merges)
        commits.restore(commits: state.commits)
        reviews.restore(reviews: state.reviews, pullRequests: state.pullRequests)
        invites.restore(invites: state.invites)
        activity.restore(activityLog: state.activityLog, notifications: state.notifications)
        locks.restore(fileLocks: state.fileLocks)
        conflicts.restore(pendingConflicts: state.conflicts)
        objectWillChange.send()
    }

    private func applyReceivedState(_ state: CollaborationState) {
        restoreState(state)
        saveState()
    }
}
