import Foundation

public final class AssistPlanner {
    private let context: AssistContext

    public init(context: AssistContext) {
        self.context = context
    }

    public func plan(for intent: String) async throws -> AssistExecutionPlan {
        context.logger.info("Planning for intent: \(intent)")

        // In a real system, this would call an LLM to generate a structured plan.
        // For now, we'll implement a basic heuristic-based planner or a simple LLM call.

        let systemPrompt = """
        You are the Assist Planner for SwiftCode.
        Your job is to break down a user's intent into a series of tool calls.
        Available tools are listed in the context.
        Output a JSON object: {"goal": "...", "steps": [{"toolId": "...", "input": {"key": "value"}, "description": "..."}]}
        """

        do {
            let response = try await LLMService.shared.generateResponse(prompt: "\(systemPrompt)\n\nIntent: \(intent)", useContext: true)
            return try parsePlan(from: response)
        } catch {
            context.logger.error("Failed to generate plan: \(error.localizedDescription)")
            // Fallback: simple one-step plan if LLM fails
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
