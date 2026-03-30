import Foundation
import Combine

@MainActor
public final class AssistManager: ObservableObject {
    public static let shared = AssistManager()

    @Published public var messages: [AssistMessage] = []
    @Published public var isProcessing = false
    @Published public var lastError: String?

    // Core Components
    public let logger = AssistLogger()
    public let session = AssistSession()
    public let registry = AssistToolRegistry()
    private let permissions = AssistPermissionsManager()
    private let memory = AssistMemoryGraph()

    private var agent: AssistAgent?

    public var selectedModel: AssistModelOption {
        let modelID = AppSettings.shared.selectedAssistModelID
        return AssistModelOption.all.first(where: { $0.id == modelID }) ?? .swiftCodeBalanced
    }

    private init() {
        loadHistory()
        setupAgent()
    }

    private func setupAgent() {
        let builder = AssistContextBuilder(
            logger: logger,
            permissions: permissions,
            memory: memory,
            fileSystem: AssistFileSystem(workspaceRoot: ProjectManager.shared.currentProject?.rootURL ?? URL(fileURLWithPath: "/")),
            git: AssistGitManager(project: ProjectManager.shared.currentProject)
        )
        let context = builder.buildContext(sessionId: session.id)
        self.agent = AssistAgent(context: context, registry: registry)
    }

    public func sendMessage(_ content: String) async {
        let userMessage = AssistMessage(role: .user, content: content)
        messages.append(userMessage)
        saveHistory()

        isProcessing = true
        lastError = nil

        do {
            if let agent = agent {
                try await agent.processIntent(content)
                // In a real implementation, we'd add the agent's summary response here
                let assistantMessage = AssistMessage(role: .assistant, content: "Task completed successfully.")
                messages.append(assistantMessage)
            } else {
                throw NSError(domain: "Assist", code: 1, userInfo: [NSLocalizedDescriptionKey: "Agent not initialized"])
            }
        } catch {
            lastError = error.localizedDescription
            let errorMessage = AssistMessage(role: .system, content: "Error: \(error.localizedDescription)")
            messages.append(errorMessage)
        }

        isProcessing = false
        saveHistory()
    }

    public func clearChat() {
        messages.removeAll()
        session.reset()
        UserDefaults.standard.removeObject(forKey: "com.swiftcode.assist.history")
    }

    public func registerCapabilityExecution(_ text: String) {
        let systemMessage = AssistMessage(role: .system, content: text)
        messages.append(systemMessage)
        saveHistory()
    }

    // MARK: - Persistence

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "com.swiftcode.assist.history"),
           let history = try? JSONDecoder().decode([AssistMessage].self, from: data) {
            self.messages = history
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: "com.swiftcode.assist.history")
        }
    }
}
