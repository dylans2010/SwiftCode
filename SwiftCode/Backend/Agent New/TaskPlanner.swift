import Foundation

@MainActor
final class TaskPlanner {
    static let shared = TaskPlanner()
    private init() {}

    func generatePlan(for task: String) async throws -> [AgentPlanStep] {
        let systemPrompt = """
        You are a task planner. Decompose the user task into a list of 3-5 high-level steps.
        Return ONLY a JSON array of strings, where each string is a step description.
        Example: ["Step 1", "Step 2", "Step 3"]
        """

        let response = try await LLMService.shared.generateResponse(prompt: task, useContext: true)

        // Attempt to parse the response as JSON array of strings
        // If parsing fails, fallback to a basic plan
        let cleaned = response.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8),
           let steps = try? JSONDecoder().decode([String].self, from: data) {
            return steps.map { AgentPlanStep(description: $0) }
        }

        // Fallback
        return [
            AgentPlanStep(description: "Analyze the request: \(task)"),
            AgentPlanStep(description: "Execute required actions"),
            AgentPlanStep(description: "Verify results and finalize")
        ]
    }
}
