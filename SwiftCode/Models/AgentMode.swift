import Foundation

enum AgentMode: String, CaseIterable, Identifiable {
    case generate = "Generate"
    case modify = "Modify"
    case refactor = "Refactor"
    case debug = "Debug"
    case agent = "Agent"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .generate: return "Create new Swift files or features"
        case .modify: return "Edit existing code with AI assistance"
        case .refactor: return "Analyze and improve project structure"
        case .debug: return "Analyze errors and propose fixes"
        case .agent: return "Autonomous agent with \(AgentTool.all.count)+ tools"
        }
    }

    var icon: String {
        switch self {
        case .generate: return "plus.circle.fill"
        case .modify: return "pencil.circle.fill"
        case .refactor: return "arrow.triangle.2.circlepath.circle.fill"
        case .debug: return "ant.circle.fill"
        case .agent: return "cpu.fill"
        }
    }

    var systemPrompt: String {
        switch self {
        case .generate:
            return "You are an expert Swift/SwiftUI developer. Generate clean, production-ready Swift code based on the user's request. Always include proper imports and follow Swift best practices. Format code blocks with ```swift."
        case .modify:
            return "You are an expert Swift/SwiftUI developer. Modify the provided Swift code based on the user's request. Show the complete modified file or provide a clear diff. Format code blocks with ```swift."
        case .refactor:
            return "You are an expert Swift/SwiftUI developer. Analyze the provided Swift code and suggest improvements for modularity, performance, and SwiftUI best practices. Format code blocks with ```swift."
        case .debug:
            return "You are an expert Swift/SwiftUI developer. Analyze the provided error or code and identify the root cause. Provide a clear fix with explanation. Format code blocks with ```swift."
        case .agent:
            // Dynamic system prompt built by AgentToolService
            return AgentToolService.buildSystemPrompt()
        }
    }
}

struct AIMessage: Identifiable, Codable {
    var id: UUID = UUID()
    var role: String // "user", "assistant", "tool_call", or "tool_result"
    var content: String
    var timestamp: Date = Date()

    init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
        self.id        = id
        self.role      = role
        self.content   = content
        self.timestamp = timestamp
    }
}

struct OpenRouterModel: Identifiable, Codable {
    var id: String
    var name: String
    var description: String

    static let defaults: [OpenRouterModel] = [
        OpenRouterModel(id: "anthropic/claude-3.5-sonnet", name: "Claude 3.5 Sonnet", description: "Best for coding"),
        OpenRouterModel(id: "openai/gpt-4o", name: "GPT-4o", description: "Powerful and fast"),
        OpenRouterModel(id: "google/gemini-pro-1.5", name: "Gemini Pro 1.5", description: "Google's best"),
        OpenRouterModel(id: "meta-llama/llama-3.1-70b-instruct", name: "Llama 3.1 70B", description: "Open source"),
        OpenRouterModel(id: "deepseek/deepseek-coder", name: "DeepSeek Coder", description: "Specialized for code"),
    ]
}
