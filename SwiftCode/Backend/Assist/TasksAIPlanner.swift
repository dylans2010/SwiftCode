import Foundation
import Combine

/// A high-trust task planning engine that decomposes user intent into executable steps.
@MainActor
public final class TasksAIPlanner: ObservableObject {
    public static let shared = TasksAIPlanner()

    @Published public var currentPlan: AssistExecutionPlan?
    @Published public var isPlanning = false

    private init() {}

    /// Generates a structured multi-step plan based on user intent.
    public func generatePlan(intent: String, context: AssistContext) async throws -> AssistExecutionPlan {
        isPlanning = true
        defer { isPlanning = false }

        context.logger.info("Generating autonomous plan for intent: \(intent)", toolId: "TasksAIPlanner")

        let prompt = """
        \(AssistAgenticPrompt.systemPrompt)

        # TASK
        Analyze the user's intent and generate a structured execution plan.
        Intent: "\(intent)"

        # RESPONSE REQUIREMENTS
        You must output a JSON object representing the plan.
        Format:
        {
          "goal": "Clear summary of the goal",
          "steps": [
            {
              "toolId": "The ID of the tool to use (e.g., AssistReadFileTool)",
              "description": "Clear description of what this step achieves",
              "input": { "path": "example/path.swift", "content": "..." }
            }
          ]
        }

        # CONSTRAINTS
        - Minimum 3 steps.
        - Never return an empty steps array.
        - Use real file paths and full implementations.
        """

        let providerRawValue = UserDefaults.standard.string(forKey: "assist.selectedProvider") ?? AssistModelProvider.openAI.rawValue
        let provider = AssistModelProvider(rawValue: providerRawValue) ?? .openAI
        let apiKey = APIKeyManager.shared.retrieveKey(service: provider.apiKeyProvider)

        let response = await AssistLLMService.generateResponse(
            prompt: prompt,
            provider: provider,
            apiKey: apiKey
        )

        guard response.success else {
            context.logger.error("Planner failed to get AI response: \(response.error ?? "Unknown error")", toolId: "TasksAIPlanner")
            return fallbackPlan(intent: intent)
        }

        do {
            let plan = try parsePlan(from: response.content)
            self.currentPlan = plan
            return plan
        } catch {
            context.logger.error("Failed to parse plan JSON: \(error.localizedDescription)", toolId: "TasksAIPlanner")
            return fallbackPlan(intent: intent)
        }
    }

    /// Provides a basic fallback plan if the AI fails to generate one.
    public func fallbackPlan(intent: String) -> AssistExecutionPlan {
        var plan = AssistExecutionPlan(goal: intent)
        plan.steps = [
            AssistExecutionStep(toolId: "AssistSearchTool", input: ["query": intent], description: "Search codebase for context related to intent."),
            AssistExecutionStep(toolId: "AssistExplainCodeTool", input: ["query": intent], description: "Analyze relevant code sections."),
            AssistExecutionStep(toolId: "AssistRefactorTool", input: ["instructions": intent], description: "Apply requested changes or fixes.")
        ]
        self.currentPlan = plan
        return plan
    }

    /// Updates the status of a specific step in the current plan.
    public func updateStep(id: UUID, status: AssistExecutionStatus, result: AssistToolResult? = nil) {
        guard var plan = currentPlan else { return }
        if let index = plan.steps.firstIndex(where: { $0.id == id }) {
            plan.steps[index].status = status
            if let result = result {
                plan.steps[index].result = result
            }
            self.currentPlan = plan
        }
    }

    private func parsePlan(from response: String) throws -> AssistExecutionPlan {
        let pattern = "\\{(?:[^{}]|\\{(?:[^{}]|\\{[^{}]*\\})*\\})*\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range, in: response) else {
            throw AssistPlannerError.invalidResponse
        }

        let jsonStr = String(response[range])
        guard let data = jsonStr.data(using: .utf8) else {
            throw AssistPlannerError.invalidResponse
        }

        struct RawPlan: Decodable {
            let goal: String
            let steps: [RawStep]
        }
        struct RawStep: Decodable {
            let toolId: String
            let description: String
            let input: [String: String]
        }

        let raw = try JSONDecoder().decode(RawPlan.self, from: data)

        guard !raw.steps.isEmpty else {
            throw AssistPlannerError.invalidResponse
        }

        var plan = AssistExecutionPlan(goal: raw.goal)
        plan.steps = raw.steps.map { step in
            AssistExecutionStep(
                toolId: step.toolId,
                input: step.input,
                description: step.description
            )
        }
        return plan
    }
}
