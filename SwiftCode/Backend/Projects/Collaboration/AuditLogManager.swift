import Foundation
import Combine

public struct AuditLogEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let actorID: String
    public let action: String
    public let detail: String
    public let type: CollaborationActivity.Kind

    public init(actorID: String, action: String, detail: String, type: CollaborationActivity.Kind) {
        self.id = UUID()
        self.timestamp = Date()
        self.actorID = actorID
        self.action = action
        self.detail = detail
        self.type = type
    }
}

@MainActor
public final class AuditLogManager: ObservableObject {
    @Published public private(set) var entries: [AuditLogEntry] = []

    public func log(actorID: String, action: String, detail: String, type: CollaborationActivity.Kind) {
        let entry = AuditLogEntry(actorID: actorID, action: action, detail: detail, type: type)
        entries.insert(entry, at: 0)

        if entries.count > 500 {
            entries.removeLast()
        }
    }

    public func filteredEntries(byActor actorID: String? = nil, byType type: CollaborationActivity.Kind? = nil) -> [AuditLogEntry] {
        entries.filter { entry in
            let actorMatch = actorID == nil || entry.actorID == actorID
            let typeMatch = type == nil || entry.type == type
            return actorMatch && typeMatch
        }
    }
}
