import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.swiftcode.app", category: "AssistScheduledTaskManager")

public struct AssistScheduledTask: Identifiable, Codable, Sendable, Hashable {
    public enum CadenceType: String, Codable, Sendable {
        case oneShot = "One-Shot"
        case cron = "Recurring Cron"
    }

    public enum TaskStatus: String, Codable, Sendable {
        case scheduled = "Scheduled"
        case running = "Running"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }

    public let id: UUID
    public var title: String
    public var prompt: String
    public var cadenceType: CadenceType
    public var cadenceValue: String
    public var scheduledAt: Date
    public var nextFireDate: Date
    public var isDaemon: Bool
    public var status: TaskStatus

    public init(
        id: UUID = UUID(),
        title: String,
        prompt: String,
        cadenceType: CadenceType,
        cadenceValue: String,
        scheduledAt: Date = Date(),
        nextFireDate: Date,
        isDaemon: Bool = false,
        status: TaskStatus = .scheduled
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.cadenceType = cadenceType
        self.cadenceValue = cadenceValue
        self.scheduledAt = scheduledAt
        self.nextFireDate = nextFireDate
        self.isDaemon = isDaemon
        self.status = status
    }
}

@MainActor
@Observable
public final class AssistScheduledTaskManager {
    public static let shared = AssistScheduledTaskManager()

    public private(set) var tasks: [AssistScheduledTask] = []
    private var activeTimers: [UUID: Task<Void, Never>] = [:]

    private init() {}

    public func parseDuration(_ string: String) -> Int? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let directSec = Int(trimmed) {
            return max(1, directSec)
        }
        if trimmed.hasSuffix("s") {
            let val = String(trimmed.dropLast())
            return Int(val).map { max(1, $0) }
        }
        if trimmed.hasSuffix("m") {
            let val = String(trimmed.dropLast())
            return Int(val).map { max(1, $0 * 60) }
        }
        if trimmed.hasSuffix("h") {
            let val = String(trimmed.dropLast())
            return Int(val).map { max(1, $0 * 3600) }
        }
        if trimmed.hasSuffix("d") {
            let val = String(trimmed.dropLast())
            return Int(val).map { max(1, $0 * 86400) }
        }
        return nil
    }

    @discardableResult
    public func scheduleOneShot(delaySeconds: Int, prompt: String, title: String? = nil, isDaemon: Bool = false) -> AssistScheduledTask {
        let taskTitle = title ?? (prompt.count > 30 ? String(prompt.prefix(27)) + "..." : prompt)
        let fireDate = Date().addingTimeInterval(TimeInterval(delaySeconds))

        let task = AssistScheduledTask(
            title: taskTitle,
            prompt: prompt,
            cadenceType: .oneShot,
            cadenceValue: "\(delaySeconds)s",
            nextFireDate: fireDate,
            isDaemon: isDaemon
        )

        tasks.append(task)
        logger.info("Scheduled task '\(taskTitle)' to fire in \(delaySeconds)s at \(fireDate).")

        let timer = Task { [weak self, taskID = task.id, fireSeconds = delaySeconds, promptText = prompt] in
            try? await Task.sleep(nanoseconds: UInt64(fireSeconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.executeTrigger(for: taskID, prompt: promptText)
        }
        activeTimers[task.id] = timer

        return task
    }

    @discardableResult
    public func scheduleCron(expression: String, prompt: String, title: String? = nil, isDaemon: Bool = false) -> AssistScheduledTask {
        let taskTitle = title ?? (prompt.count > 30 ? String(prompt.prefix(27)) + "..." : prompt)
        // Default interval for cron demonstration: 5 minutes or calculated cadence
        let interval: TimeInterval = 300
        let nextFire = Date().addingTimeInterval(interval)

        let task = AssistScheduledTask(
            title: taskTitle,
            prompt: prompt,
            cadenceType: .cron,
            cadenceValue: expression,
            nextFireDate: nextFire,
            isDaemon: isDaemon
        )

        tasks.append(task)
        logger.info("Scheduled cron task '\(taskTitle)' [\(expression)].")

        let timer = Task { [weak self, taskID = task.id, promptText = prompt] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.executeTrigger(for: taskID, prompt: promptText)
                if !isDaemon { break }
            }
        }
        activeTimers[task.id] = timer

        return task
    }

    public func cancelTask(id: UUID) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].status = .cancelled
        }
        activeTimers[id]?.cancel()
        activeTimers.removeValue(forKey: id)
        logger.info("Cancelled scheduled task \(id).")
    }

    private func executeTrigger(for taskID: UUID, prompt: String) {
        if let idx = tasks.firstIndex(where: { $0.id == taskID }) {
            tasks[idx].status = .completed
        }
        activeTimers.removeValue(forKey: taskID)

        let messageText = "⏰ [SCHEDULED TASK FIRED] \(prompt)"
        logger.info("Triggering scheduled task: \(prompt)")

        let manager = AssistManager.shared
        if !manager.isProcessing {
            Task {
                await manager.sendMessage(messageText)
            }
        } else {
            manager.enqueueMessage(messageText)
        }
    }
}
