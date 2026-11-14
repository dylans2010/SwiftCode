import Foundation
import Testing
@testable import SpacesEngine

@Suite struct IntelligenceTests {
    @Test func timeMachineStatesAndRestore() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(
            api, ["a.txt": "version one\n"], message: "first")
        _ = try SpacesTestSupport.commitFiles(
            api, ["a.txt": "version two\n"], message: "second")
        _ = try api.snapshot(message: "manual snap")

        let states = try api.timeMachineStates(limit: 100)
        #expect(states.filter { $0.kind == .commit }.count >= 2)
        #expect(states.contains { $0.kind == .snapshot })

        let restored = try api.restoreTimeMachineState(rev: first.hex, paths: ["a.txt"])
        #expect(restored == ["a.txt"])
        let contents = try String(contentsOf: url.appendingPathComponent("a.txt"), encoding: .utf8)
        #expect(contents == "version one\n")
    }

    @Test func recoveryCheckpointRoundTrip() throws {
        let (_, api, url) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(
            api, ["notes.txt": "base content\n"], message: "base")
        let oid = try api.createRecoveryCheckpoint(operation: "merge")
        #expect(oid.hex.count == 64)

        let checkpoints = try api.recoveryCheckpoints()
        #expect(checkpoints.contains { $0.oid == oid && $0.operation == "merge" })

        try SpacesTestSupport.write(
            "changed content\n", to: url.appendingPathComponent("notes.txt"))
        try api.restoreRecoveryCheckpoint(oid.hex)
        let contents = try String(contentsOf: url.appendingPathComponent("notes.txt"), encoding: .utf8)
        #expect(contents == "base content\n")
    }

    @Test func semanticSearchFindsDeclarations() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "App.swift": "import Foundation\npublic struct Widget {\n    public var title: String\n    public func greet() -> String {\n        return title\n    }\n}\n",
        ], message: "add app")
        let count = try api.refreshSymbolIndex()
        #expect(count > 0)

        let functions = try api.semanticSearch(query: "greet")
        #expect(functions.contains { $0.name == "greet" && $0.kind == .function && $0.file == "App.swift" })
        let structs = try api.semanticSearch(query: "Widget", kind: .structType)
        #expect(structs.contains { $0.name == "Widget" })
        let imports = try api.semanticSearch(query: "Foundation", kind: .moduleImport)
        #expect(imports.contains { $0.name == "Foundation" })
    }

    @Test func historySearchFindsOldText() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        let first = try SpacesTestSupport.commitFiles(api, [
            "Main.swift": "import Foundation\nlet marker = \"alpha marker text\"\n",
        ], message: "first")
        _ = try SpacesTestSupport.commitFiles(api, [
            "Main.swift": "import Foundation\nlet marker = \"beta text\"\n",
        ], message: "second")

        let matches = try api.historySearch(query: "alpha marker")
        #expect(matches.contains { $0.commit == first && $0.path == "Main.swift" && $0.line == 2 })
        #expect(matches.allSatisfy { $0.text.contains("alpha") })

        let regexMatches = try api.historySearch(query: "alp.a marker", useRegex: true)
        #expect(regexMatches.contains { $0.commit == first })
    }

    @Test func changeImpactFindsSymbolsAndDependents() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "A.swift": "import Foundation\npublic func sharedHelper() {}\n",
            "B.swift": "import Foundation\npublic func useIt() {\n    sharedHelper()\n}\n",
        ], message: "base")
        let second = try SpacesTestSupport.commitFiles(api, [
            "A.swift": "import Foundation\npublic func sharedHelper() {}\npublic func extra() {}\n",
        ], message: "extend A")

        let impact = try api.changeImpact(rev: second.hex)
        #expect(impact.changedFiles == ["A.swift"])
        #expect(impact.declaredSymbols.contains { $0.name == "sharedHelper" })
        #expect(impact.reverseDependents == ["B.swift"])
        #expect(impact.directories == ["."])
    }

    @Test func dependencyGraphParsesImports() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "A.swift": "import Foundation\npublic struct A {}\n",
            "B.swift": "import Alamofire\nimport Foundation\npublic struct B {}\n",
        ], message: "add modules")
        let graph = try api.refreshDependencyGraph()
        #expect(graph.edges.contains { $0.from == "A.swift" && $0.to == "Foundation" })
        #expect(graph.edges.contains { $0.from == "B.swift" && $0.to == "Alamofire" })
        #expect(graph.nodes.contains("B.swift"))
        #expect(graph.nodes.contains("Alamofire"))

        let cached = try api.dependencyGraph()
        #expect(cached.edges.count == graph.edges.count)
    }

    @Test func fileEvolutionFollowsRename() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(
            api, ["Old.swift": "public struct Old {}\n"], message: "add old")
        try api.move("Old.swift", "New.swift")
        _ = try api.commit(message: "rename file")

        let steps = try api.fileEvolution(path: "New.swift")
        #expect(steps.count >= 2)
        #expect(steps.first?.change == .renamed)
        #expect(steps.first?.oldPath == "Old.swift")
        #expect(steps.first?.path == "New.swift")
        #expect(steps.last?.change == .added)
        #expect(steps.last?.path == "Old.swift")
    }

    @Test func knowledgeIndexSearchesStructure() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(api, [
            "App.swift": "import Foundation\npublic struct Widget {\n    public func greet() {}\n}\n",
        ], message: "add app")
        let entries = try api.refreshKnowledgeIndex()
        let app = entries.first { $0.path == "App.swift" }
        #expect(app != nil)
        #expect(app?.commitCount == 1)
        #expect(app?.lastModifiedCommit != nil)
        #expect(app?.symbols.contains { $0.name == "Widget" } == true)
        #expect(app?.imports.contains("Foundation") == true)

        let found = try api.searchKnowledge(query: "Widget")
        #expect(found.contains { $0.path == "App.swift" })
        let byPath = try api.searchKnowledge(query: "App.swift")
        #expect(byPath.count == 1)
    }

    @Test func changeRiskIsMeasuredHeuristic() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(
            api, ["f.txt": "one\n"], message: "base")
        let second = try SpacesTestSupport.commitFiles(
            api, ["f.txt": "one\ntwo\nthree\n"], message: "grow")
        let risk = try api.changeRisk(rev: second.hex)
        #expect(risk.scoreKind == "heuristic")
        #expect(risk.score >= 0 && risk.score < 50)
        let files = risk.factors.first { $0.name == "filesChanged" }
        #expect(files?.measuredValue == 1)
        let added = risk.factors.first { $0.name == "linesAdded" }
        #expect(added?.measuredValue == 2)
        let merge = risk.factors.first { $0.name == "mergeCommit" }
        #expect(merge?.measuredValue == 0)
    }

    @Test func healthHistoryAppendsSnapshots() throws {
        let (_, api, _) = try SpacesTestSupport.makeRepo()
        _ = try SpacesTestSupport.commitFiles(
            api, ["f.txt": "one\n"], message: "base")
        let first = try api.recordHealthSnapshot()
        #expect(first.score >= 0 && first.score <= 100)
        _ = try api.recordHealthSnapshot()
        let history = try api.healthHistory(limit: 10)
        #expect(history.count == 2)
        #expect(history.allSatisfy { $0.score >= 0 && $0.score <= 100 })
    }
}
