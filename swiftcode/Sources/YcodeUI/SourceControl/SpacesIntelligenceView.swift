import Foundation
import SwiftUI
import SpacesEngine

@Observable
@MainActor
final class SpacesIntelligenceModel {
    let workspace: SpacesWorkspaceModel
    var error: String?
    var notice: String?
    var states: [TimeMachineOps.TimeMachineState] = []
    var checkpoints: [RecoveryCheckpointOps.CheckpointInfo] = []
    var symbols: [SemanticSearchOps.Symbol] = []
    var symbolKind: SemanticSearchOps.SymbolKind?
    var semanticQuery = ""
    var historyMatches: [HistoricalSearchOps.HistoricalMatch] = []
    var historyQuery = ""
    var historyUseRegex = false
    var evolutionPath = ""
    var evolution: [FileEvolutionOps.EvolutionStep] = []
    var impactRev = "HEAD"
    var impact: ImpactAnalysisOps.ChangeImpact?
    var risk: RiskAnalysisOps.ChangeRisk?
    var graph: DependencyGraphOps.DependencyGraph?
    var knowledgeQuery = ""
    var knowledge: [KnowledgeIndexOps.KnowledgeEntry] = []
    var healthHistory: [HealthHistoryOps.HealthSnapshot] = []
    var checkpointOperation = ""

    init(workspace: SpacesWorkspaceModel) {
        self.workspace = workspace
    }

    func refreshAll() {
        loadStates()
        loadCheckpoints()
        loadHealthHistory()
        loadGraph()
        loadKnowledge()
    }

    private func load<T: Sendable>(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> T, assign: @escaping @MainActor @Sendable (T) -> Void) {
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let value = try body(api)
                await MainActor.run { assign(value) }
            } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
        }
    }

    private func perform(_ what: String, _ body: @escaping @Sendable (SpacesAPI) throws -> Void) {
        guard let api = workspace.api else { return }
        Task.detached {
            do { try body(api) } catch {
                await MainActor.run { self.error = "\(what): \(error.localizedDescription)" }
            }
            await MainActor.run { self.refreshAll() }
        }
    }

    func loadStates() {
        load("time machine states", { try $0.timeMachineStates(limit: 100) }, assign: { self.states = $0 })
    }

    func loadCheckpoints() {
        load("recovery checkpoints", { try $0.recoveryCheckpoints() }, assign: { self.checkpoints = $0 })
    }

    func loadHealthHistory() {
        load("health history", { try $0.healthHistory(limit: 100) }, assign: { self.healthHistory = $0 })
    }

    func loadGraph() {
        load("dependency graph", { try $0.dependencyGraph() }, assign: { self.graph = $0 })
    }

    func loadKnowledge() {
        let query = knowledgeQuery
        if query.isEmpty {
            load("knowledge index", { try $0.refreshKnowledgeIndex() }, assign: { self.knowledge = $0 })
        } else {
            load("knowledge search", { try $0.searchKnowledge(query: query, limit: 100) }, assign: { self.knowledge = $0 })
        }
    }

    func restoreState(_ state: TimeMachineOps.TimeMachineState) {
        guard let oid = state.oid else {
            error = "restore: state \(state.title) has no revision to restore"
            return
        }
        let rev = oid.hex
        perform("restore time machine state") { _ = try $0.restoreTimeMachineState(rev: rev) }
    }

    func createCheckpoint() {
        let operation = checkpointOperation
        guard !operation.isEmpty else {
            error = "recovery checkpoint: enter the operation name first"
            return
        }
        perform("create recovery checkpoint") { _ = try $0.createRecoveryCheckpoint(operation: operation) }
        checkpointOperation = ""
    }

    func restoreCheckpoint(_ checkpoint: RecoveryCheckpointOps.CheckpointInfo) {
        let rev = checkpoint.oid.hex
        perform("restore recovery checkpoint") { try $0.restoreRecoveryCheckpoint(rev) }
    }

    func refreshSymbolIndex() {
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let count = try api.refreshSymbolIndex()
                await MainActor.run { self.notice = "Symbol index refreshed: \(count) symbols" }
            } catch {
                await MainActor.run { self.error = "refresh symbol index: \(error.localizedDescription)" }
            }
        }
    }

    func runSemanticSearch() {
        let query = semanticQuery
        let kind = symbolKind
        load("semantic search", { try $0.semanticSearch(query: query, kind: kind, limit: 100) }, assign: { self.symbols = $0 })
    }

    func runHistorySearch() {
        let query = historyQuery
        let useRegex = historyUseRegex
        load("history search", { try $0.historySearch(query: query, limit: 100, useRegex: useRegex) }, assign: { self.historyMatches = $0 })
    }

    func runFileEvolution() {
        let path = evolutionPath
        guard !path.isEmpty else {
            error = "file evolution: enter a file path first"
            return
        }
        load("file evolution", { try $0.fileEvolution(path: path, limit: 100) }, assign: { self.evolution = $0 })
    }

    func runImpactAndRisk() {
        let rev = impactRev
        load("change impact", { try $0.changeImpact(rev: rev) }, assign: { self.impact = $0 })
        load("change risk", { try $0.changeRisk(rev: rev) }, assign: { self.risk = $0 })
    }

    func refreshGraph() {
        load("refresh dependency graph", { try $0.refreshDependencyGraph() }, assign: { self.graph = $0 })
    }

    func recordHealthSnapshot() {
        guard let api = workspace.api else { return }
        Task.detached {
            do {
                let snapshot = try api.recordHealthSnapshot()
                await MainActor.run {
                    self.notice = "Health snapshot recorded: score \(snapshot.score)/100"
                    self.loadHealthHistory()
                }
            } catch {
                await MainActor.run { self.error = "record health snapshot: \(error.localizedDescription)" }
            }
        }
    }

    static func dateString(_ timestamp: Int64) -> String {
        Date(timeIntervalSince1970: TimeInterval(timestamp)).formatted(date: .abbreviated, time: .shortened)
    }
}

struct SpacesIntelligenceView: View {
    @State private var model: SpacesIntelligenceModel

    init(workspace: SpacesWorkspaceModel) {
        _model = State(initialValue: SpacesIntelligenceModel(workspace: workspace))
    }

    var body: some View {
        Form {
            if let error = model.error {
                Section {
                    HStack {
                        Text(error).foregroundStyle(.red)
                        Spacer()
                        Button("Dismiss") { model.error = nil }
                    }
                }
            }
            if let notice = model.notice {
                Section {
                    HStack {
                        Text(notice)
                        Spacer()
                        Button("Dismiss") { model.notice = nil }
                    }
                }
            }
            Section("Time Machine") {
                HStack {
                    Button("Refresh States") { model.loadStates() }
                    Button("Refresh Checkpoints") { model.loadCheckpoints() }
                }
                if model.states.isEmpty {
                    Text("No recorded states yet. States appear after commits and snapshots.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(model.states.enumerated()), id: \.offset) { _, state in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(state.title).font(.subheadline)
                            Text("\(state.kind.rawValue) • \(SpacesIntelligenceModel.dateString(state.timestamp))")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(state.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Restore") { model.restoreState(state) }
                            .disabled(state.oid == nil)
                    }
                }
            }
            Section("Recovery Checkpoints") {
                HStack {
                    TextField("Operation name", text: $model.checkpointOperation)
                    Button("Create Checkpoint") { model.createCheckpoint() }
                        .disabled(model.checkpointOperation.isEmpty)
                }
                ForEach(Array(model.checkpoints.enumerated()), id: \.offset) { _, checkpoint in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(checkpoint.message).font(.subheadline)
                            Text("\(checkpoint.operation) • \(SpacesIntelligenceModel.dateString(checkpoint.timestamp))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Restore") { model.restoreCheckpoint(checkpoint) }
                    }
                }
            }
            Section("Semantic Search") {
                HStack {
                    TextField("Symbol query", text: $model.semanticQuery)
                    Picker("Kind", selection: $model.symbolKind) {
                        Text("Any").tag(nil as SemanticSearchOps.SymbolKind?)
                        ForEach(SemanticSearchOps.SymbolKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue).tag(kind as SemanticSearchOps.SymbolKind?)
                        }
                    }
                    .pickerStyle(.menu)
                    Button("Search") { model.runSemanticSearch() }
                        .disabled(model.semanticQuery.isEmpty)
                    Button("Refresh Index") { model.refreshSymbolIndex() }
                }
                ForEach(Array(model.symbols.enumerated()), id: \.offset) { _, symbol in
                    HStack {
                        Text(symbol.name).font(.callout.monospaced())
                        Text(symbol.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(symbol.file):\(symbol.line)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            Section("History Search") {
                HStack {
                    TextField("Search history contents", text: $model.historyQuery)
                    Toggle("Regex", isOn: $model.historyUseRegex).controlSize(.small)
                    Button("Search") { model.runHistorySearch() }
                        .disabled(model.historyQuery.isEmpty)
                }
                ForEach(Array(model.historyMatches.enumerated()), id: \.offset) { _, match in
                    VStack(alignment: .leading) {
                        Text(match.text).font(.callout.monospaced())
                        Text("\(match.path):\(match.line) • \(match.commit.hex.prefix(8)) • \(match.summary)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("File Evolution") {
                HStack {
                    TextField("File path", text: $model.evolutionPath)
                    Button("Show Evolution") { model.runFileEvolution() }
                        .disabled(model.evolutionPath.isEmpty)
                }
                ForEach(Array(model.evolution.enumerated()), id: \.offset) { _, step in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(step.summary).font(.subheadline)
                            Text("\(step.path) • \(SpacesIntelligenceModel.dateString(step.timestamp))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(step.change.rawValue).font(.caption).foregroundStyle(.secondary)
                        Text(step.commit.hex.prefix(8)).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Change Impact and Risk") {
                HStack {
                    TextField("Revision", text: $model.impactRev)
                    Button("Analyze") { model.runImpactAndRisk() }
                        .disabled(model.impactRev.isEmpty)
                }
                if let risk = model.risk {
                    HStack {
                        Text("Risk score").font(.subheadline)
                        Spacer()
                        Text("\(risk.score) (\(risk.scoreKind))").font(.headline)
                    }
                    ForEach(Array(risk.factors.enumerated()), id: \.offset) { _, factor in
                        VStack(alignment: .leading) {
                            Text("\(factor.name): \(factor.valueText)").font(.subheadline)
                            Text(factor.explanation).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let impact = model.impact {
                    Text("Changed files: \(impact.changedFiles.joined(separator: ", "))")
                        .font(.caption)
                    Text("Reverse dependents: \(impact.reverseDependents.joined(separator: ", "))")
                        .font(.caption)
                    Text("Directories: \(impact.directories.joined(separator: ", "))")
                        .font(.caption)
                    ForEach(Array(impact.declaredSymbols.enumerated()), id: \.offset) { _, symbol in
                        Text("\(symbol.name) (\(symbol.kind.rawValue)) — \(symbol.file):\(symbol.line)")
                            .font(.caption.monospaced())
                    }
                }
            }
            Section("Dependency Graph") {
                HStack {
                    Button("Refresh Graph") { model.refreshGraph() }
                    if let graph = model.graph {
                        Text("\(graph.nodes.count) nodes, \(graph.edges.count) edges")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let graph = model.graph {
                    ForEach(Array(graph.edges.prefix(50).enumerated()), id: \.offset) { _, edge in
                        Text("\(edge.from) → \(edge.to)").font(.caption.monospaced())
                    }
                }
            }
            Section("Knowledge Index") {
                HStack {
                    TextField("Search knowledge (blank refreshes the index)", text: $model.knowledgeQuery)
                    Button("Search / Refresh") { model.loadKnowledge() }
                }
                ForEach(Array(model.knowledge.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading) {
                        Text(entry.path).font(.callout.monospaced())
                        Text("\(entry.commitCount) commits • \(entry.symbols.count) symbols • imports: \(entry.imports.joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Health History") {
                HStack {
                    Button("Record Health Snapshot") { model.recordHealthSnapshot() }
                    Button("Refresh History") { model.loadHealthHistory() }
                }
                ForEach(Array(model.healthHistory.enumerated()), id: \.offset) { _, snapshot in
                    HStack {
                        Text(SpacesIntelligenceModel.dateString(snapshot.timestamp)).font(.subheadline)
                        Spacer()
                        Text("Score \(snapshot.score)/100").font(.caption)
                        Text("\(snapshot.errors) errors, \(snapshot.warnings) warnings, \(snapshot.okCount) ok")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshAll() }
    }
}
