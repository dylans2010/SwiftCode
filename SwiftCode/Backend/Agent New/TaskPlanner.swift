import Foundation

@MainActor
final class TaskPlanner {
    static let shared = TaskPlanner()
    private init() {}

    func generatePlan(
        for task: String,
        contextFiles: [String] = [],
        availableFiles: [String] = []
    ) async throws -> [AgentPlanStep] {
        let systemPrompt = """
        You are an expert task planner for autonomous software development agents.
        Break down complex tasks into clear, actionable steps.
        Each step should be specific and achievable.
        Typically, plans should have 3-7 steps.
        """

        let fileContext = buildFileContext(contextFiles: contextFiles, availableFiles: availableFiles)

        let prompt = """
        Task: \(task)

        \(fileContext)

        Create a step-by-step execution plan to complete this task.
        Return ONLY a JSON array of step descriptions.

        Format:
        ["Step 1 description", "Step 2 description", "Step 3 description"]

        Guidelines:
        - Start with understanding/scanning if needed
        - Include reading relevant files
        - Include making code changes if needed
        - Include verification steps
        - Be specific and actionable
        """

        let response = try await LLMService.shared.generateResponse(prompt: prompt, useContext: true)

        // Attempt to parse the response as JSON array of strings
        return parseSteps(from: response, fallbackTask: task)
    }

    private func buildFileContext(contextFiles: [String], availableFiles: [String]) -> String {
        var context = ""

        if !contextFiles.isEmpty {
            context += "Context Files Provided:\n"
            context += contextFiles.map { "- \($0)" }.joined(separator: "\n")
            context += "\n\n"
        }

        if !availableFiles.isEmpty {
            let count = min(availableFiles.count, 20)
            context += "Repository contains \(availableFiles.count) files"
            if availableFiles.count > 20 {
                context += " (showing first 20):\n"
            } else {
                context += ":\n"
            }
            context += availableFiles.prefix(count).map { "- \($0)" }.joined(separator: "\n")
            context += "\n\n"
        }

        return context
    }

    private func parseSteps(from response: String, fallbackTask: String) -> [AgentPlanStep] {
        // Clean up response to extract JSON
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to parse as JSON array
        if let data = cleaned.data(using: .utf8),
           let steps = try? JSONDecoder().decode([String].self, from: data),
           !steps.isEmpty {
            return steps.map { AgentPlanStep(description: $0) }
        }

        // Try to parse line-by-line if response is not valid JSON
        let lines = cleaned.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("{") && !$0.hasPrefix("}") }
            .map { line -> String in
                // Remove leading markers like "1.", "-", "*", etc.
                var cleaned = line
                if let match = cleaned.range(of: #"^[\d\.\-\*\+]\s*"#, options: .regularExpression) {
                    cleaned.removeSubrange(match)
                }
                return cleaned.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }

        if !lines.isEmpty {
            return lines.map { AgentPlanStep(description: $0) }
        }

        // Final fallback - generate intelligent steps based on task
        return generateFallbackPlan(for: fallbackTask)
    }

    private func generateFallbackPlan(for task: String) -> [AgentPlanStep] {
        let lowercased = task.lowercased()

        // Customize plan based on task type
        if lowercased.contains("refactor") {
            return [
                AgentPlanStep(description: "Scan and identify files to refactor"),
                AgentPlanStep(description: "Read current implementation"),
                AgentPlanStep(description: "Plan refactoring approach"),
                AgentPlanStep(description: "Apply refactoring changes"),
                AgentPlanStep(description: "Verify changes compile")
            ]
        } else if lowercased.contains("fix") || lowercased.contains("bug") {
            return [
                AgentPlanStep(description: "Locate the file with the issue"),
                AgentPlanStep(description: "Read and analyze the problematic code"),
                AgentPlanStep(description: "Identify the root cause"),
                AgentPlanStep(description: "Implement the fix"),
                AgentPlanStep(description: "Test the fix")
            ]
        } else if lowercased.contains("add") || lowercased.contains("create") || lowercased.contains("implement") {
            return [
                AgentPlanStep(description: "Understand project structure"),
                AgentPlanStep(description: "Identify where to add new code"),
                AgentPlanStep(description: "Design the implementation"),
                AgentPlanStep(description: "Write the new code"),
                AgentPlanStep(description: "Verify integration")
            ]
        } else {
            // Generic fallback
            return [
                AgentPlanStep(description: "Analyze the request: \(task)"),
                AgentPlanStep(description: "Scan relevant files"),
                AgentPlanStep(description: "Execute required actions"),
                AgentPlanStep(description: "Verify results and finalize")
            ]
        }
    }
}
