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
        AssistExecutionFunctions.initializeRegistry()
        loadHistory()
        setupAgent()
    }

    private func setupAgent() {
        let context = buildContext()
        self.agent = AssistAgent(context: context, registry: registry)
    }

    private func buildContext() -> AssistContext {
        let builder = AssistContextBuilder(
            logger: logger,
            permissions: permissions,
            memory: memory,
            fileSystem: AssistFileSystem(workspaceRoot: ProjectManager.shared.currentProject?.directoryURL ?? URL(fileURLWithPath: "/")),
            git: AssistGitManager(project: ProjectManager.shared.currentProject)
        )
        return builder.buildContext(sessionId: session.id)
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

    public func rejectPlan() {
        session.currentPlan = nil
        registerCapabilityExecution("Plan rejected.")
    }

    public func applyPlan(_ plan: AssistExecutionPlan) async throws {
        guard var executingPlan = session.currentPlan ?? session.history.first(where: { $0.id == plan.id }) ?? Optional(plan) else {
            return
        }
        let engine = AssistExecutionEngine(context: buildContext(), registry: registry)
        try await engine.execute(plan: &executingPlan)
        session.currentPlan = executingPlan
        if let index = session.history.firstIndex(where: { $0.id == executingPlan.id }) {
            session.history[index] = executingPlan
        } else {
            session.history.append(executingPlan)
        }
        registerCapabilityExecution("Plan applied successfully.")
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
