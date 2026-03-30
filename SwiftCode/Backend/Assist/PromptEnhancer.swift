import Foundation

public final class PromptEnhancer {
    public static func enhancePrompt(userInput: String) async -> String {
        let systemPrompt = """
        You are an expert software architect. Rewrite vague user prompts into highly detailed, technically specific instructions for an autonomous coding agent.

        Rules:
        - Expand vague ideas into concrete steps
        - Specify frameworks and architecture
        - Infer missing details
        - Do not explain anything
        - Output must be directly executable
        """

        let apiKey = APIKeyManager.shared.retrieveKey(service: .openRouter)

        let response = await AssistLLMService.generateResponse(
            prompt: "\(systemPrompt)\n\nUser Input: \(userInput)",
            provider: .openRouter,
            apiKey: apiKey,
            modelOverride: "openai/gpt-oss-120b:free"
        )

        if response.success {
            return response.content
        } else {
            // Fallback to original input if enhancement fails
            return userInput
        }
    }
}
