import Foundation
import Testing
@testable import YcodeAssistant

@Suite("Slash menu gap tests")
struct SlashMenuGapTests {

    @Test("Empty query returns the whole catalog")
    func searchEmptyReturnsAll() {
        let manager = MetaSlashCommandManager()
        #expect(manager.searchCommands(query: "") == manager.commands)
        #expect(!manager.commands.isEmpty)
    }

    @Test("The four host-effect commands are in the catalog")
    func effectCommandsPresent() {
        let manager = MetaSlashCommandManager()
        for id in ["effort", "model", "clear", "login"] {
            #expect(manager.searchCommands(query: "/\(id)").contains { $0.id == id }, "missing /\(id)")
        }
    }

    @Test("Search matches name, title, description, and category; a leading slash is ignored")
    func searchMatchesFields() {
        let manager = MetaSlashCommandManager()
        #expect(manager.searchCommands(query: "eff").contains { $0.id == "effort" })
        #expect(manager.searchCommands(query: "/model").contains { $0.id == "model" })
        #expect(manager.searchCommands(query: "zzz-no-such-command").isEmpty)
        #expect(manager.searchCommands(query: "session").contains { $0.id == "clear" })
    }

    @Test("Effect commands return Legacy's verbatim text and a host-side effect")
    func effectCommandsReturnVerbatimText() {
        let manager = MetaSlashCommandManager()
        let effort = manager.commands.first { $0.id == "effort" }!
        let (effortText, effortEffect) = manager.executeCommand(effort, argument: "high")
        #expect(effortText == "Meta reasoning effort set to 'high'.")
        #expect(effortEffect == .setReasoningEffort("high"))

        let model = manager.commands.first { $0.id == "model" }!
        let (modelText, modelEffect) = manager.executeCommand(model, argument: "opus")
        #expect(modelText == "Meta Assist model switched to 'opus'.")
        #expect(modelEffect == .setModel("opus"))

        let clear = manager.commands.first { $0.id == "clear" }!
        let (clearText, clearEffect) = manager.executeCommand(clear, argument: nil)
        #expect(clearText == "Cleared Assist session.")
        #expect(clearEffect == .clearSession)

        let login = manager.commands.first { $0.id == "login" }!
        let (loginText, loginEffect) = manager.executeCommand(login, argument: nil)
        #expect(loginText == "Starting Meta authentication flow...")
        #expect(loginEffect == .startLogin)
    }

    @Test("A command with no host-side effect inserts its text")
    func plainCommandInsertsText() {
        let manager = MetaSlashCommandManager()
        let plain = MetaSlashCommand(
            id: "review", name: "/review", title: "Review", description: "Review the diff",
            syntax: "/review", category: "General")
        let (bareText, bareEffect) = manager.executeCommand(plain, argument: nil)
        #expect(bareText == "/review")
        #expect(bareEffect == .insertText("/review"))
        let (argText, argEffect) = manager.executeCommand(plain, argument: "staged")
        #expect(argText == "/review staged")
        #expect(argEffect == .insertText("/review staged"))
    }

    @Test("Palette starts on the first match and wraps on move up/down")
    func paletteSelectionWraps() {
        var state = SlashCommandPaletteState(manager: MetaSlashCommandManager(), query: "")
        let count = state.filtered.count
        #expect(count > 1)
        #expect(state.selectedIndex == 0)
        state.moveUp()
        #expect(state.selectedIndex == count - 1)
        state.moveDown()
        #expect(state.selectedIndex == 0)
        state.moveDown()
        #expect(state.selectedIndex == 1)
    }

    @Test("Palette re-filters on a new query and clears the selection when nothing matches")
    func paletteRefilters() {
        var state = SlashCommandPaletteState(manager: MetaSlashCommandManager(), query: "")
        state.update(query: "eff")
        #expect(state.selected?.id == "effort")
        state.update(query: "zzz-no-such-command")
        #expect(state.filtered.isEmpty)
        #expect(state.selected == nil)
        #expect(state.commitText(argument: nil) == nil)
        #expect(state.shouldSendImmediately(argument: nil) == false)
    }

    @Test("Palette commit sends immediately only for host-effect commands")
    func paletteCommitSendImmediately() {
        var state = SlashCommandPaletteState(manager: MetaSlashCommandManager(), query: "eff")
        #expect(state.commitText(argument: "high") == "Meta reasoning effort set to 'high'.")
        #expect(state.shouldSendImmediately(argument: "high") == true)

        state.update(query: "clear")
        #expect(state.commitText(argument: nil) == "Cleared Assist session.")
        #expect(state.shouldSendImmediately(argument: nil) == true)

        let plainManager = MetaSlashCommandManager(commands: [
            MetaSlashCommand(
                id: "review", name: "/review", title: "Review", description: "Review the diff",
                syntax: "/review", category: "General"),
        ])
        var plain = SlashCommandPaletteState(manager: plainManager, query: "")
        #expect(plain.commitText(argument: nil) == "/review")
        #expect(plain.shouldSendImmediately(argument: nil) == false)
    }

    @Test("Slash commands are on by default")
    func slashCommandsOnByDefault() {
        #expect(AssistantSettings().useMetaSlashCommands == true)
    }

    private func candidates() -> [AssistCandidateModel] {
        [
            AssistCandidateModel(id: "a-1", provider: .ollama),
            AssistCandidateModel(id: "a-2", provider: .ollama),
            AssistCandidateModel(id: "b-1", provider: .ollama),
        ]
    }

    @Test("Failover is off when auto-switch is off")
    @MainActor func failoverOffWithoutAutoSwitch() async {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        let restore = AssistModelRoutingTests.useFailoverEnvironment(candidates(), autoSwitch: false)
        defer { restore() }
        let router = AssistModelRouter()
        let result = await router.handleTurnFailure(
            failedModel: AssistAvailableModel(candidate: candidates()[0]),
            error: E(message: "429 Too Many Requests"),
            completedTurnContent: "partial", executedToolsCount: 0,
            objective: "")
        #expect(result == nil)
    }

    @Test("A 429 fails over to the next model and carries the partial output forward")
    @MainActor func failoverOnRateLimit() async {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        let all = candidates()
        let restore = AssistModelRoutingTests.useFailoverEnvironment(all, autoSwitch: true)
        defer { restore() }
        let router = AssistModelRouter()
        let result = await router.handleTurnFailure(
            failedModel: AssistAvailableModel(candidate: all[0]),
            error: E(message: "429 Too Many Requests"),
            completedTurnContent: "partial output", executedToolsCount: 2,
            objective: "")
        #expect(result != nil)
        #expect(result?.nextModel.id != all[0].id)
        #expect(result?.continuationPrompt.contains("partial output") == true)
    }

    @Test("A quota failure excludes the whole failed provider")
    @MainActor func quotaFailureExcludesProvider() async {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        let all = candidates()
        let restore = AssistModelRoutingTests.useFailoverEnvironment(all, autoSwitch: true)
        defer { restore() }
        let router = AssistModelRouter()
        let result = await router.handleTurnFailure(
            failedModel: AssistAvailableModel(candidate: all[0]),
            error: E(message: "quota exceeded"),
            completedTurnContent: "", executedToolsCount: 0,
            objective: "")
        
        
        #expect(result == nil)
    }

    @Test("Failover returns nil when no eligible model remains")
    @MainActor func failoverNilWhenNothingEligible() async {
        struct E: LocalizedError { let message: String; var errorDescription: String? { message } }
        let only = [candidates()[0]]
        let restore = AssistModelRoutingTests.useFailoverEnvironment(only, autoSwitch: true)
        defer { restore() }
        let router = AssistModelRouter()
        let result = await router.handleTurnFailure(
            failedModel: AssistAvailableModel(candidate: only[0]),
            error: E(message: "429 Too Many Requests"),
            completedTurnContent: "", executedToolsCount: 0,
            objective: "")
        #expect(result == nil)
    }
}
