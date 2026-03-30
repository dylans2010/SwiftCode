import Foundation
import SwiftUI

// MARK: - AI Models & Providers

public enum AssistModelProvider: String, Codable, CaseIterable {
    case openAI = "ChatGPT"
    case anthropic = "Claude"
    case gemini = "Gemini"
    case mistral = "Mistral"
    case meta = "Meta AI"
    case kimi = "Kimi"
    case openRouter = "OpenRouter"

    var apiKeyProvider: APIKeyProvider {
        switch self {
        case .openAI: return .openai
        case .anthropic: return .anthropic
        case .gemini: return .google
        case .mistral: return .mistral
        case .meta, .kimi: return .openRouter
        case .openRouter: return .openRouter
        }
    }

    public var endpoint: URL? {
        switch self {
        case .openAI: return URL(string: "https://api.openai.com/v1/chat/completions")
        case .anthropic: return URL(string: "https://api.anthropic.com/v1/messages")
        case .gemini: return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent")
        case .mistral: return URL(string: "https://api.mistral.ai/v1/chat/completions")
        case .meta: return URL(string: "https://api.meta.ai/v1/chat/completions") // Example
        case .kimi: return URL(string: "https://api.moonshot.cn/v1/chat/completions")
        case .openRouter: return URL(string: "https://openrouter.ai/api/v1/chat/completions")
        }
    }
}

public struct AssistAIResponse {
    public let content: String
    public let success: Bool
    public let error: String?

    public init(content: String, success: Bool, error: String? = nil) {
        self.content = content
        self.success = success
        self.error = error
    }
}

public struct AssistLLMService {
    public static func generateResponse(prompt: String, provider: AssistModelProvider, apiKey: String?) async -> AssistAIResponse {
        guard let url = provider.endpoint else {
            return AssistAIResponse(content: "", success: false, error: "Invalid endpoint for \(provider.rawValue)")
        }

        guard let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AssistAIResponse(content: "", success: false, error: "Missing API key for \(provider.rawValue).")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        switch provider {
        case .openAI, .mistral, .kimi, .openRouter, .meta:
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .gemini:
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
            if let finalURL = components?.url {
                request.url = finalURL
            }
        }

        let body = prepareBody(prompt: prompt, provider: provider)
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return AssistAIResponse(content: "", success: false, error: "Failed to encode API request payload.")
        }

        request.httpBody = bodyData

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: configuration)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return AssistAIResponse(content: "", success: false, error: "Invalid response from API provider.")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorPayload = parseAPIError(data: data)
                return AssistAIResponse(content: "", success: false, error: "API request failed (\(httpResponse.statusCode)): \(errorPayload)")
            }

            guard !data.isEmpty else {
                return AssistAIResponse(content: "", success: false, error: "API returned an empty response.")
            }

            guard let parsedContent = parseResponse(data: data, provider: provider) else {
                return AssistAIResponse(content: "", success: false, error: "API returned an unexpected response format.")
            }

            return AssistAIResponse(content: parsedContent, success: true)
        } catch {
            return AssistAIResponse(content: "", success: false, error: "Network request failed: \(error.localizedDescription)")
        }
    }

    private static func prepareBody(prompt: String, provider: AssistModelProvider) -> [String: Any] {
        switch provider {
        case .anthropic:
            return [
                "model": "claude-3-sonnet-20240229",
                "max_tokens": 4096,
                "messages": [["role": "user", "content": prompt]]
            ]
        case .gemini:
            return [
                "contents": [["parts": [["text": prompt]]]]
            ]
        default:
            let model: String
            switch provider {
            case .openAI: model = "gpt-4o-mini"
            case .mistral: model = "mistral-large-latest"
            case .kimi: model = "moonshot-v1-8k"
            case .openRouter: model = "openai/gpt-4o-mini"
            case .meta: model = "meta-llama/llama-3.1-8b-instruct"
            default: model = "gpt-4o-mini"
            }
            return [
                "model": model,
                "messages": [["role": "user", "content": prompt]]
            ]
        }
    }

    private static func parseResponse(data: Data, provider: AssistModelProvider) -> String? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }

        switch provider {
        case .anthropic:
            if let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String,
               !text.isEmpty {
                return text
            }
        case .gemini:
            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String,
               !text.isEmpty {
                return text
            }
        default:
            if let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String,
               !content.isEmpty {
                return content
            }
        }

        return nil
    }

    private static func parseAPIError(data: Data) -> String {
        if let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                return message
            }
            if let message = json["message"] as? String {
                return message
            }
        }

        return String(data: data, encoding: .utf8) ?? "Unknown API error"
    }
}

// MARK: - Core Protocols

/// Protocol for all Assist tools.
/// All tools must be prefixed with 'Assist'.
public protocol AssistTool {
    var id: String { get }
    var name: String { get }
    var description: String { get }

    func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult
}

// MARK: - Assist Context & State

/// Shared context provided to tools during execution.
public struct AssistContext {
    public let sessionId: UUID
    public let project: Project?
    public let workspaceRoot: URL
    public let memory: AssistMemoryGraphProtocol
    public let logger: AssistLoggerProtocol
    public let fileSystem: AssistFileSystemProtocol
    public let git: AssistGitManagerProtocol
    public let permissions: AssistPermissionsManagerProtocol

    // Safety & Mode settings
    public let safetyLevel: AssistSafetyLevel
    public let isAutonomous: Bool

    public init(
        sessionId: UUID,
        project: Project?,
        workspaceRoot: URL,
        memory: AssistMemoryGraphProtocol,
        logger: AssistLoggerProtocol,
        fileSystem: AssistFileSystemProtocol,
        git: AssistGitManagerProtocol,
        permissions: AssistPermissionsManagerProtocol,
        safetyLevel: AssistSafetyLevel,
        isAutonomous: Bool
    ) {
        self.sessionId = sessionId
        self.project = project
        self.workspaceRoot = workspaceRoot
        self.memory = memory
        self.logger = logger
        self.fileSystem = fileSystem
        self.git = git
        self.permissions = permissions
        self.safetyLevel = safetyLevel
        self.isAutonomous = isAutonomous
    }
}

/// Safety levels for autonomous execution.
public enum AssistSafetyLevel: String, Codable, CaseIterable {
    case conservative = "Conservative"
    case balanced = "Balanced"
    case aggressive = "Aggressive"
}

/// Result returned by an Assist tool execution.
public struct AssistToolResult: Codable {
    public let success: Bool
    public let output: String
    public let data: [String: String]?
    public let error: String?
    public let errorCode: Int?

    public init(success: Bool, output: String, data: [String: String]? = nil, error: String? = nil, errorCode: Int? = nil) {
        self.success = success
        self.output = output
        self.data = data
        self.error = error
        self.errorCode = errorCode
    }

    public static func success(_ output: String, data: [String: String]? = nil) -> AssistToolResult {
        AssistToolResult(success: true, output: output, data: data)
    }

    public static func failure(_ error: String, code: Int? = nil) -> AssistToolResult {
        AssistToolResult(success: false, output: "Error: \(error)", error: error, errorCode: code)
    }
}

// Standard data payload keys
public enum AssistToolDataKey {
    public static let content = "content"
    public static let explanation = "explanation"
    public static let diff = "diff"
    public static let testResults = "test_results"
    public static let buildStatus = "build_status"
    public static let searchResults = "results"
    public static let planId = "planId"
    public static let breakdown = "breakdown"
}

// MARK: - Planning & Execution Models

/// A structured plan generated by the AssistPlanner.
public struct AssistExecutionPlan: Codable, Identifiable {
    public let id: UUID
    public let goal: String
    public var steps: [AssistExecutionStep]
    public var status: AssistExecutionStatus

    public init(goal: String, steps: [AssistExecutionStep] = []) {
        self.id = UUID()
        self.goal = goal
        self.steps = steps
        self.status = .pending
    }
}

/// A single step within an execution plan.
public struct AssistExecutionStep: Codable, Identifiable {
    public let id: UUID
    public let toolId: String
    public let input: [String: String] // Simple key-value for storage/serialization
    public let description: String
    public var status: AssistExecutionStatus
    public var result: AssistToolResult?

    public init(toolId: String, input: [String: String], description: String) {
        self.id = UUID()
        self.toolId = toolId
        self.input = input
        self.description = description
        self.status = .pending
    }
}

public enum AssistExecutionStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
    case skipped
}

// MARK: - Legacy / UI Compatibility Models

/// Maintained for UI compatibility during transition
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

/// Maintained for UI compatibility
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

// MARK: - Core Protocols for Components

public protocol AssistMemoryGraphProtocol {
    func store(key: String, value: String)
    func retrieve(key: String) -> String?
    func clear()
}

public protocol AssistLoggerProtocol {
    func info(_ message: String, toolId: String?)
    func warning(_ message: String, toolId: String?)
    func error(_ message: String, toolId: String?)
    func debug(_ message: String, toolId: String?)
}

public protocol AssistFileSystemProtocol {
    func readFile(at path: String) throws -> String
    func writeFile(at path: String, content: String) throws
    func deleteFile(at path: String) throws
    func moveFile(from: String, to: String) throws
    func copyFile(from: String, to: String) throws
    func exists(at path: String) -> Bool
    func appendFile(at path: String, content: String) throws
    func listDirectory(at path: String) throws -> [String]
    func createDirectory(at path: String) throws
}

public protocol AssistGitManagerProtocol {
    func status() throws -> String
    func commit(message: String) throws
    func push() async throws
}

public protocol AssistPermissionsManagerProtocol {
    func isPathAllowed(_ path: String) -> Bool
    func authorizeOperation(_ operation: String) -> Bool
}


// MARK: - Legacy Typealiases

public typealias AssistPlan = AssistExecutionPlan
public typealias AssistStep = AssistExecutionStep

public enum AssistAction: Codable, Hashable {
    case createFile(String, String)
    case modifyFile(String, String)
    case deleteFile(String)
    case renameFile(String, String)
    case runTest(String)

    public var path: String {
        switch self {
        case .createFile(let path, _), .modifyFile(let path, _), .deleteFile(let path):
            return path
        case .renameFile(let oldPath, _):
            return oldPath
        case .runTest(let target):
            return target
        }
    }
}

public extension AssistExecutionPlan {
    var title: String { goal }
}

public extension AssistExecutionStep {
    var actions: [AssistAction] { [] }
}
