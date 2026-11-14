import Foundation
import Testing
@testable import YcodeAssistant

struct HermesProviderTests {

    final class HermesTestDir {
        let url: URL
        init() throws {
            url = FileManager.default.temporaryDirectory.appendingPathComponent("swiftcode-hermes-test-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        deinit { try? FileManager.default.removeItem(at: url) }
    }

    @Test func modelIDParsing() {
        #expect(HermesModelID.parse("hermes:openrouter:anthropic/claude-sonnet-4-6")?.spec == "openrouter:anthropic/claude-sonnet-4-6")
        #expect(HermesModelID.parse("hermes:gpt-5.5")?.spec == "gpt-5.5")
        #expect(HermesModelID.parse("openrouter:anthropic/claude-sonnet-4-6") == nil)
        #expect(HermesModelID.parse("opencode:anthropic/claude-sonnet-4-5") == nil)
        #expect(HermesModelID.parse("anthropic/claude-sonnet-4-5") == nil)
        #expect(HermesModelID.parse("hermes:") == nil)
        #expect(HermesModelID.parse("hermes:openrouter:") == nil)
        #expect(HermesModelID.parse("") == nil)
    }

    @Test func modelProviderSplit() {
        let withProvider = HermesModelID.parse("hermes:openrouter:anthropic/claude-sonnet-4-6")
        #expect(withProvider?.provider == "openrouter")
        #expect(withProvider?.model == "anthropic/claude-sonnet-4-6")
        let bare = HermesModelID.parse("hermes:gpt-5.5")
        #expect(bare?.provider == nil)
        #expect(bare?.model == "gpt-5.5")
    }

    private func runRequest(
        model: String = "hermes:openrouter:anthropic/claude-sonnet-4-6",
        configuration: HermesConfiguration = HermesConfiguration()
    ) -> HermesRunRequest {
        HermesRunRequest(
            model: model,
            systemPrompt: "Be helpful.",
            userText: "Summarize README.md",
            directory: "/tmp/workspace",
            configuration: configuration
        )
    }

    @Test func argumentConstruction() {
        var config = HermesConfiguration()
        config.toolsets = "file,web"
        config.maxTurns = 25
        let args = HermesProvider.buildArguments(request: runRequest(configuration: config), queryFilePath: "/tmp/q.txt")
        #expect(args == [
            "--in", "/tmp/workspace",
            "chat", "--oneshot", "--query-file", "/tmp/q.txt",
            "--format", "stream-json", "--source", "tool",
            "--provider", "openrouter", "--model", "anthropic/claude-sonnet-4-6",
            "--toolsets", "file,web", "--max-turns", "25",
        ])
        #expect(!args.contains("--yolo") && !args.contains("--api-key") && !args.contains("--base-url"))
        #expect(!args.contains("Be helpful.") && !args.contains("Summarize README.md"))
    }

    @Test func bareModelArguments() {
        let args = HermesProvider.buildArguments(
            request: runRequest(model: "hermes:gpt-5.5"),
            queryFilePath: "/tmp/q.txt")
        #expect(args.contains("--model"))
        #expect(args[args.firstIndex(of: "--model")! + 1] == "gpt-5.5")
        #expect(!args.contains("--provider") && !args.contains("--toolsets") && !args.contains("--max-turns"))
    }

    @Test func defaultModelPassesNoModelFlags() {
        let args = HermesProvider.buildArguments(
            request: runRequest(model: "hermes-default"),
            queryFilePath: "/tmp/q.txt")
        let hasModelFlag = args.contains("--model") || args.contains("--provider")
        #expect(!hasModelFlag || args.contains("hermes-default"))
    }

    @Test func streamEventParsing() {
        #expect(HermesStreamParser.parseLine(#"{"type":"system","model":"anthropic/claude-sonnet-4-6","session_id":"abc"}"#)
            == .system(sessionId: "abc", model: "anthropic/claude-sonnet-4-6"))
        #expect(HermesStreamParser.parseLine(#"{"type":"text","text":"Hello"}"#) == .text("Hello"))
        #expect(HermesStreamParser.parseLine(#"{"type":"tool_use","name":"read_file","input":{"path":"README.md"}}"#)
            == .toolUse(name: "read_file", inputJSON: #"{"path":"README.md"}"#))
        #expect(HermesStreamParser.parseLine(#"{"type":"tool_result","name":"read_file","output":"contents","duration_ms":12,"is_error":false}"#)
            == .toolResult(name: "read_file", output: "contents", isError: false, durationMs: 12))
        #expect(HermesStreamParser.parseLine(#"{"type":"tool_result","name":"terminal","output":"denied","is_error":true}"#)
            == .toolResult(name: "terminal", output: "denied", isError: true, durationMs: nil))
        #expect(HermesStreamParser.parseLine(#"{"type":"result","session_id":"abc","exit_code":0,"text":"Done"}"#)
            == .result(HermesStreamResult(sessionId: "abc", exitCode: 0, text: "Done", error: nil)))
    }

    @Test func malformedStreamLinesIgnored() {
        for line in ["", "   ", "not json", #"{"type":"text"}"#, #"{"type":"mystery","x":1}"#, #"{"type":"tool_use","input":{}}"#] {
            #expect(HermesStreamParser.parseLine(line) == .ignored)
        }
    }

    @Test func promptBuilder() {
        #expect(HermesPromptBuilder.build(systemPrompt: "Be helpful.", objective: "Summarize README.md")
            == "Be helpful.\n\n---\n\nSummarize README.md")
        #expect(HermesPromptBuilder.build(systemPrompt: "", objective: "Task") == "Task")
        #expect(HermesPromptBuilder.build(systemPrompt: "Prompt", objective: "") == "Prompt")
    }

    @Test func configuredModelSpecs() throws {
        let home = try HermesTestDir()
        #expect(HermesProvider.readConfiguredModelSpecs(homeDirectory: home.url) == [])
        let hermesHome = home.url.appendingPathComponent(".hermes", isDirectory: true)
        try FileManager.default.createDirectory(at: hermesHome, withIntermediateDirectories: true)
        try "model:\n  provider: openrouter\n  default: vendor/model-x\n"
            .write(to: hermesHome.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        #expect(HermesProvider.readConfiguredModelSpecs(homeDirectory: home.url) == ["openrouter:vendor/model-x"])
        try "model:\n  provider: openrouter\n"
            .write(to: hermesHome.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        #expect(HermesProvider.readConfiguredModelSpecs(homeDirectory: home.url) == [])
    }

    @Test func modelOutputParsing() {
        #expect(HermesProvider.parseModelOutput("Current model: openrouter:anthropic/claude-sonnet-4-6\nProvider: openrouter")
            == ["openrouter:anthropic/claude-sonnet-4-6"])
        #expect(HermesProvider.parseModelOutput("Model: gpt-5.5") == ["gpt-5.5"])
        #expect(HermesProvider.parseModelOutput("https://example.com/x") == [])
    }

    @Test func assistantProviderReportsAvailability() async {
        let provider = HermesAssistantProvider()
        let availability = await provider.availability()
        switch availability {
        case .ready(let models):
            #expect(!models.isEmpty)
        case .notInstalled(let hint):
            #expect(hint.contains("hermes"))
        default:
            Issue.record("Unexpected availability: \(availability)")
        }
    }
}
