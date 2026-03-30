import Foundation

@MainActor
final class AgentSkillsManager {
    static let shared = AgentSkillsManager()
    private init() {}

    func loadSkills() {
        let skills = AgentSkillManager.shared.allSkills
        for skill in skills {
            let tool = AgentTool(
                id: "skill_\(skill.scheme.name.lowercased().replacingOccurrences(of: " ", with: "_"))",
                displayName: skill.scheme.name,
                description: skill.scheme.summary,
                parameters: [
                    AgentToolParameter(name: "input", description: "Input for the skill execution")
                ],
                category: .utilities
            )

            ToolRegistry.shared.register(tool, source: ToolSource.skill) { params in
                AssistCapabilityExecutor.executeIfNeeded(
                    kind: AssistCapabilityKind.skill,
                    name: skill.scheme.name,
                    identifiers: skill.identificationTags,
                    payload: params.reduce(into: [String: String]()) { partialResult, entry in
                        partialResult[entry.key] = "\(entry.value)"
                    }
                )
                // Logic to execute skill
                return "Skill '\(skill.scheme.name)' executed with input: \(params["input"] ?? "none")"
            }
        }
    }
}
