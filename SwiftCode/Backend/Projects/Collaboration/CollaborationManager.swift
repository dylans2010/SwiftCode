import Foundation
import Combine

public struct CollaborationActivity: Identifiable, Codable, Equatable {
    public enum Kind: String, Codable {
        case branch
        case commit
        case review
        case sync
        case invite
        case permissions
        case conflict
        case fileLock
    }

    public let id: UUID
    public let timestamp: Date
    public let actorID: String
    public let title: String
    public let detail: String
    public let kind: Kind

    public init(actorID: String, title: String, detail: String, kind: Kind, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.actorID = actorID
        self.title = title
        self.detail = detail
        self.kind = kind
    }
}

public struct CollaborationNotificationItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let timestamp: Date
    public var isRead: Bool

    public init(title: String, detail: String, timestamp: Date = Date(), isRead: Bool = false) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.timestamp = timestamp
        self.isRead = isRead
    }
}

@MainActor
public final class CollaborationManager: ObservableObject {
    public let projectID: UUID
    public let creatorID: String
    public let permissions: PermissionsManager
    public let branches: BranchManager
    public let commits: CommitManager
    public let pushes: PushManager
    public let reviews: CodeReviewManager
    public let invites: InviteManager

    @Published public private(set) var activityLog: [CollaborationActivity] = []
    @Published public private(set) var notifications: [CollaborationNotificationItem] = []
    @Published public private(set) var pendingConflicts: [BranchConflict] = []
    @Published public private(set) var fileLocks: [FileLock] = []

    private var cancellables = Set<AnyCancellable>()

    public init(projectID: UUID, creatorID: String) {
        self.projectID = projectID
        self.creatorID = creatorID
        self.permissions = PermissionsManager(creatorID: creatorID)
        self.branches = BranchManager()
        self.commits = CommitManager()
        self.pushes = PushManager()
        self.reviews = CodeReviewManager()
        self.invites = InviteManager()

        setupBindings()
        addActivity(actorID: creatorID, title: "Collaboration enabled", detail: "Project collaboration workspace is ready.", kind: .permissions, notify: true)
    }

    private func setupBindings() {
        branches.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .branch, notify: event.notifies)
            }
            .store(in: &cancellables)

        commits.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .commit, notify: event.notifies)
            }
            .store(in: &cancellables)

        pushes.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .sync, notify: event.notifies)
            }
            .store(in: &cancellables)

        reviews.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .review, notify: event.notifies)
            }
            .store(in: &cancellables)

        permissions.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .permissions, notify: event.notifies)
            }
            .store(in: &cancellables)

        invites.$lastEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.addActivity(actorID: event.actorID, title: event.title, detail: event.detail, kind: .invite, notify: event.notifies)
            }
            .store(in: &cancellables)
    }

    public func commit(message: String, authorID: String, changes: [String: String]) {
        guard permissions.hasPermission(.commit, for: authorID, projectPermission: .owner) else { return }
        let commit = commits.recordCommit(branchID: branches.currentBranch.id, authorID: authorID, message: message, changes: changes)
        branches.updateLastCommit(for: branches.currentBranch.id, commitID: commit.id)
        reviews.initiateReview(for: commit.id)
    }

    public func merge(branch sourceID: UUID, into targetID: UUID, actorID: String) {
        guard permissions.hasPermission(.merge, for: actorID, projectPermission: .owner) else { return }
        if let mergedCommit = commits.merge(branchID: sourceID, into: targetID, authorID: actorID) {
            branches.registerMerge(from: sourceID, into: targetID, commitID: mergedCommit.id, actorID: actorID)
            reviews.initiateReview(for: mergedCommit.id)
        }
    }

    public func syncCurrentBranch(actorID: String) async {
        guard permissions.hasPermission(.push, for: actorID, projectPermission: .owner) else { return }
        let branchName = branches.currentBranch.name
        let localCommits = commits.commits(for: branches.currentBranch.id).count
        let remoteCommits = max(0, localCommits - 1)
        let conflict = pushes.prepareSync(branchName: branchName, actorID: actorID, localCommitCount: localCommits, remoteCommitCount: remoteCommits)
        if let conflict {
            pendingConflicts.removeAll { $0.id == conflict.id }
            pendingConflicts.append(conflict)
            addActivity(actorID: actorID, title: "Conflict detected", detail: "\(conflict.filePath) requires resolution on \(branchName).", kind: .conflict, notify: true)
        }
        await pushes.push(branchName: branchName, actorID: actorID)
        await pushes.pull(branchName: branchName, actorID: actorID)
    }

    public func resolveConflict(_ conflictID: UUID, using resolution: ConflictResolutionChoice, actorID: String) {
        guard let index = pendingConflicts.firstIndex(where: { $0.id == conflictID }) else { return }
        let conflict = pendingConflicts.remove(at: index)
        pushes.resolveConflict(conflictID, using: resolution, actorID: actorID)
        addActivity(actorID: actorID, title: "Conflict resolved", detail: "Resolved \(conflict.filePath) using \(resolution.displayName).", kind: .conflict, notify: true)
    }

    public func lockFile(path: String, actorID: String) {
        guard permissions.hasPermission(.editFiles, for: actorID, projectPermission: .owner) else { return }
        guard fileLocks.contains(where: { $0.path == path }) == false else { return }
        let lock = FileLock(path: path, lockedBy: actorID)
        fileLocks.append(lock)
        addActivity(actorID: actorID, title: "File locked", detail: "\(path) is now locked for editing.", kind: .fileLock, notify: true)
    }

    public func unlockFile(path: String, actorID: String) {
        guard let index = fileLocks.firstIndex(where: { $0.path == path }) else { return }
        let lock = fileLocks[index]
        guard lock.lockedBy == actorID || permissions.memberRoles[actorID] == .owner || permissions.memberRoles[actorID] == .admin else { return }
        fileLocks.remove(at: index)
        addActivity(actorID: actorID, title: "File unlocked", detail: "\(path) is available for collaborators again.", kind: .fileLock, notify: false)
    }

    public func invite(memberID: String, role: CollaborationRole, actorID: String) {
        guard permissions.canManageMembers(actorID: actorID) else { return }
        invites.createInvite(memberID: memberID, role: role, actorID: actorID)
        permissions.assignRole(role, to: memberID, by: actorID)
    }

    public func markNotificationRead(_ notificationID: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationID }) else { return }
        notifications[index].isRead = true
    }

    public func addActivity(actorID: String, title: String, detail: String, kind: CollaborationActivity.Kind, notify: Bool) {
        let activity = CollaborationActivity(actorID: actorID, title: title, detail: detail, kind: kind)
        activityLog.insert(activity, at: 0)
        if notify {
            notifications.insert(CollaborationNotificationItem(title: title, detail: detail), at: 0)
        }
    }
}
