import Foundation
import Combine

public struct FileLock: Identifiable, Codable, Equatable {
    public let id: UUID
    public let path: String
    public let lockedBy: String
    public let timestamp: Date

    public init(path: String, lockedBy: String) {
        self.id = UUID()
        self.path = path
        self.lockedBy = lockedBy
        self.timestamp = Date()
    }
}

public struct FileLockEvent: Equatable {
    public let actorID: String
    public let title: String
    public let detail: String
    public let notifies: Bool
}

@MainActor
public final class FileLockManager: ObservableObject {
    @Published public private(set) var fileLocks: [FileLock] = []
    @Published public private(set) var lastEvent: FileLockEvent?

    public init() {}

    public func restore(fileLocks: [FileLock]) {
        self.fileLocks = fileLocks
    }

    public func lockFile(path: String, actorID: String) {
        guard !fileLocks.contains(where: { $0.path == path }) else { return }
        let lock = FileLock(path: path, lockedBy: actorID)
        fileLocks.append(lock)
        lastEvent = FileLockEvent(actorID: actorID, title: "File locked", detail: "\(path) is now locked for editing.", notifies: true)
    }

    public func unlockFile(path: String, actorID: String, isAdmin: Bool = false) {
        guard let index = fileLocks.firstIndex(where: { $0.path == path }) else { return }
        let lock = fileLocks[index]

        // Only the owner of the lock or an admin can unlock it
        if lock.lockedBy == actorID || isAdmin {
            fileLocks.remove(at: index)
            lastEvent = FileLockEvent(actorID: actorID, title: "File unlocked", detail: "\(path) is available for collaborators again.", notifies: false)
        }
    }

    public func isLocked(path: String) -> Bool {
        fileLocks.contains(where: { $0.path == path })
    }

    public func locker(for path: String) -> String? {
        fileLocks.first(where: { $0.path == path })?.lockedBy
    }
}
