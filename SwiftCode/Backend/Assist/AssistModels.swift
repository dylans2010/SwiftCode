import Foundation

public struct AssistModelOption: Identifiable, Codable, Hashable {
    public let id: String
    public let displayName: String
    public let provider: String

    public static let swiftCodeBalanced = AssistModelOption(id: "swiftcode.assist.balanced", displayName: "SwiftCode Balanced", provider: "SwiftCode")
    public static let swiftCodeReasoning = AssistModelOption(id: "swiftcode.assist.reasoning", displayName: "SwiftCode Reasoning", provider: "SwiftCode")
    public static let gpt4oMini = AssistModelOption(id: "openai.gpt-4o-mini", displayName: "GPT-4o mini", provider: "OpenAI")
    public static let claudeSonnet = AssistModelOption(id: "anthropic.claude-sonnet", displayName: "Claude Sonnet", provider: "Anthropic")

    public static let all: [AssistModelOption] = [.swiftCodeBalanced, .swiftCodeReasoning, .gpt4oMini, .claudeSonnet]
}

public enum AssistTool: String, CaseIterable, Codable, Identifiable {
    case editFiles = "Edit Files"
    case generatePlan = "Generate Plan"
    case runTests = "Run Tests"
    case summarizeDiff = "Summarize Diff"
    case createPatch = "Create Patch"
    case refactor = "Refactor"
    case explainCode = "Explain Code"
    case extensionBridge = "Extension Bridge"
    case skillBridge = "Skill Bridge"
    case connectionBridge = "Connection Bridge"

    public var id: String { rawValue }
}

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

public enum AssistCapabilityKind: String, Codable {
    case `extension`
    case skill
    case connection
}
