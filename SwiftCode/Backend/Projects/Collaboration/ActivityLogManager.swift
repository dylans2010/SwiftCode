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
        case pr
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
public final class ActivityLogManager: ObservableObject {
    @Published public private(set) var activityLog: [CollaborationActivity] = []
    @Published public private(set) var notifications: [CollaborationNotificationItem] = []

    public init() {}

    public func restore(activityLog: [CollaborationActivity], notifications: [CollaborationNotificationItem]) {
        self.activityLog = activityLog
        self.notifications = notifications
    }

    public func addActivity(actorID: String, title: String, detail: String, kind: CollaborationActivity.Kind, notify: Bool) {
        let activity = CollaborationActivity(actorID: actorID, title: title, detail: detail, kind: kind)
        activityLog.insert(activity, at: 0)

        if notify {
            let notification = CollaborationNotificationItem(title: title, detail: detail)
            notifications.insert(notification, at: 0)
        }
    }

    public func markNotificationRead(_ notificationID: UUID) {
        if let index = notifications.firstIndex(where: { $0.id == notificationID }) {
            notifications[index].isRead = true
        }
    }

    public func clearAll() {
        activityLog.removeAll()
        notifications.removeAll()
    }
}
