import Foundation

public struct AssistPlan: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public var steps: [AssistStep]
    public var status: AssistStatus

    public init(title: String, steps: [AssistStep] = []) {
        self.id = UUID()
        self.title = title
        self.steps = steps
        self.status = .pending
    }
}

public struct AssistStep: Codable, Identifiable {
    public let id: UUID
    public let description: String
    public var actions: [AssistAction]
    public var status: AssistStatus

    public init(description: String, actions: [AssistAction] = []) {
        self.id = UUID()
        self.description = description
        self.actions = actions
        self.status = .pending
    }
}

public enum AssistAction: Codable {
    case createFile(path: String, content: String)
    case modifyFile(path: String, patch: String)
    case deleteFile(path: String)
    case renameFile(oldPath: String, newPath: String)
    case runTest(testName: String)

    var path: String {
        switch self {
        case .createFile(let p, _), .modifyFile(let p, _), .deleteFile(let p), .renameFile(let p, _):
            return p
        case .runTest:
            return ""
        }
    }
}

public enum AssistStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
    case rejected
}

public struct AssistMessage: Codable, Identifiable {
    public let id: UUID
    public let role: AssistRole
    public let content: String
    public let timestamp: Date

    public init(role: AssistRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

public enum AssistRole: String, Codable {
    case user
    case assistant
    case system
}
