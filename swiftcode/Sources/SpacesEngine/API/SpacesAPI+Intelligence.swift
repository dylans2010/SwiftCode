import Foundation

extension SpacesAPI {
    public func timeMachineStates(limit: Int = 100) throws -> [TimeMachineOps.TimeMachineState] {
        try TimeMachineOps(repo: repo).states(limit: limit)
    }

    @discardableResult
    public func restoreTimeMachineState(rev: String, paths: [String]? = nil) throws -> [String] {
        try TimeMachineOps(repo: repo).restoreState(rev: rev, paths: paths)
    }

    @discardableResult
    public func createRecoveryCheckpoint(operation: String) throws -> ObjectID {
        try RecoveryCheckpointOps(repo: repo).createCheckpointBefore(operation: operation)
    }

    public func recoveryCheckpoints() throws -> [RecoveryCheckpointOps.CheckpointInfo] {
        try RecoveryCheckpointOps(repo: repo).listCheckpoints()
    }

    public func restoreRecoveryCheckpoint(_ rev: String) throws {
        try RecoveryCheckpointOps(repo: repo).restoreCheckpoint(rev)
    }

    @discardableResult
    public func refreshSymbolIndex() throws -> Int {
        try SemanticSearchOps(repo: repo).refreshSymbolIndex()
    }

    public func semanticSearch(query: String, kind: SemanticSearchOps.SymbolKind? = nil,
                               limit: Int = 100) throws -> [SemanticSearchOps.Symbol] {
        try SemanticSearchOps(repo: repo).searchSymbols(query: query, kind: kind, limit: limit)
    }

    public func rankedSemanticSearch(query: String, kind: SemanticSearchOps.SymbolKind? = nil,
                                     limit: Int = 100) throws -> [SemanticSearchOps.RankedSymbol] {
        try SemanticSearchOps(repo: repo).rankedSearchSymbols(query: query, kind: kind, limit: limit)
    }

    public func historySearch(query: String, limit: Int = 100,
                              useRegex: Bool = false) throws -> [HistoricalSearchOps.HistoricalMatch] {
        try HistoricalSearchOps(repo: repo).search(query: query, limit: limit, useRegex: useRegex)
    }

    public func changeImpact(rev: String) throws -> ImpactAnalysisOps.ChangeImpact {
        try ImpactAnalysisOps(repo: repo).impactOf(rev: rev)
    }

    public func dependencyGraph() throws -> DependencyGraphOps.DependencyGraph {
        try DependencyGraphOps(repo: repo).graph()
    }

    public func refreshDependencyGraph() throws -> DependencyGraphOps.DependencyGraph {
        try DependencyGraphOps(repo: repo).refresh()
    }

    public func fileEvolution(path: String, limit: Int = 100) throws -> [FileEvolutionOps.EvolutionStep] {
        try FileEvolutionOps(repo: repo).evolutionOf(path: path, limit: limit)
    }

    @discardableResult
    public func refreshKnowledgeIndex() throws -> [KnowledgeIndexOps.KnowledgeEntry] {
        try KnowledgeIndexOps(repo: repo).refresh()
    }

    public func searchKnowledge(query: String, limit: Int = 100) throws -> [KnowledgeIndexOps.KnowledgeEntry] {
        try KnowledgeIndexOps(repo: repo).searchKnowledge(query: query, limit: limit)
    }

    public func changeRisk(rev: String) throws -> RiskAnalysisOps.ChangeRisk {
        try RiskAnalysisOps(repo: repo).riskOf(rev: rev)
    }

    @discardableResult
    public func recordHealthSnapshot() throws -> HealthHistoryOps.HealthSnapshot {
        try HealthHistoryOps(repo: repo).recordHealth()
    }

    public func healthHistory(limit: Int = 100) throws -> [HealthHistoryOps.HealthSnapshot] {
        try HealthHistoryOps(repo: repo).history(limit: limit)
    }
}
