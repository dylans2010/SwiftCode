import Foundation

public final class AssistToolRegistry {
    private var tools: [String: AssistTool] = [:]

    public init() {
        registerAllTools()
    }

    private func registerAllTools() {
        // File System
        register(AssistReadFileTool())
        register(AssistWriteFileTool())
        register(AssistAppendFileTool())
        register(AssistDeleteFileTool())
        register(AssistMoveFileTool())
        register(AssistCopyFileTool())
        register(AssistRenameFileTool())
        register(AssistCreateDirectoryTool())
        register(AssistDeleteDirectoryTool())
        register(AssistReadDirectoryTool())
        register(AssistTreeViewTool())

        // Search & Analysis
        register(AssistSearchTool())
        register(AssistRegexSearchTool())
        register(AssistSymbolSearchTool())
        register(AssistDependencyGraphTool())
        register(AssistCodeSummaryTool())
        register(AssistLintTool())
        register(AssistComplexityAnalysisTool())

        // Code Editing
        register(AssistReplaceInFileTool())
        register(AssistMultiFileEditTool())
        register(AssistRefactorTool())
        register(AssistFormatCodeTool())
        register(AssistGenerateFileTool())
        register(AssistInsertCodeBlockTool())

        // Git
        register(AssistGitInitTool())
        register(AssistGitStatusTool())
        register(AssistGitAddTool())
        register(AssistGitCommitTool())
        register(AssistGitBranchTool())
        register(AssistGitCheckoutTool())
        register(AssistGitMergeTool())
        register(AssistGitDiffTool())
        register(AssistGitStashTool())
        register(AssistGitPRTool())

        // Execution
        register(AssistRunCommandTool())
        register(AssistRunScriptTool())
        register(AssistBuildProjectTool())
        register(AssistTestRunnerTool())
        register(AssistLogCaptureTool())
        register(AssistEnvironmentInfoTool())

        // Intelligence
        register(AssistPlanTaskTool())
        register(AssistBreakdownTaskTool())
        register(AssistAutoFixErrorsTool())
        register(AssistGenerateTestsTool())
        register(AssistExplainCodeTool())

        // Memory
        register(AssistStoreMemoryTool())
        register(AssistRetrieveMemoryTool())
        register(AssistClearMemoryTool())
        register(AssistContextSnapshotTool())

        // Safety
        register(AssistSnapshotProjectTool())
        register(AssistRestoreSnapshotTool())
        register(AssistUndoTool())
        register(AssistValidateChangesTool())
    }

    public func register(_ tool: AssistTool) {
        tools[tool.id] = tool
    }

    public func getTool(_ id: String) -> AssistTool? {
        return tools[id]
    }

    public var allTools: [AssistTool] {
        return Array(tools.values).sorted(by: { $0.id < $1.id })
    }
}
