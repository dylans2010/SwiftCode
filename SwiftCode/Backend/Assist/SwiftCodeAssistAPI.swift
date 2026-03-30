import Foundation

public final class SwiftCodeAssistAPI {
    /// Executes a SwiftCode Assist task with full codebase context.
    ///
    /// Developers can use this by setting the "UseSwiftCodeAssistAPI" parameter to true.
    public static func execute(prompt: String, project: Project, options: [String: Any] = [:]) async throws -> [AssistDraft] {
        let manager = AssistManager.shared

        // Check for specific API activation parameter
        guard options["UseSwiftCodeAssistAPI"] as? Bool == true else {
            throw AssistAPIError.apiNotRequested
        }

        await manager.processRequest(prompt, project: project)

        return manager.currentDrafts
    }
}

enum AssistAPIError: LocalizedError {
    case apiNotRequested

    var errorDescription: String? {
        switch self {
        case .apiNotRequested:
            return "SwiftCode Assist API was not requested via UseSwiftCodeAssistAPI parameter."
        }
    }
}
