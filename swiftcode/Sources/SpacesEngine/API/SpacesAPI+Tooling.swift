import Foundation

public extension SpacesAPI {
    public func structuralDiff(from: String, to: String, path: String) throws -> [LanguageDiffOps.DeclarationChange] {
        try LanguageDiffOps(repo: repo).structuralDiff(from: from, to: to, path: path)
    }

    public func symbolHistory(symbol: String, path: String) throws -> [SymbolHistoryOps.SymbolHistoryEntry] {
        try SymbolHistoryOps(repo: repo).symbolHistory(symbol: symbol, path: path)
    }

    public func publicApiSurface(rev: String) throws -> [ApiCompatibilityOps.ApiSurfaceEntry] {
        try ApiCompatibilityOps(repo: repo).publicApiSurface(rev: rev)
    }

    public func apiCompatibilityBetween(from: String, to: String) throws -> [ApiCompatibilityOps.CompatibilityChange] {
        try ApiCompatibilityOps(repo: repo).compatibilityBetween(from: from, to: to)
    }

    @discardableResult
    public func recordBuildResult(commit: ObjectID, command: String,
                                  timeoutSeconds: TimeInterval = 120) throws -> BuildImpactOps.BuildRecord {
        try BuildImpactOps(repo: repo).recordBuildResult(commit: commit, command: command,
                                                         timeoutSeconds: timeoutSeconds)
    }

    public func recordBuildResult(commit: ObjectID, result: BuildImpactOps.BuildResult, durationMs: Int64, failures: [String]) throws {
        try BuildImpactOps(repo: repo).recordBuildResult(commit: commit, result: result, durationMs: durationMs, failures: failures)
    }

    public func buildHistory(commit: ObjectID) throws -> [BuildImpactOps.BuildRecord] {
        try BuildImpactOps(repo: repo).buildHistory(commit: commit)
    }

    @discardableResult
    public func recordTestResult(commit: ObjectID, suite: String, command: String,
                                 timeoutSeconds: TimeInterval = 120) throws -> TestProvenanceOps.TestRecord {
        try TestProvenanceOps(repo: repo).recordTestResult(commit: commit, suite: suite,
                                                           command: command,
                                                           timeoutSeconds: timeoutSeconds)
    }

    public func recordTestResult(commit: ObjectID, suite: String, passed: Int, failed: Int) throws {
        try TestProvenanceOps(repo: repo).recordTestResult(commit: commit, suite: suite, passed: passed, failed: failed)
    }

    public func testResultsFor(commit: ObjectID) throws -> [TestProvenanceOps.TestRecord] {
        try TestProvenanceOps(repo: repo).testResultsFor(commit: commit)
    }

    public func affectedComponents(rev: String) throws -> [String] {
        try ChangeValidationOps(repo: repo).affectedComponents(rev: rev)
    }

    public func validationPlan(rev: String) throws -> [ChangeValidationOps.ValidationPlanEntry] {
        try ChangeValidationOps(repo: repo).validationPlan(rev: rev)
    }

    @discardableResult
    public func runValidation(rev: String, timeoutSeconds: TimeInterval = 300) throws -> [ChangeValidationOps.ValidationRunResult] {
        try ChangeValidationOps(repo: repo).runValidation(rev: rev, timeoutSeconds: timeoutSeconds)
    }

    public func validationRuns(rev: String) throws -> [ChangeValidationOps.ValidationRunResult] {
        try ChangeValidationOps(repo: repo).validationRuns(rev: rev)
    }

    public func automationPipelines() throws -> [AutomationOps.Pipeline] {
        try AutomationOps(repo: repo).automationPipelines()
    }

    public func setAutomationPipelines(_ pipelines: [AutomationOps.Pipeline], allowlistedCommands: [String] = []) throws {
        try AutomationOps(repo: repo).setPipelines(pipelines, allowlistedCommands: allowlistedCommands)
    }

    public func runAutomation(event: AutomationOps.AutomationEvent) throws -> [AutomationOps.AutomationRunResult] {
        try AutomationOps(repo: repo).runAutomation(event: event)
    }

    public func createPatchCollection(name: String, from: String, to: String) throws -> PatchCollectionOps.PatchCollection {
        try PatchCollectionOps(repo: repo).createPatchCollection(name: name, from: from, to: to)
    }

    public func patchCollections() throws -> [PatchCollectionOps.PatchCollection] {
        try PatchCollectionOps(repo: repo).patchCollections()
    }

    public func applyPatchCollection(name: String) throws -> [String] {
        try PatchCollectionOps(repo: repo).applyPatchCollection(name: name)
    }

    public func traceLineOrigin(path: String, line: Int, rev: String = "HEAD") throws -> AttributionOps.LineOrigin {
        try AttributionOps(repo: repo).traceLineOrigin(path: path, line: line, rev: rev)
    }

    public func traceSymbolOrigin(symbol: String) throws -> AttributionOps.SymbolOrigin {
        try AttributionOps(repo: repo).traceSymbolOrigin(symbol: symbol)
    }

    public func profileOperation(_ operation: PerformanceProfilerOps.ProfileOperation) throws -> PerformanceProfilerOps.ProfileSample {
        try PerformanceProfilerOps(repo: repo).profileOperation(operation)
    }

    public func performanceProfile(limit: Int = 1000) throws -> [PerformanceProfilerOps.ProfileSummary] {
        try PerformanceProfilerOps(repo: repo).performanceProfile(limit: limit)
    }
}
