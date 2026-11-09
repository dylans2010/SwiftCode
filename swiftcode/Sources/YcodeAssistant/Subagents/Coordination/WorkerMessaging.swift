import Foundation
import os





public struct WorkerMessage: Identifiable, Codable, Sendable, Hashable {
    public enum Recipient: String, Codable, Sendable {
        
        case parent
        
        case broadcast
        
        case worker
    }

    public let id: UUID
    public let sender: String
    public let recipient: Recipient
    
    public let targetWorker: String?
    public let text: String
    public let timestamp: Date

    public init(id: UUID = UUID(), sender: String, recipient: Recipient, targetWorker: String? = nil,
                text: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.recipient = recipient
        self.targetWorker = targetWorker
        self.text = text
        self.timestamp = timestamp
    }

    public var summary: String {
        let dest = recipient == .parent ? "parent" : (targetWorker ?? "broadcast")
        return "\(sender) → \(dest): \(text)"
    }
}





@MainActor
public final class WorkerMailbox: Sendable {
    public static let shared = WorkerMailbox()

    private let logger = Logger(subsystem: "com.swiftcode.app", category: "WorkerMailbox")
    
    private var pendingByWorker: [String: [WorkerMessage]] = [:]
    
    private var parentInbox: [WorkerMessage] = []
    
    public private(set) var recent: [WorkerMessage] = []
    private let maxRecent = 200

    private init() {}

    
    @discardableResult
    public func send(from sender: String, to: String, text: String) -> WorkerMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let target = to.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let message: WorkerMessage
        if target == "parent" {
            message = WorkerMessage(sender: sender, recipient: .parent, text: trimmed)
            parentInbox.append(message)
        } else if target == "broadcast" || target == "all" {
            message = WorkerMessage(sender: sender, recipient: .broadcast, text: trimmed)
            pendingByWorker["broadcast", default: []].append(message)
        } else {
            message = WorkerMessage(sender: sender, recipient: .worker, targetWorker: to, text: trimmed)
            pendingByWorker[target, default: []].append(message)
        }
        recent.append(message)
        if recent.count > maxRecent { recent.removeFirst(recent.count - maxRecent) }
        logger.info("[WorkerMailbox] \(message.summary, privacy: .public)")
        emitEvent(for: message)
        return message
    }

    
    public func inbox(forWorker workerName: String) -> [WorkerMessage] {
        (pendingByWorker[workerName.lowercased()] ?? []) +
        (pendingByWorker["broadcast"] ?? [])
    }

    
    public func drain(forWorker workerName: String) -> [WorkerMessage] {
        let key = workerName.lowercased()
        let direct = pendingByWorker.removeValue(forKey: key) ?? []
        return direct
    }

    
    public func drainParentInbox() -> [WorkerMessage] {
        let out = parentInbox
        parentInbox.removeAll()
        return out
    }

    public func clear() {
        pendingByWorker.removeAll()
        parentInbox.removeAll()
        recent.removeAll()
    }

    private func emitEvent(for message: WorkerMessage) {
        
        
        
        
        let senderID = WorkerRuntimeState.shared.allWorkers
            .first(where: { $0.name.caseInsensitiveCompare(message.sender) == .orderedSame })?.id
            ?? WorkerRuntimeState.shared.allWorkers.last?.id
            ?? UUID()
        WorkerEventBus.shared.emit(WorkerEvent(
            workerID: senderID,
            type: .workerMessage,
            title: "Message",
            details: message.summary,
            metadata: ["mailbox": "true"]))
    }
}
