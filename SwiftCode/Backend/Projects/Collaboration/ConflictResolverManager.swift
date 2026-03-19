import Foundation
import Combine

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
    public let timestamp: Date

    public init(branchName: String, filePath: String, localChange: String, remoteChange: String) {
        self.id = UUID()
        self.branchName = branchName
        self.filePath = filePath
        self.localChange = localChange
        self.remoteChange = remoteChange
        self.timestamp = Date()
    }
}

public struct ConflictEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

@MainActor
public final class ConflictResolverManager: ObservableObject {
    @Published public private(set) var pendingConflicts: [BranchConflict] = []
    @Published public private(set) var lastEvent: ConflictEvent?

    public init() {}

    public func restore(pendingConflicts: [BranchConflict]) {
        self.pendingConflicts = pendingConflicts
    }

    public func addConflict(branchName: String, filePath: String, localChange: String, remoteChange: String, actorID: String) -> BranchConflict {
        let conflict = BranchConflict(branchName: branchName, filePath: filePath, localChange: localChange, remoteChange: remoteChange)
        pendingConflicts.append(conflict)
        lastEvent = ConflictEvent(actorID: actorID, title: "Conflict detected", detail: "\(filePath) requires resolution on \(branchName).", notifies: true)
        return conflict
    }

    public func resolveConflict(_ conflictID: UUID, using resolution: ConflictResolutionChoice, actorID: String) {
        guard let index = pendingConflicts.firstIndex(where: { $0.id == conflictID }) else { return }
        let conflict = pendingConflicts.remove(at: index)
        lastEvent = ConflictEvent(actorID: actorID, title: "Conflict resolved", detail: "Resolved \(conflict.filePath) using \(resolution.displayName).", notifies: true)
    }

    public func clearConflicts(for branchName: String) {
        pendingConflicts.removeAll { $0.branchName == branchName }
    }
}
