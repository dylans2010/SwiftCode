import Foundation
import Testing
@testable import YcodeAssistant

@MainActor
struct UniversalToolAccessTests {

    @Test func expansionToolkitRegistersAtLeast200UniqueTools() {
        let tools = AssistExpansionToolkit.makeTools()
        #expect(tools.count >= 200)
        #expect(tools.count == AssistExpansionToolkit.toolCount)
        let ids = tools.map(\.id)
        #expect(Set(ids).count == ids.count)
        let registered = Set(AssistToolRegistry.shared.allTools.map(\.id))
        for id in ids { #expect(registered.contains(id), "\(id) is not registered") }
    }

    @Test func everyExpansionToolHasAgentReadyMetadata() {
        for tool in AssistExpansionToolkit.makeTools() {
            #expect(!tool.name.isEmpty)
            #expect(tool.description.count > 20, "\(tool.id) needs a descriptive description")
            #expect(tool.parametersSchema.type == "object")
            #expect(tool.id.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "_" }, "\(tool.id) id format")
        }
    }

    @Test func universalIndexTracksRegistry() {
        _ = AssistToolRegistry.shared
        #expect(AssistUniversalModelContext.registeredToolCount == AssistToolRegistry.shared.allTools.count)
        #expect(AssistUniversalModelContext.compactToolCatalog().contains("system_asset_search"))
    }

    @Test func augmentationIsIdempotentAndCarriesProtocol() {
        _ = AssistToolRegistry.shared
        let once = AssistUniversalModelContext.augmentInstructions("You are helpful.", taskHint: "write unit tests")
        #expect(once.hasPrefix("You are helpful."))
        #expect(once.contains(AssistUniversalModelContext.marker))
        #expect(once.contains("tool_call"))
        let twice = AssistUniversalModelContext.augmentInstructions(once)
        #expect(twice == once)
    }

    @Test func chatRequestAugmentationUsesCompactBlockForSmallContexts() {
        let request = ChatRequest(model: nil, instructions: "", messages: [ChatMessage(.user, "hi")], contextTokens: 4_096)
        let small = AssistUniversalModelContext.augment(request)
        let large = AssistUniversalModelContext.augment(ChatRequest(model: nil, instructions: "", messages: [ChatMessage(.user, "hi")]))
        #expect(small.instructions.contains(AssistUniversalModelContext.marker))
        #expect(small.instructions.count < large.instructions.count)
    }

    @Test func aiMessageConversationGetsSystemBlock() {
        let messages = [AIMessage(role: .user, content: "refactor this")]
        let augmented = AssistUniversalModelContext.augment(messages)
        #expect(augmented.first?.role == .system)
        #expect(augmented.first?.content.contains(AssistUniversalModelContext.marker) == true)
        #expect(AssistUniversalModelContext.augment(augmented).count == augmented.count)
    }

    @Test func parsesTextToolCalls() {
        let text = """
        I'll look at the history.
        ```tool_call
        {"tool": "git_file_history", "arguments": {"path": "README.md", "count": 5}}
        ```
        """
        let calls = AssistUniversalModelContext.parseToolCalls(in: text)
        #expect(calls.count == 1)
        #expect(calls.first?.tool == "git_file_history")
        #expect(calls.first?.argumentsJSON.contains("README.md") == true)
        #expect(AssistUniversalModelContext.parseToolCalls(in: "no calls here").isEmpty)
    }

    @Test func executesTextToolCallsAgainstRealRegistry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("uta-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let builder = AssistContextBuilder(
            logger: AssistLogger(), permissions: AssistPermissionsManager(), memory: AssistMemoryGraph(),
            fileSystem: AssistFileSystem(workspaceRoot: root), git: AssistGitManager(project: nil, workspaceRoot: root))
        let context = builder.buildContext(sessionId: UUID())
        let calls = [AssistUniversalModelContext.ToolCall(tool: "tool_catalog_search", argumentsJSON: #"{"query":"git history file"}"#),
                     AssistUniversalModelContext.ToolCall(tool: "does_not_exist", argumentsJSON: "{}")]
        let output = await AssistUniversalModelContext.executeToolCalls(calls, context: context, allowMutations: false)
        #expect(output.contains("\"tool\": \"tool_catalog_search\", \"ok\": true"))
        #expect(output.contains("git_file_history"))
        #expect(output.contains("Unknown tool id"))
    }

    @Test func bundledSystemSkillsAreValid() {
        let skills = SystemSkillInstallManager.shared.availableSkills()
        #expect(skills.count >= 190)
        for skill in skills {
            #expect(skill.name == skill.directoryName, "front matter name must match folder for \(skill.directoryName)")
            #expect(!skill.description.isEmpty)
            #expect(skill.content.contains("## Workflow"))
        }
        #expect(Set(skills.map(\.name)).count == skills.count)
    }

    @Test func frontMatterParser() {
        let meta = SystemSkillInstallManager.frontMatter("---\nname: demo\ndescription: \"Hello: world\"\n---\n# Demo")
        #expect(meta["name"] == "demo")
        #expect(meta["description"] == "Hello: world")
    }

    @Test func seventyBuiltInActionsWithUniqueCommandsAndSpecs() {
        let actions = BuiltInActionCatalog.actions
        #expect(BuiltInActionCatalog.coreActions.count == 20)
        #expect(BuiltInActionCatalog.extendedActions.count == 50)
        #expect(actions.count == 70)
        #expect(Set(actions.map(\.id)).count == 70)
        for action in actions {
            let spec = BuiltInActionCatalog.specification(for: action)
            #expect(spec?.contains("/\(action.id)") == true, "missing SC Skills/\(action.id).md")
        }
        let legacy: Set<String> = ["goal", "interview", "learn", "boost", "teamwork", "compact", "schedule"]
        #expect(actions.allSatisfy { !legacy.contains($0.id) })
        let registered = Set(AssistToolRegistry.shared.allTools.map(\.id))
        for action in actions {
            for step in action.preflight { #expect(registered.contains(step.toolID), "\(action.id) preflight \(step.toolID)") }
            #expect(BuiltInActionCatalog.basePrompt(for: action, argument: "x").contains(action.command))
        }
        let meta = MetaSlashCommandManager().commands.map(\.id)
        #expect(meta.contains("verify") && meta.contains("release"))
    }
}
