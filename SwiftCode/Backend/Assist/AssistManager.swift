import Foundation
import Combine

@MainActor
public final class AssistManager: ObservableObject {
    public static let shared = AssistManager()

    @Published public var messages: [AssistMessage] = []
    @Published public var currentPlan: AssistPlan?
    @Published public var isProcessing = false
    @Published public var lastError: String?
    @Published public var availableTools: [AssistTool] = AssistTool.allCases

    public var selectedModel: AssistModelOption {
        let modelID = AppSettings.shared.selectedAssistModelID
        return AssistModelOption.all.first(where: { $0.id == modelID }) ?? .swiftCodeBalanced
    }

    private var sessionHistory: [AssistMessage] = []

    private init() {
        loadHistory()
    }

    public func sendMessage(_ content: String) async {
        let userMessage = AssistMessage(role: .user, content: content)
        messages.append(userMessage)
        sessionHistory.append(userMessage)
        saveHistory()

        isProcessing = true
        lastError = nil

        do {
            // Integrate real LLMService
            let systemPrompt = """
            You are SwiftCode Assist, an AI specialized in iOS development.
            Analyze the user's request and provide a technical plan.
            If the request requires code changes, provide a JSON plan in your response wrapped in ```json tags.
            Plan format: {"title": "...", "steps": [{"description": "...", "actions": [{"type": "createFile|modifyFile|deleteFile|renameFile", "path": "...", "content": "..."}]}]}
            """

            let modelPrompt = """
            Selected Assist Model: \(selectedModel.displayName) (\(selectedModel.provider))
            Available Tools: \(availableTools.map(\.rawValue).joined(separator: ", "))
            """
            let responseText = try await LLMService.shared.generateResponse(prompt: "\(modelPrompt)\n\n\(content)", useContext: true)

            // Try to parse plan from response
            if let plan = extractPlan(from: responseText) {
                self.currentPlan = plan
            }

            let assistantMessage = AssistMessage(role: .assistant, content: responseText)
            messages.append(assistantMessage)
            sessionHistory.append(assistantMessage)
            saveHistory()

        } catch {
            lastError = error.localizedDescription
            let errorMessage = AssistMessage(role: .system, content: "Error: \(error.localizedDescription)")
            messages.append(errorMessage)
        }

        isProcessing = false
    }

    private func extractPlan(from text: String) -> AssistPlan? {
        guard let range = text.range(of: "```json"),
              let endRange = text.range(of: "```", options: .backwards, range: range.upperBound..<text.endIndex) else {
            return nil
        }

        let jsonStr = text[range.upperBound..<endRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonStr.data(using: .utf8) else { return nil }

        // Custom decoding to match AssistPlan structure
        struct AIPlan: Decodable {
            let title: String
            let steps: [AIStep]
        }
        struct AIStep: Decodable {
            let description: String
            let actions: [AIAction]
        }
        struct AIAction: Decodable {
            let type: String
            let path: String
            let content: String?
            let oldPath: String?
            let newPath: String?
        }

        do {
            let aiPlan = try JSONDecoder().decode(AIPlan.self, from: data)
            var assistSteps: [AssistStep] = []
            for step in aiPlan.steps {
                var assistActions: [AssistAction] = []
                for action in step.actions {
                    switch action.type {
                    case "createFile": assistActions.append(.createFile(path: action.path, content: action.content ?? ""))
                    case "modifyFile": assistActions.append(.modifyFile(path: action.path, patch: action.content ?? ""))
                    case "deleteFile": assistActions.append(.deleteFile(path: action.path))
                    case "renameFile": assistActions.append(.renameFile(oldPath: action.oldPath ?? action.path, newPath: action.newPath ?? ""))
                    default: break
                    }
                }
                assistSteps.append(AssistStep(description: step.description, actions: assistActions))
            }
            return AssistPlan(title: aiPlan.title, steps: assistSteps)
        } catch {
            print("Failed to decode AI plan: \(error)")
            return nil
        }
    }

    public func applyPlan(_ plan: AssistPlan) async throws {
        isProcessing = true
        var updatedPlan = plan
        updatedPlan.status = .inProgress
        self.currentPlan = updatedPlan

        let loop = AssistLoop(plan: updatedPlan)
        do {
            try await loop.execute()
            updatedPlan.status = .completed
            self.currentPlan = nil // Clear active plan once done
            messages.append(AssistMessage(role: .system, content: "Plan \"\(plan.title)\" applied successfully."))
        } catch {
            updatedPlan.status = .failed
            self.currentPlan = updatedPlan
            lastError = error.localizedDescription
            throw error
        }

        isProcessing = false
    }

    public func rejectPlan() {
        if let plan = currentPlan {
            currentPlan = nil
            messages.append(AssistMessage(role: .system, content: "Plan \"\(plan.title)\" rejected."))
        }
    }

    public func clearChat() {
        messages.removeAll()
        sessionHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "com.swiftcode.assist.history")
    }

    public func registerCapabilityExecution(_ text: String) {
        let systemMessage = AssistMessage(role: .system, content: text)
        messages.append(systemMessage)
        sessionHistory.append(systemMessage)
        saveHistory()
    }

    // MARK: - Persistence

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "com.swiftcode.assist.history"),
           let history = try? JSONDecoder().decode([AssistMessage].self, from: data) {
            self.messages = history
            self.sessionHistory = history
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(data, forKey: "com.swiftcode.assist.history")
        }
    }
}
