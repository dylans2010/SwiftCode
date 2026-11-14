import Foundation
import Testing
@testable import SpacesEngine

@Suite struct ToolingTests {
    @Test func parserFindsDeclarations() throws {
        let source = "public struct Widget {\n    public var name: String\n    public func greet() -> String {\n        return name\n    }\n}\n\nfunc helper(value: Int) -> Int {\n    return value + 1\n}\n"
        let declarations = SwiftDeclarationParser.parse(source)
        #expect(declarations.contains { $0.kind == .structType && $0.name == "Widget" })
        #expect(declarations.contains { $0.kind == .function && $0.name == "greet" && $0.isPublic })
        #expect(declarations.contains { $0.kind == .function && $0.name == "helper" && !$0.isPublic })
        #expect(declarations.contains { $0.kind == .variable && $0.name == "name" })
    }

    @Test func structuralDiffDetectsChangedAndAdded() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = "public func greet() -> String {\n    return \"hi\"\n}\n"
        let second = "public func greet(name: String) -> String {\n    return \"hello \" + name\n}\n\npublic func farewell() -> String {\n    return \"bye\"\n}\n"
        _ = try SpacesTestSupport.commitFiles(api, ["Main.swift": first], message: "v1")
        _ = try SpacesTestSupport.commitFiles(api, ["Main.swift": second], message: "v2")
        let changes = try api.structuralDiff(from: "HEAD~1", to: "HEAD", path: "Main.swift")
        #expect(changes.contains { $0.name == "greet" && $0.change == .changed })
        #expect(changes.contains { $0.name == "farewell" && $0.change == .added })
        #expect(!changes.contains { $0.name == "greet" && $0.change == .removed })
    }

    @Test func symbolHistoryTracksDeclarationAcrossCommits() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = "public func greet() -> String {\n    return \"hi\"\n}\n"
        let second = "public func greet(name: String) -> String {\n    return \"hello \" + name\n}\n"
        _ = try SpacesTestSupport.commitFiles(api, ["Main.swift": first], message: "v1")
        _ = try SpacesTestSupport.commitFiles(api, ["Main.swift": second], message: "v2")
        let history = try api.symbolHistory(symbol: "greet", path: "Main.swift")
        #expect(history.count == 2)
        #expect(history[0].declaration.signature.contains("name: String"))
        #expect(history[1].declaration.signature.contains("greet()"))
        #expect(history[0].commit != history[1].commit)
    }

    @Test func apiCompatibilityFlagsBreakingChanges() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = "public func keep() -> Int {\n    return 1\n}\n\npublic func removed() -> Int {\n    return 2\n}\n\nfunc internalOnly() -> Int {\n    return 3\n}\n"
        let second = "public func keep(value: Int) -> Int {\n    return value\n}\n\nfunc internalOnly() -> Int {\n    return 3\n}\n"
        _ = try SpacesTestSupport.commitFiles(api, ["Api.swift": first], message: "v1")
        _ = try SpacesTestSupport.commitFiles(api, ["Api.swift": second], message: "v2")
        let surface = try api.publicApiSurface(rev: "HEAD")
        #expect(surface.count == 1)
        #expect(surface[0].name == "keep")
        let changes = try api.apiCompatibilityBetween(from: "HEAD~1", to: "HEAD")
        #expect(changes.contains { $0.name == "removed" && $0.change == .removed && $0.breaking })
        #expect(changes.contains { $0.name == "keep" && $0.change == .changed && $0.breaking })
        #expect(!changes.contains { $0.name == "internalOnly" })
    }

    @Test func buildHistoryRecordsResults() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let commit = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        try api.recordBuildResult(commit: commit, result: .success, durationMs: 120, failures: [])
        try api.recordBuildResult(commit: commit, result: .failure, durationMs: 45, failures: ["FlakyTest.testCrash"])
        let history = try api.buildHistory(commit: commit)
        #expect(history.count == 2)
        #expect(history[0].result == .success)
        #expect(history[1].failures == ["FlakyTest.testCrash"])
        #expect(history[1].durationMs == 45)
    }

    @Test func testProvenanceRecordsHead() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let commit = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        try api.recordTestResult(commit: commit, suite: "CoreTests", passed: 10, failed: 0)
        try api.recordTestResult(commit: commit, suite: "CoreTests", passed: 9, failed: 1)
        let results = try api.testResultsFor(commit: commit)
        #expect(results.count == 2)
        #expect(results[0].worktreeHead == commit.hex)
        #expect(results[0].passed == 10 && results[0].failed == 0)
        #expect(results[1].failed == 1)
    }

    @Test func validationPlanMapsComponentToSuite() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["Sources/Widget/Widget.swift": "public struct Widget {\n    public var name: String\n}\n"], message: "widget")
        _ = try SpacesTestSupport.commitFiles(api, ["Tests/WidgetTests/WidgetTests.swift": "import Testing\n"], message: "tests")
        let components = try api.affectedComponents(rev: "HEAD")
        #expect(components == ["Widget"])
        let plan = try api.validationPlan(rev: "HEAD")
        #expect(plan.count == 1)
        #expect(plan[0].component == "Widget")
        #expect(plan[0].testSuite == "WidgetTests")
        #expect(plan[0].testSuiteExists)
    }

    @Test func automationRunsAllowlistedAndSkipsOthers() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let pipelines = [
            AutomationOps.Pipeline(id: "echoer", event: .postCommit, command: "echo automated", enabled: true),
            AutomationOps.Pipeline(id: "blocked", event: .postCommit, command: "echo blocked", enabled: true),
            AutomationOps.Pipeline(id: "disabled", event: .postCommit, command: "echo automated", enabled: false)
        ]
        try api.setAutomationPipelines(pipelines, allowlistedCommands: ["echo automated"])
        #expect(try api.automationPipelines().count == 3)
        let results = try api.runAutomation(event: .postCommit)
        #expect(results.count == 3)
        let ran = results.first { $0.pipelineId == "echoer" }
        #expect(ran?.status == .executed)
        #expect(ran?.stdout.contains("automated") == true)
        #expect(ran?.exitCode == 0)
        #expect(results.first { $0.pipelineId == "blocked" }?.status == .skipped)
        #expect(results.first { $0.pipelineId == "disabled" }?.status == .skipped)
        let other = try api.runAutomation(event: .postMerge)
        #expect(other.isEmpty)
    }

    @Test func patchCollectionRoundTrips() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let first = "func run() -> String {\n    return \"one\"\n}\n"
        let second = "func run() -> String {\n    return \"two\"\n}\n"
        _ = try SpacesTestSupport.commitFiles(api, ["App.swift": first], message: "v1")
        _ = try SpacesTestSupport.commitFiles(api, ["App.swift": second], message: "v2")
        let collection = try api.createPatchCollection(name: "fix", from: "HEAD~1", to: "HEAD")
        #expect(collection.patches.count == 1)
        #expect(collection.patches[0].patchText.contains("two"))
        #expect(try api.patchCollections().map { $0.name }.contains("fix"))
        try api.reset(to: "HEAD~1", mode: .hard)
        #expect(try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8) == first)
        let applied = try api.applyPatchCollection(name: "fix")
        #expect(applied == ["App.swift"])
        #expect(try String(contentsOf: url.appendingPathComponent("App.swift"), encoding: .utf8) == second)
    }

    @Test func attributionFollowsRename() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let source = "public func traced() -> Int {\n    return 7\n}\n"
        let first = try SpacesTestSupport.commitFiles(api, ["Old.swift": source], message: "create")
        try api.move("Old.swift", "New.swift")
        _ = try api.commit(message: "rename")
        let origin = try api.traceLineOrigin(path: "New.swift", line: 2)
        #expect(origin.commit == first)
        #expect(origin.renamedFrom == "Old.swift")
        #expect(origin.text.contains("return 7"))
        let symbolOrigin = try api.traceSymbolOrigin(symbol: "traced")
        #expect(symbolOrigin.entries.count == 2)
        #expect(symbolOrigin.firstSeenCommit == first)
        #expect(symbolOrigin.firstSeenPath == "Old.swift")
        #expect(symbolOrigin.entries[0].path == "New.swift")
    }

    @Test func profilerRecordsRealDurations() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, ["f.txt": "1"], message: "base")
        let sample = try api.profileOperation(.status)
        #expect(sample.operation == "status")
        #expect(sample.durationMs >= 1)
        #expect(sample.objectCount >= 1)
        #expect(sample.bytes > 0)
        _ = try api.profileOperation(.log)
        let profile = try api.performanceProfile()
        #expect(profile.contains { $0.operation == "status" && $0.samples >= 1 })
        #expect(profile.contains { $0.operation == "log" && $0.samples >= 1 })
        #expect(profile.allSatisfy { $0.averageDurationMs >= 1 })
    }
}
