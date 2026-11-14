import Foundation



public protocol DecompileAssistTool: Sendable {
    
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    
    var inputSchema: [String: Any] { get }
    
    var requiresApproval: Bool { get }
    func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String
}












public struct DecompileAssistToolRegistry: Sendable {

    private var tools: [String: any DecompileAssistTool] = [:]

    public init() {
        registerAll()
    }

    public mutating func register(_ tool: any DecompileAssistTool) {
        tools[tool.id] = tool
    }

    private mutating func registerAll() {
        
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
        
        register(SearchSymbolsTool())
        register(InspectSymbolTool())
        register(DemangleSymbolTool())
        register(ListImportsTool())
        register(ListExportsTool())
        register(InspectImportTool())
        register(InspectExportTool())
        
        register(SearchStringsTool())
        register(InspectStringTool())
        register(InspectStringReferencesTool())
        register(GetStringContextTool())
        
        register(GetControlFlowGraphTool())
        register(GetCallGraphTool())
        register(GetCrossReferencesTool())
        register(GetVariableInformationTool())
        register(GetTypeInformationTool())
        register(SearchBinaryTool())
        register(NavigateToAddressTool())
        register(InspectMemoryRegionTool())
        
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

    
    
    public func toolSchemas() -> [[String: Any]] {
        all.map { tool in
            [
                "name": tool.id,
                "description": tool.description,
                "parameters": tool.inputSchema,
            ]
        }
    }

    
    
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
