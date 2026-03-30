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
        guard let range = response.range(of: "{"),
              let endRange = response.range(of: "}", options: .backwards) else {
            throw AssistPlannerError.invalidResponse
        }

        let jsonStr = response[range.lowerBound...endRange.upperBound]
        guard let data = jsonStr.data(using: .utf8) else {
            throw AssistPlannerError.invalidResponse
        }

        struct RawPlan: Decodable {
            let goal: String
            let steps: [RawStep]
        }
        struct RawStep: Decodable {
            let toolId: String
            let input: [String: String]
            let description: String
        }

        let raw = try JSONDecoder().decode(RawPlan.self, from: data)
        var plan = AssistExecutionPlan(goal: raw.goal)
        plan.steps = raw.steps.map {
            AssistExecutionStep(toolId: $0.toolId, input: $0.input, description: $0.description)
        }
        return plan
    }
}

enum AssistPlannerError: Error {
    case invalidResponse
}
