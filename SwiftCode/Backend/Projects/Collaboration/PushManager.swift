import Foundation

public struct PushEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

public enum ConflictResolutionChoice: String, Codable, CaseIterable {
    case local
    case remote
    case manual

    public var displayName: String {
        switch self {
        case .local: return "Keep Local"
        case .remote: return "Use Remote"
        case .manual: return "Manual Merge"
        }
    }
}

public struct BranchConflict: Identifiable, Codable, Equatable {
    public let id: UUID
    public let branchName: String
    public let filePath: String
    public let localChange: String
    public let remoteChange: String

    public init(branchName: String, filePath: String, localChange: String, remoteChange: String) {
        self.id = UUID()
        self.branchName = branchName
        self.filePath = filePath
        self.localChange = localChange
        self.remoteChange = remoteChange
    }
}

public struct PushStatus: Identifiable, Equatable {
    public let id = UUID()
    public let branchName: String
    public let progress: Double
    public let isComplete: Bool
    public let direction: String
}

@MainActor
public final class PushManager: ObservableObject {
    @Published public private(set) var activePushes: [PushStatus] = []
    @Published public private(set) var conflicts: [BranchConflict] = []
    @Published public private(set) var lastEvent: PushEvent?

    public func prepareSync(branchName: String, actorID: String, localCommitCount: Int, remoteCommitCount: Int) -> BranchConflict? {
        guard localCommitCount != remoteCommitCount else { return nil }
        let conflict = BranchConflict(branchName: branchName, filePath: "Sources/Shared/SyncState.swift", localChange: "local: commit count \(localCommitCount)", remoteChange: "remote: commit count \(remoteCommitCount)")
        conflicts.removeAll { $0.branchName == branchName }
        conflicts.append(conflict)
        lastEvent = PushEvent(actorID: actorID, title: "Sync prepared", detail: "Local/remote comparison finished for \(branchName).", notifies: false)
        return conflict
    }

    public func resolveConflict(_ conflictID: UUID, using resolution: ConflictResolutionChoice, actorID: String) {
        conflicts.removeAll { $0.id == conflictID }
        lastEvent = PushEvent(actorID: actorID, title: "Conflict resolution applied", detail: resolution.displayName, notifies: true)
    }

    public func push(branchName: String, actorID: String) async {
        await runTransfer(branchName: branchName, actorID: actorID, direction: "Push")
    }

    public func pull(branchName: String, actorID: String) async {
        await runTransfer(branchName: branchName, actorID: actorID, direction: "Pull")
    }

    private func runTransfer(branchName: String, actorID: String, direction: String) async {
        activePushes.append(PushStatus(branchName: branchName, progress: 0, isComplete: false, direction: direction))
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if let index = activePushes.firstIndex(where: { $0.branchName == branchName && $0.direction == direction }) {
                activePushes[index] = PushStatus(branchName: branchName, progress: Double(i) / 10.0, isComplete: i == 10, direction: direction)
            }
        }
        lastEvent = PushEvent(actorID: actorID, title: "\(direction) complete", detail: "\(branchName) synced successfully.", notifies: true)
        try? await Task.sleep(nanoseconds: 200_000_000)
        activePushes.removeAll { $0.branchName == branchName && $0.direction == direction }
    }
}
