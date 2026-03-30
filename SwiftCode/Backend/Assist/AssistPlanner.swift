import Foundation

public final class AssistPlanner {
    private let context: AssistContext

    public init(context: AssistContext) {
        self.context = context
    }

    public func plan(for intent: String) async throws -> AssistExecutionPlan {
        context.logger.info("Planning for intent: \(intent)")

        let systemPrompt = """
        You are the Assist Planner for SwiftCode.
        Your job is to break down a user's intent into a series of tool calls.
        Available tools are listed in the context.
        Output a JSON object: {"goal": "...", "steps": [{"toolId": "...", "input": {"key": "value"}, "description": "..."}]}
        """

        let providerRawValue = UserDefaults.standard.string(forKey: "assist.selectedProvider") ?? AssistModelProvider.openAI.rawValue
        let provider = AssistModelProvider(rawValue: providerRawValue) ?? .openAI
        let apiKey = APIKeyManager.shared.retrieveKey(service: provider.apiKeyProvider)

        let response = await AssistLLMService.generateResponse(
            prompt: "\(systemPrompt)\n\nIntent: \(intent)",
            provider: provider,
            apiKey: apiKey
        )

        guard response.success else {
            context.logger.error("Planner request failed: \(response.error ?? "Unknown planner error")")
            return AssistExecutionPlan(goal: intent, steps: [])
        }

        do {
            return try parsePlan(from: response.content)
        } catch {
            context.logger.error("Planner response parse failed: \(error.localizedDescription)")
            return AssistExecutionPlan(goal: intent, steps: [])
        }
    }

    private func parsePlan(from response: String) throws -> AssistExecutionPlan {
        let pattern = "\\{(?:[^{}]|\\{(?:[^{}]|\\{[^{}]*\\})*\\})*\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range, in: response) else {
            context.logger.error("No JSON found in planner response.")
            throw AssistPlannerError.invalidResponse
        }

        let jsonStr = String(response[range])
        guard let data = jsonStr.data(using: .utf8) else {
            throw AssistPlannerError.invalidResponse
        }

        struct RawPlan: Decodable {
            let goal: String?
            let steps: [RawStep]?
        }
        struct RawStep: Decodable {
            let toolId: String?
            let input: [String: String]?
            let description: String?
        }

        let raw = try JSONDecoder().decode(RawPlan.self, from: data)
        var plan = AssistExecutionPlan(goal: raw.goal ?? "Untitled Task")
        plan.steps = (raw.steps ?? []).compactMap { step in
            guard let toolId = step.toolId else { return nil }
            return AssistExecutionStep(
                toolId: toolId,
                input: step.input ?? [:],
                description: step.description ?? "Executing \(toolId)"
            )
        }

        if plan.steps.isEmpty {
            context.logger.warning("Planner returned 0 steps for intent.")
        }

        return plan
    }
}

enum AssistPlannerError: Error {
    case invalidResponse
}
