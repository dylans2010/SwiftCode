import Foundation
import Combine

public struct UserPresence: Identifiable, Codable {
    public let id: String // actorID
    public let name: String
    public var activeFile: String?
    public var lastSeen: Date
    public var cursorPosition: Int? // Character index

    public init(id: String, name: String, activeFile: String? = nil, cursorPosition: Int? = nil) {
        self.id = id
        self.name = name
        self.activeFile = activeFile
        self.lastSeen = Date()
        self.cursorPosition = cursorPosition
    }
}

@MainActor
public final class PresenceManager: ObservableObject {
    @Published public private(set) var activeUsers: [String: UserPresence] = [:]

    private var cleanupTimer: Timer?

    public init() {
        startCleanupTimer()
    }

    public func updatePresence(actorID: String, name: String, file: String? = nil, cursor: Int? = nil) {
        let presence = UserPresence(id: actorID, name: name, activeFile: file, cursorPosition: cursor)
        activeUsers[actorID] = presence
    }

    public func usersInFile(_ path: String) -> [UserPresence] {
        activeUsers.values.filter { $0.activeFile == path }
    }

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupInactiveUsers()
            }
        }
    }

    private func cleanupInactiveUsers() {
        let now = Date()
        let timeout: TimeInterval = 30 // 30 seconds of inactivity

        let inactiveIDs = activeUsers.values
            .filter { now.timeIntervalSince($0.lastSeen) > timeout }
            .map { $0.id }

        for id in inactiveIDs {
            activeUsers.removeValue(forKey: id)
        }
    }
}
