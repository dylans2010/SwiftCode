import Foundation

/// A single tool exposed to Decompile Assist. Implementations are structs;
/// `execute` returns a JSON string (success payload or `{"ok":false,"error":…}`).
public protocol DecompileAssistTool: Sendable {
    /// Stable tool id used in `tools` declarations and dispatch.
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    /// JSON-schema-ish description of arguments (`type: object` + `properties`).
    var inputSchema: [String: Any] { get }
    /// Whether the tool mutates analysis state and requires `approved: true`.
    var requiresApproval: Bool { get }
    func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String
}

/// Registry of all Decompile Assist tools. Dispatch enforces the approval
/// policy: tools with `requiresApproval` reject calls that do not include
/// `"approved": true` in their arguments.
///
/// Approval semantics mirror `Security/PermissionPolicy`: read-only query
/// tools run without prompting; every tool that mutates analysis state
/// (rename_*, add_*, annotate_*, create_user_label, save_analysis_finding)
/// requires approval. The per-tool `requiresApproval` flag is authoritative
/// here — `PermissionPolicy.classify(toolName:)` is name-based and would
/// fail-safe-block read tools like `inspect_*`/`explain_*` whose names are
/// not in its read-only prefix list, so it is not applied to dispatch.
public struct DecompileAssistToolRegistry: Sendable {

    private var tools: [String: any DecompileAssistTool] = [:]

    public init() {
        registerAll()
    }

    public mutating func register(_ tool: any DecompileAssistTool) {
        tools[tool.id] = tool
    }

    private mutating func registerAll() {
        // Binary inspection
        register(InspectBinaryTool())
        register(GetBinaryMetadataTool())
        register(ListBinaryArchitecturesTool())
        register(InspectBinarySliceTool())
        register(InspectBinarySectionsTool())
        register(InspectBinarySegmentsTool())
        register(GetEntryPointTool())
        register(InspectCodeSignatureTool())
        register(InspectEntitlementsTool())
        register(InspectBinaryDependenciesTool())
        // Functions
        register(ListFunctionsTool())
        register(InspectFunctionTool())
        register(GetFunctionPseudocodeTool())
        register(GetFunctionAssemblyTool())
        register(GetFunctionSignatureTool())
        register(GetFunctionReferencesTool())
        register(GetFunctionCallersTool())
        register(GetFunctionCalleesTool())
        register(CompareFunctionsTool())
        register(InspectBasicBlockTool())
        // Symbols
        register(SearchSymbolsTool())
        register(InspectSymbolTool())
        register(DemangleSymbolTool())
        register(ListImportsTool())
        register(ListExportsTool())
        register(InspectImportTool())
        register(InspectExportTool())
        // Strings
        register(SearchStringsTool())
        register(InspectStringTool())
        register(InspectStringReferencesTool())
        register(GetStringContextTool())
        // Analysis
        register(GetControlFlowGraphTool())
        register(GetCallGraphTool())
        register(GetCrossReferencesTool())
        register(GetVariableInformationTool())
        register(GetTypeInformationTool())
        register(SearchBinaryTool())
        register(NavigateToAddressTool())
        register(InspectMemoryRegionTool())
        // Assistant analysis
        register(ExplainFunctionTool())
        register(ExplainInstructionTool())
        register(ExplainBinaryTool())
        register(SummarizeBinaryTool())
        register(SuggestFunctionNameTool())
        register(SuggestVariableNamesTool())
        register(IdentifyFunctionPurposeTool())
        register(CompareFunctionBehaviorTool())
        register(GenerateFunctionDocumentationTool())
        register(AnalyzeSuspiciousPatternsTool())
        // Annotations (approval-gated mutations)
        register(RenameSymbolTool())
        register(RenameFunctionTool())
        register(AddAnalysisCommentTool())
        register(AnnotateFunctionTool())
        register(CreateUserLabelTool())
        register(SaveAnalysisFindingTool())
    }

    public var all: [any DecompileAssistTool] {
        tools.values.sorted { $0.id < $1.id }
    }

    public var allIDs: [String] { all.map(\.id) }

    public func tool(named id: String) -> (any DecompileAssistTool)? {
        tools[id]
    }

    /// `tools` payload for `GoogleCloudSDKConfiguration.tools`: name,
    /// description, and JSON-schema parameters per tool.
    public func toolSchemas() -> [[String: Any]] {
        all.map { tool in
            [
                "name": tool.id,
                "description": tool.description,
                "parameters": tool.inputSchema,
            ]
        }
    }

    /// Execute a tool by name. Enforces approval policy and converts thrown
    /// errors into structured JSON error payloads.
    public func execute(name: String, arguments: [String: Any], session: DecompilerSession) async -> String {
        guard let tool = tools[name] else {
            return DecompileAssistToolSupport.error("unknown tool '\(name)'", code: "unknown_tool")
        }
        if tool.requiresApproval,
           !DecompileAssistToolSupport.bool(arguments, "approved") {
            return DecompileAssistToolSupport.approvalRequired(tool.id)
        }
        do {
            return try await tool.execute(arguments: arguments, session: session)
        } catch DecompileAssistToolSupport.ToolArgError.missing(let msg) {
            return DecompileAssistToolSupport.error(msg, code: "missing_argument")
        } catch {
            return DecompileAssistToolSupport.error(error.localizedDescription, code: "tool_error")
        }
    }
}
