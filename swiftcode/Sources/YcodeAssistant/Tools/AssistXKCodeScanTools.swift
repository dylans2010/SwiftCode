// Expansion toolkit: CodeScan. Generated from specs; every tool operates on real workspace,
// process, or caller-provided data.
import Foundation


public struct XKScanPrintStatementsTool: AssistTool {
    public init() {}
    public var id: String { "scan_print_statements" }
    public var name: String { "Print Statement Scan" }
    public var description: String { "Scans the workspace (or `path`) for Print Statement occurrences and returns file:line findings with remediation guidance. Replace print() with Logger/os_log or remove before shipping." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Print Statement occurrences and returns file:line findings with remediation guidance. Replace print() with Logger/os_log or remove before shipping.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Print Statement Scan",
            guidance: "Replace print() with Logger/os_log or remove before shipping.",
            input: input, context: context,
            pattern: "\\bprint\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanDebugPrintDumpTool: AssistTool {
    public init() {}
    public var id: String { "scan_debug_print_dump" }
    public var name: String { "Debug Print/Dump Scan" }
    public var description: String { "Scans the workspace (or `path`) for Debug Print/Dump occurrences and returns file:line findings with remediation guidance. Remove debugPrint()/dump() from production paths." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Debug Print/Dump occurrences and returns file:line findings with remediation guidance. Remove debugPrint()/dump() from production paths.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Debug Print/Dump Scan",
            guidance: "Remove debugPrint()/dump() from production paths.",
            input: input, context: context,
            pattern: "\\bdebugPrint\\(|\\bdump\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanNslogUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_nslog_usage" }
    public var name: String { "NSLog Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for NSLog Usage occurrences and returns file:line findings with remediation guidance. Prefer unified logging (Logger) with privacy annotations." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for NSLog Usage occurrences and returns file:line findings with remediation guidance. Prefer unified logging (Logger) with privacy annotations.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "NSLog Usage Scan",
            guidance: "Prefer unified logging (Logger) with privacy annotations.",
            input: input, context: context,
            pattern: "\\bNSLog\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanFatalErrorCallsTool: AssistTool {
    public init() {}
    public var id: String { "scan_fatal_error_calls" }
    public var name: String { "fatalError Scan" }
    public var description: String { "Scans the workspace (or `path`) for fatalError occurrences and returns file:line findings with remediation guidance. Each fatalError crashes the app; replace with thrown errors where recovery is possible." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for fatalError occurrences and returns file:line findings with remediation guidance. Each fatalError crashes the app; replace with thrown errors where recovery is possible.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "fatalError Scan",
            guidance: "Each fatalError crashes the app; replace with thrown errors where recovery is possible.",
            input: input, context: context,
            pattern: "\\bfatalError\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanPreconditionCallsTool: AssistTool {
    public init() {}
    public var id: String { "scan_precondition_calls" }
    public var name: String { "Precondition Scan" }
    public var description: String { "Scans the workspace (or `path`) for Precondition occurrences and returns file:line findings with remediation guidance. Preconditions trap in release builds; confirm each is a true invariant." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Precondition occurrences and returns file:line findings with remediation guidance. Preconditions trap in release builds; confirm each is a true invariant.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Precondition Scan",
            guidance: "Preconditions trap in release builds; confirm each is a true invariant.",
            input: input, context: context,
            pattern: "\\bprecondition(Failure)?\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanAssertCallsTool: AssistTool {
    public init() {}
    public var id: String { "scan_assert_calls" }
    public var name: String { "Assertion Scan" }
    public var description: String { "Scans the workspace (or `path`) for Assertion occurrences and returns file:line findings with remediation guidance. Assertions are stripped in release builds; do not rely on them for validation." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Assertion occurrences and returns file:line findings with remediation guidance. Assertions are stripped in release builds; do not rely on them for validation.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Assertion Scan",
            guidance: "Assertions are stripped in release builds; do not rely on them for validation.",
            input: input, context: context,
            pattern: "\\bassert(ionFailure)?\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanForceTryTool: AssistTool {
    public init() {}
    public var id: String { "scan_force_try" }
    public var name: String { "Force-Try Scan" }
    public var description: String { "Scans the workspace (or `path`) for Force-Try occurrences and returns file:line findings with remediation guidance. Replace try! with do/catch or try? plus explicit handling." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Force-Try occurrences and returns file:line findings with remediation guidance. Replace try! with do/catch or try? plus explicit handling.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Force-Try Scan",
            guidance: "Replace try! with do/catch or try? plus explicit handling.",
            input: input, context: context,
            pattern: "\\btry!",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanForceCastTool: AssistTool {
    public init() {}
    public var id: String { "scan_force_cast" }
    public var name: String { "Force-Cast Scan" }
    public var description: String { "Scans the workspace (or `path`) for Force-Cast occurrences and returns file:line findings with remediation guidance. Replace as! with conditional casting (as?) and handle failure." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Force-Cast occurrences and returns file:line findings with remediation guidance. Replace as! with conditional casting (as?) and handle failure.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Force-Cast Scan",
            guidance: "Replace as! with conditional casting (as?) and handle failure.",
            input: input, context: context,
            pattern: "\\bas!\\s",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanForceUnwrapTool: AssistTool {
    public init() {}
    public var id: String { "scan_force_unwrap" }
    public var name: String { "Force-Unwrap Scan" }
    public var description: String { "Scans the workspace (or `path`) for Force-Unwrap occurrences and returns file:line findings with remediation guidance. Replace force unwraps with guard let / if let / nil-coalescing." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Force-Unwrap occurrences and returns file:line findings with remediation guidance. Replace force unwraps with guard let / if let / nil-coalescing.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Force-Unwrap Scan",
            guidance: "Replace force unwraps with guard let / if let / nil-coalescing.",
            input: input, context: context,
            pattern: "[\\w\\)\\]]!(?=[.\\s),\\]]|$)",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanImplicitlyUnwrappedOptionalsTool: AssistTool {
    public init() {}
    public var id: String { "scan_implicitly_unwrapped_optionals" }
    public var name: String { "Implicitly Unwrapped Optional Scan" }
    public var description: String { "Scans the workspace (or `path`) for Implicitly Unwrapped Optional occurrences and returns file:line findings with remediation guidance. Prefer real optionals or non-optional initialization over IUOs." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Implicitly Unwrapped Optional occurrences and returns file:line findings with remediation guidance. Prefer real optionals or non-optional initialization over IUOs.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Implicitly Unwrapped Optional Scan",
            guidance: "Prefer real optionals or non-optional initialization over IUOs.",
            input: input, context: context,
            pattern: ":\\s*[\\w.<>\\[\\]]+!(\\s|=|$)",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanUnownedReferencesTool: AssistTool {
    public init() {}
    public var id: String { "scan_unowned_references" }
    public var name: String { "Unowned Reference Scan" }
    public var description: String { "Scans the workspace (or `path`) for Unowned Reference occurrences and returns file:line findings with remediation guidance. Unowned references crash if the referent is deallocated; verify lifetimes or use weak." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Unowned Reference occurrences and returns file:line findings with remediation guidance. Unowned references crash if the referent is deallocated; verify lifetimes or use weak.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Unowned Reference Scan",
            guidance: "Unowned references crash if the referent is deallocated; verify lifetimes or use weak.",
            input: input, context: context,
            pattern: "\\bunowned\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanClosureSelfCaptureTool: AssistTool {
    public init() {}
    public var id: String { "scan_closure_self_capture" }
    public var name: String { "Closure Strong-Self Capture Scan" }
    public var description: String { "Scans the workspace (or `path`) for Closure Strong-Self Capture occurrences and returns file:line findings with remediation guidance. Escaping closures that capture self strongly may create retain cycles; consider [weak self]." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Closure Strong-Self Capture occurrences and returns file:line findings with remediation guidance. Escaping closures that capture self strongly may create retain cycles; consider [weak self].", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Closure Strong-Self Capture Scan",
            guidance: "Escaping closures that capture self strongly may create retain cycles; consider [weak self].",
            input: input, context: context,
            pattern: "\\{\\s*(?!\\[weak|\\[unowned)[^}]*\\bin\\b[^}]*\\bself\\.",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanDispatchMainQueueTool: AssistTool {
    public init() {}
    public var id: String { "scan_dispatch_main_queue" }
    public var name: String { "DispatchQueue.main Scan" }
    public var description: String { "Scans the workspace (or `path`) for DispatchQueue.main occurrences and returns file:line findings with remediation guidance. In Swift concurrency code prefer @MainActor / MainActor.run over DispatchQueue.main." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for DispatchQueue.main occurrences and returns file:line findings with remediation guidance. In Swift concurrency code prefer @MainActor / MainActor.run over DispatchQueue.main.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "DispatchQueue.main Scan",
            guidance: "In Swift concurrency code prefer @MainActor / MainActor.run over DispatchQueue.main.",
            input: input, context: context,
            pattern: "DispatchQueue\\.main\\.(async|sync)",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanDispatchGlobalQueueTool: AssistTool {
    public init() {}
    public var id: String { "scan_dispatch_global_queue" }
    public var name: String { "Global Dispatch Queue Scan" }
    public var description: String { "Scans the workspace (or `path`) for Global Dispatch Queue occurrences and returns file:line findings with remediation guidance. Consider structured concurrency (Task / async let) instead of global queues." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Global Dispatch Queue occurrences and returns file:line findings with remediation guidance. Consider structured concurrency (Task / async let) instead of global queues.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Global Dispatch Queue Scan",
            guidance: "Consider structured concurrency (Task / async let) instead of global queues.",
            input: input, context: context,
            pattern: "DispatchQueue\\.global\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanDispatchSemaphoresTool: AssistTool {
    public init() {}
    public var id: String { "scan_dispatch_semaphores" }
    public var name: String { "DispatchSemaphore Scan" }
    public var description: String { "Scans the workspace (or `path`) for DispatchSemaphore occurrences and returns file:line findings with remediation guidance. Semaphores that block threads can deadlock with Swift concurrency; prefer async APIs." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for DispatchSemaphore occurrences and returns file:line findings with remediation guidance. Semaphores that block threads can deadlock with Swift concurrency; prefer async APIs.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "DispatchSemaphore Scan",
            guidance: "Semaphores that block threads can deadlock with Swift concurrency; prefer async APIs.",
            input: input, context: context,
            pattern: "DispatchSemaphore\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanTaskDetachedTool: AssistTool {
    public init() {}
    public var id: String { "scan_task_detached" }
    public var name: String { "Task.detached Scan" }
    public var description: String { "Scans the workspace (or `path`) for Task.detached occurrences and returns file:line findings with remediation guidance. Detached tasks lose priority, task-locals and cancellation; prefer Task {} or structured concurrency." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Task.detached occurrences and returns file:line findings with remediation guidance. Detached tasks lose priority, task-locals and cancellation; prefer Task {} or structured concurrency.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Task.detached Scan",
            guidance: "Detached tasks lose priority, task-locals and cancellation; prefer Task {} or structured concurrency.",
            input: input, context: context,
            pattern: "Task\\.detached",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanUncheckedSendableTool: AssistTool {
    public init() {}
    public var id: String { "scan_unchecked_sendable" }
    public var name: String { "@unchecked Sendable Scan" }
    public var description: String { "Scans the workspace (or `path`) for @unchecked Sendable occurrences and returns file:line findings with remediation guidance. Each @unchecked Sendable must be backed by real synchronization; audit them." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for @unchecked Sendable occurrences and returns file:line findings with remediation guidance. Each @unchecked Sendable must be backed by real synchronization; audit them.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "@unchecked Sendable Scan",
            guidance: "Each @unchecked Sendable must be backed by real synchronization; audit them.",
            input: input, context: context,
            pattern: "@unchecked\\s+Sendable",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanNonisolatedUnsafeTool: AssistTool {
    public init() {}
    public var id: String { "scan_nonisolated_unsafe" }
    public var name: String { "nonisolated(unsafe) Scan" }
    public var description: String { "Scans the workspace (or `path`) for nonisolated(unsafe) occurrences and returns file:line findings with remediation guidance. nonisolated(unsafe) disables data-race checking; ensure external synchronization." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for nonisolated(unsafe) occurrences and returns file:line findings with remediation guidance. nonisolated(unsafe) disables data-race checking; ensure external synchronization.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "nonisolated(unsafe) Scan",
            guidance: "nonisolated(unsafe) disables data-race checking; ensure external synchronization.",
            input: input, context: context,
            pattern: "nonisolated\\(unsafe\\)",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanMainActorAnnotationsTool: AssistTool {
    public init() {}
    public var id: String { "scan_main_actor_annotations" }
    public var name: String { "@MainActor Annotation Scan" }
    public var description: String { "Scans the workspace (or `path`) for @MainActor Annotation occurrences and returns file:line findings with remediation guidance. Review @MainActor usage to keep UI state isolated and heavy work off the main actor." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for @MainActor Annotation occurrences and returns file:line findings with remediation guidance. Review @MainActor usage to keep UI state isolated and heavy work off the main actor.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "@MainActor Annotation Scan",
            guidance: "Review @MainActor usage to keep UI state isolated and heavy work off the main actor.",
            input: input, context: context,
            pattern: "@MainActor",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanThreadSleepTool: AssistTool {
    public init() {}
    public var id: String { "scan_thread_sleep" }
    public var name: String { "Thread Sleep Scan" }
    public var description: String { "Scans the workspace (or `path`) for Thread Sleep occurrences and returns file:line findings with remediation guidance. Blocking sleeps stall threads; use Task.sleep(for:) in async code." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Thread Sleep occurrences and returns file:line findings with remediation guidance. Blocking sleeps stall threads; use Task.sleep(for:) in async code.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Thread Sleep Scan",
            guidance: "Blocking sleeps stall threads; use Task.sleep(for:) in async code.",
            input: input, context: context,
            pattern: "Thread\\.sleep|\\busleep\\(|\\bsleep\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanNotificationCenterTool: AssistTool {
    public init() {}
    public var id: String { "scan_notification_center" }
    public var name: String { "NotificationCenter Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for NotificationCenter Usage occurrences and returns file:line findings with remediation guidance. Check observers are removed or use async notification sequences." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for NotificationCenter Usage occurrences and returns file:line findings with remediation guidance. Check observers are removed or use async notification sequences.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "NotificationCenter Usage Scan",
            guidance: "Check observers are removed or use async notification sequences.",
            input: input, context: context,
            pattern: "NotificationCenter\\.default",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanUserdefaultsUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_userdefaults_usage" }
    public var name: String { "UserDefaults Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for UserDefaults Usage occurrences and returns file:line findings with remediation guidance. Centralize keys; never store secrets in UserDefaults (use Keychain)." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for UserDefaults Usage occurrences and returns file:line findings with remediation guidance. Centralize keys; never store secrets in UserDefaults (use Keychain).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "UserDefaults Usage Scan",
            guidance: "Centralize keys; never store secrets in UserDefaults (use Keychain).",
            input: input, context: context,
            pattern: "UserDefaults\\.standard|@AppStorage\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanHardcodedUrlsTool: AssistTool {
    public init() {}
    public var id: String { "scan_hardcoded_urls" }
    public var name: String { "Hardcoded URL Scan" }
    public var description: String { "Scans the workspace (or `path`) for Hardcoded URL occurrences and returns file:line findings with remediation guidance. Move environment-specific URLs into configuration." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Hardcoded URL occurrences and returns file:line findings with remediation guidance. Move environment-specific URLs into configuration.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Hardcoded URL Scan",
            guidance: "Move environment-specific URLs into configuration.",
            input: input, context: context,
            pattern: "https?://[^\\s\\\"']+",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanInsecureHttpUrlsTool: AssistTool {
    public init() {}
    public var id: String { "scan_insecure_http_urls" }
    public var name: String { "Insecure HTTP URL Scan" }
    public var description: String { "Scans the workspace (or `path`) for Insecure HTTP URL occurrences and returns file:line findings with remediation guidance. Plain HTTP is blocked by ATS and insecure; use HTTPS." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Insecure HTTP URL occurrences and returns file:line findings with remediation guidance. Plain HTTP is blocked by ATS and insecure; use HTTPS.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Insecure HTTP URL Scan",
            guidance: "Plain HTTP is blocked by ATS and insecure; use HTTPS.",
            input: input, context: context,
            pattern: "\\\"http://(?!localhost|127\\.0\\.0\\.1)",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanHardcodedSecretsTool: AssistTool {
    public init() {}
    public var id: String { "scan_hardcoded_secrets" }
    public var name: String { "Hardcoded Secret Scan" }
    public var description: String { "Scans the workspace (or `path`) for Hardcoded Secret occurrences and returns file:line findings with remediation guidance. Move secrets to Keychain or server-side configuration and rotate exposed values." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Hardcoded Secret occurrences and returns file:line findings with remediation guidance. Move secrets to Keychain or server-side configuration and rotate exposed values.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Hardcoded Secret Scan",
            guidance: "Move secrets to Keychain or server-side configuration and rotate exposed values.",
            input: input, context: context,
            pattern: "(api[_-]?key|secret|token|password|passwd)\\s*[:=]\\s*\\\"[^\\\"]{8,}\\\"",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: true
        )
    }
}


public struct XKScanPrivateKeyMaterialTool: AssistTool {
    public init() {}
    public var id: String { "scan_private_key_material" }
    public var name: String { "Private Key Material Scan" }
    public var description: String { "Scans the workspace (or `path`) for Private Key Material occurrences and returns file:line findings with remediation guidance. Remove private keys from the repository and rotate them." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Private Key Material occurrences and returns file:line findings with remediation guidance. Remove private keys from the repository and rotate them.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? nil : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Private Key Material Scan",
            guidance: "Remove private keys from the repository and rotate them.",
            input: input, context: context,
            pattern: "-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----",
            extensions: extensions,
            skipComments: false,
            caseInsensitive: false
        )
    }
}


public struct XKScanWeakCryptoTool: AssistTool {
    public init() {}
    public var id: String { "scan_weak_crypto" }
    public var name: String { "Weak Cryptography Scan" }
    public var description: String { "Scans the workspace (or `path`) for Weak Cryptography occurrences and returns file:line findings with remediation guidance. Use SHA-256+ and AES-GCM / ChaChaPoly from CryptoKit." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Weak Cryptography occurrences and returns file:line findings with remediation guidance. Use SHA-256+ and AES-GCM / ChaChaPoly from CryptoKit.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Weak Cryptography Scan",
            guidance: "Use SHA-256+ and AES-GCM / ChaChaPoly from CryptoKit.",
            input: input, context: context,
            pattern: "Insecure\\.(MD5|SHA1)|CC_MD5|CC_SHA1|kCCAlgorithmDES|kCCAlgorithm3DES",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanInsecureRandomTool: AssistTool {
    public init() {}
    public var id: String { "scan_insecure_random" }
    public var name: String { "Insecure Randomness Scan" }
    public var description: String { "Scans the workspace (or `path`) for Insecure Randomness occurrences and returns file:line findings with remediation guidance. Use SystemRandomNumberGenerator or SecRandomCopyBytes for security-sensitive randomness." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Insecure Randomness occurrences and returns file:line findings with remediation guidance. Use SystemRandomNumberGenerator or SecRandomCopyBytes for security-sensitive randomness.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Insecure Randomness Scan",
            guidance: "Use SystemRandomNumberGenerator or SecRandomCopyBytes for security-sensitive randomness.",
            input: input, context: context,
            pattern: "\\barc4random\\b|\\bdrand48\\(|\\brand\\(\\)|\\brandom\\(\\)",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanUnsafePointersTool: AssistTool {
    public init() {}
    public var id: String { "scan_unsafe_pointers" }
    public var name: String { "Unsafe Pointer Scan" }
    public var description: String { "Scans the workspace (or `path`) for Unsafe Pointer occurrences and returns file:line findings with remediation guidance. Unsafe pointers bypass memory safety; keep them tightly scoped." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Unsafe Pointer occurrences and returns file:line findings with remediation guidance. Unsafe pointers bypass memory safety; keep them tightly scoped.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Unsafe Pointer Scan",
            guidance: "Unsafe pointers bypass memory safety; keep them tightly scoped.",
            input: input, context: context,
            pattern: "Unsafe(Mutable)?(Raw)?(Buffer)?Pointer",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanObjcAttributesTool: AssistTool {
    public init() {}
    public var id: String { "scan_objc_attributes" }
    public var name: String { "@objc Attribute Scan" }
    public var description: String { "Scans the workspace (or `path`) for @objc Attribute occurrences and returns file:line findings with remediation guidance. Audit @objc exposure; remove where Objective-C interop is not needed." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for @objc Attribute occurrences and returns file:line findings with remediation guidance. Audit @objc exposure; remove where Objective-C interop is not needed.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "@objc Attribute Scan",
            guidance: "Audit @objc exposure; remove where Objective-C interop is not needed.",
            input: input, context: context,
            pattern: "@objc\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanDynamicAttributesTool: AssistTool {
    public init() {}
    public var id: String { "scan_dynamic_attributes" }
    public var name: String { "Dynamic Lookup Attribute Scan" }
    public var description: String { "Scans the workspace (or `path`) for Dynamic Lookup Attribute occurrences and returns file:line findings with remediation guidance. Dynamic dispatch hides type errors; confirm usage is intentional." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Dynamic Lookup Attribute occurrences and returns file:line findings with remediation guidance. Dynamic dispatch hides type errors; confirm usage is intentional.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Dynamic Lookup Attribute Scan",
            guidance: "Dynamic dispatch hides type errors; confirm usage is intentional.",
            input: input, context: context,
            pattern: "@dynamicMemberLookup|@dynamicCallable|\\bdynamic\\s+var",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanSingletonsTool: AssistTool {
    public init() {}
    public var id: String { "scan_singletons" }
    public var name: String { "Singleton Scan" }
    public var description: String { "Scans the workspace (or `path`) for Singleton occurrences and returns file:line findings with remediation guidance. Singletons hinder testing; consider dependency injection." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Singleton occurrences and returns file:line findings with remediation guidance. Singletons hinder testing; consider dependency injection.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Singleton Scan",
            guidance: "Singletons hinder testing; consider dependency injection.",
            input: input, context: context,
            pattern: "static\\s+(let|var)\\s+shared\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanGlobalMutableStateTool: AssistTool {
    public init() {}
    public var id: String { "scan_global_mutable_state" }
    public var name: String { "Global Mutable State Scan" }
    public var description: String { "Scans the workspace (or `path`) for Global Mutable State occurrences and returns file:line findings with remediation guidance. Top-level mutable globals are not concurrency-safe; isolate them." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Global Mutable State occurrences and returns file:line findings with remediation guidance. Top-level mutable globals are not concurrency-safe; isolate them.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Global Mutable State Scan",
            guidance: "Top-level mutable globals are not concurrency-safe; isolate them.",
            input: input, context: context,
            pattern: "^(public\\s+|private\\s+|fileprivate\\s+)?var\\s+\\w+",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanTimerUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_timer_usage" }
    public var name: String { "Timer Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for Timer Usage occurrences and returns file:line findings with remediation guidance. Invalidate timers and avoid retain cycles; consider AsyncTimerSequence/Task.sleep loops." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Timer Usage occurrences and returns file:line findings with remediation guidance. Invalidate timers and avoid retain cycles; consider AsyncTimerSequence/Task.sleep loops.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Timer Usage Scan",
            guidance: "Invalidate timers and avoid retain cycles; consider AsyncTimerSequence/Task.sleep loops.",
            input: input, context: context,
            pattern: "Timer\\.(scheduledTimer|publish)|Timer\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanAnyTypeUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_any_type_usage" }
    public var name: String { "Any Type Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for Any Type Usage occurrences and returns file:line findings with remediation guidance. Replace Any with concrete types or Codable models where feasible." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Any Type Usage occurrences and returns file:line findings with remediation guidance. Replace Any with concrete types or Codable models where feasible.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Any Type Usage Scan",
            guidance: "Replace Any with concrete types or Codable models where feasible.",
            input: input, context: context,
            pattern: ":\\s*Any\\b|\\[Any\\]|\\[String:\\s*Any\\]",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanAnyobjectUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_anyobject_usage" }
    public var name: String { "AnyObject Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for AnyObject Usage occurrences and returns file:line findings with remediation guidance. Ensure AnyObject constraints are required (e.g. weak delegates)." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for AnyObject Usage occurrences and returns file:line findings with remediation guidance. Ensure AnyObject constraints are required (e.g. weak delegates).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "AnyObject Usage Scan",
            guidance: "Ensure AnyObject constraints are required (e.g. weak delegates).",
            input: input, context: context,
            pattern: "\\bAnyObject\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanLongLinesTool: AssistTool {
    public init() {}
    public var id: String { "scan_long_lines" }
    public var name: String { "Long Line Scan" }
    public var description: String { "Scans the workspace (or `path`) for Long Line occurrences and returns file:line findings with remediation guidance. Wrap lines longer than 120 characters for readability." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Long Line occurrences and returns file:line findings with remediation guidance. Wrap lines longer than 120 characters for readability.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Long Line Scan",
            guidance: "Wrap lines longer than 120 characters for readability.",
            input: input, context: context,
            pattern: "^.{121,}$",
            extensions: extensions,
            skipComments: false,
            caseInsensitive: false
        )
    }
}


public struct XKScanTrailingWhitespaceTool: AssistTool {
    public init() {}
    public var id: String { "scan_trailing_whitespace" }
    public var name: String { "Trailing Whitespace Scan" }
    public var description: String { "Scans the workspace (or `path`) for Trailing Whitespace occurrences and returns file:line findings with remediation guidance. Strip trailing whitespace (file_strip_trailing_whitespace)." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Trailing Whitespace occurrences and returns file:line findings with remediation guidance. Strip trailing whitespace (file_strip_trailing_whitespace).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Trailing Whitespace Scan",
            guidance: "Strip trailing whitespace (file_strip_trailing_whitespace).",
            input: input, context: context,
            pattern: "[ \\t]+$",
            extensions: extensions,
            skipComments: false,
            caseInsensitive: false
        )
    }
}


public struct XKScanTabIndentationTool: AssistTool {
    public init() {}
    public var id: String { "scan_tab_indentation" }
    public var name: String { "Tab Indentation Scan" }
    public var description: String { "Scans the workspace (or `path`) for Tab Indentation occurrences and returns file:line findings with remediation guidance. Convert tabs to spaces for consistency (file_tabs_to_spaces)." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Tab Indentation occurrences and returns file:line findings with remediation guidance. Convert tabs to spaces for consistency (file_tabs_to_spaces).", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Tab Indentation Scan",
            guidance: "Convert tabs to spaces for consistency (file_tabs_to_spaces).",
            input: input, context: context,
            pattern: "^\\t+",
            extensions: extensions,
            skipComments: false,
            caseInsensitive: false
        )
    }
}


public struct XKScanTodoFixmeMarkersTool: AssistTool {
    public init() {}
    public var id: String { "scan_todo_fixme_markers" }
    public var name: String { "TODO/FIXME Marker Scan" }
    public var description: String { "Scans the workspace (or `path`) for TODO/FIXME Marker occurrences and returns file:line findings with remediation guidance. Resolve or ticket each marker before release." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for TODO/FIXME Marker occurrences and returns file:line findings with remediation guidance. Resolve or ticket each marker before release.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "TODO/FIXME Marker Scan",
            guidance: "Resolve or ticket each marker before release.",
            input: input, context: context,
            pattern: "\\b(TODO|FIXME|HACK|XXX)\\b",
            extensions: extensions,
            skipComments: false,
            caseInsensitive: false
        )
    }
}


public struct XKScanSwiftlintDisablesTool: AssistTool {
    public init() {}
    public var id: String { "scan_swiftlint_disables" }
    public var name: String { "SwiftLint Disable Scan" }
    public var description: String { "Scans the workspace (or `path`) for SwiftLint Disable occurrences and returns file:line findings with remediation guidance. Each lint suppression should be justified; remove stale ones." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for SwiftLint Disable occurrences and returns file:line findings with remediation guidance. Each lint suppression should be justified; remove stale ones.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "SwiftLint Disable Scan",
            guidance: "Each lint suppression should be justified; remove stale ones.",
            input: input, context: context,
            pattern: "swiftlint:disable",
            extensions: extensions,
            skipComments: false,
            caseInsensitive: false
        )
    }
}


public struct XKScanDeprecatedDeclarationsTool: AssistTool {
    public init() {}
    public var id: String { "scan_deprecated_declarations" }
    public var name: String { "Deprecated Declaration Scan" }
    public var description: String { "Scans the workspace (or `path`) for Deprecated Declaration occurrences and returns file:line findings with remediation guidance. Migrate callers away from deprecated declarations." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Deprecated Declaration occurrences and returns file:line findings with remediation guidance. Migrate callers away from deprecated declarations.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Deprecated Declaration Scan",
            guidance: "Migrate callers away from deprecated declarations.",
            input: input, context: context,
            pattern: "@available\\([^)]*deprecated",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanAvailabilityChecksTool: AssistTool {
    public init() {}
    public var id: String { "scan_availability_checks" }
    public var name: String { "Availability Check Scan" }
    public var description: String { "Scans the workspace (or `path`) for Availability Check occurrences and returns file:line findings with remediation guidance. Remove availability checks below the deployment target." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Availability Check occurrences and returns file:line findings with remediation guidance. Remove availability checks below the deployment target.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Availability Check Scan",
            guidance: "Remove availability checks below the deployment target.",
            input: input, context: context,
            pattern: "#available\\(|#unavailable\\(|@available\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanCompilerDirectivesTool: AssistTool {
    public init() {}
    public var id: String { "scan_compiler_directives" }
    public var name: String { "Compiler Directive Scan" }
    public var description: String { "Scans the workspace (or `path`) for Compiler Directive occurrences and returns file:line findings with remediation guidance. Review conditional compilation for dead branches." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Compiler Directive occurrences and returns file:line findings with remediation guidance. Review conditional compilation for dead branches.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Compiler Directive Scan",
            guidance: "Review conditional compilation for dead branches.",
            input: input, context: context,
            pattern: "^\\s*#(if|elseif|else|endif)\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanEmptyCatchBlocksTool: AssistTool {
    public init() {}
    public var id: String { "scan_empty_catch_blocks" }
    public var name: String { "Empty Catch Block Scan" }
    public var description: String { "Scans the workspace (or `path`) for Empty Catch Block occurrences and returns file:line findings with remediation guidance. Never swallow errors silently; log or propagate them." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Empty Catch Block occurrences and returns file:line findings with remediation guidance. Never swallow errors silently; log or propagate them.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Empty Catch Block Scan",
            guidance: "Never swallow errors silently; log or propagate them.",
            input: input, context: context,
            pattern: "catch\\s*(let\\s+\\w+)?\\s*\\{\\s*\\}",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanTryOptionalTool: AssistTool {
    public init() {}
    public var id: String { "scan_try_optional" }
    public var name: String { "try? Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for try? Usage occurrences and returns file:line findings with remediation guidance. try? discards error information; confirm failure is truly ignorable." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for try? Usage occurrences and returns file:line findings with remediation guidance. try? discards error information; confirm failure is truly ignorable.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "try? Usage Scan",
            guidance: "try? discards error information; confirm failure is truly ignorable.",
            input: input, context: context,
            pattern: "\\btry\\?",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanEmptyFunctionsTool: AssistTool {
    public init() {}
    public var id: String { "scan_empty_functions" }
    public var name: String { "Empty Function Scan" }
    public var description: String { "Scans the workspace (or `path`) for Empty Function occurrences and returns file:line findings with remediation guidance. Empty functions may be unfinished; implement or document why they are empty." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Empty Function occurrences and returns file:line findings with remediation guidance. Empty functions may be unfinished; implement or document why they are empty.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Empty Function Scan",
            guidance: "Empty functions may be unfinished; implement or document why they are empty.",
            input: input, context: context,
            pattern: "func\\s+\\w+[^{]*\\{\\s*\\}",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanMagicNumbersTool: AssistTool {
    public init() {}
    public var id: String { "scan_magic_numbers" }
    public var name: String { "Magic Number Scan" }
    public var description: String { "Scans the workspace (or `path`) for Magic Number occurrences and returns file:line findings with remediation guidance. Extract repeated numeric literals into named constants." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Magic Number occurrences and returns file:line findings with remediation guidance. Extract repeated numeric literals into named constants.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Magic Number Scan",
            guidance: "Extract repeated numeric literals into named constants.",
            input: input, context: context,
            pattern: "[=(,:]\\s*-?\\d{3,}(\\.\\d+)?\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanSqlStringInterpolationTool: AssistTool {
    public init() {}
    public var id: String { "scan_sql_string_interpolation" }
    public var name: String { "SQL String Interpolation Scan" }
    public var description: String { "Scans the workspace (or `path`) for SQL String Interpolation occurrences and returns file:line findings with remediation guidance. Use bound parameters instead of interpolating values into SQL." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for SQL String Interpolation occurrences and returns file:line findings with remediation guidance. Use bound parameters instead of interpolating values into SQL.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "SQL String Interpolation Scan",
            guidance: "Use bound parameters instead of interpolating values into SQL.",
            input: input, context: context,
            pattern: "\\\"\\s*(select|insert|update|delete)\\b[^\\\"]*\\\\\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: true
        )
    }
}


public struct XKScanWebviewUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_webview_usage" }
    public var name: String { "Web View Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for Web View Usage occurrences and returns file:line findings with remediation guidance. Audit web content loading, JavaScript bridges and navigation policies." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Web View Usage occurrences and returns file:line findings with remediation guidance. Audit web content loading, JavaScript bridges and navigation policies.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Web View Usage Scan",
            guidance: "Audit web content loading, JavaScript bridges and navigation policies.",
            input: input, context: context,
            pattern: "WKWebView|UIWebView|SFSafariViewController|ASWebAuthenticationSession",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanKeychainUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_keychain_usage" }
    public var name: String { "Keychain API Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for Keychain API Usage occurrences and returns file:line findings with remediation guidance. Check accessibility classes (kSecAttrAccessible...) and error handling." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Keychain API Usage occurrences and returns file:line findings with remediation guidance. Check accessibility classes (kSecAttrAccessible...) and error handling.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Keychain API Usage Scan",
            guidance: "Check accessibility classes (kSecAttrAccessible...) and error handling.",
            input: input, context: context,
            pattern: "SecItem(Add|CopyMatching|Update|Delete)|kSecClass",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanFileProtectionTool: AssistTool {
    public init() {}
    public var id: String { "scan_file_protection" }
    public var name: String { "File Protection Scan" }
    public var description: String { "Scans the workspace (or `path`) for File Protection occurrences and returns file:line findings with remediation guidance. Sensitive files should use complete file protection." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for File Protection occurrences and returns file:line findings with remediation guidance. Sensitive files should use complete file protection.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "File Protection Scan",
            guidance: "Sensitive files should use complete file protection.",
            input: input, context: context,
            pattern: "FileProtectionType|\\.completeFileProtection|NSFileProtection",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanCombineSinksTool: AssistTool {
    public init() {}
    public var id: String { "scan_combine_sinks" }
    public var name: String { "Combine Sink Scan" }
    public var description: String { "Scans the workspace (or `path`) for Combine Sink occurrences and returns file:line findings with remediation guidance. Store cancellables and capture self weakly inside sinks." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Combine Sink occurrences and returns file:line findings with remediation guidance. Store cancellables and capture self weakly inside sinks.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Combine Sink Scan",
            guidance: "Store cancellables and capture self weakly inside sinks.",
            input: input, context: context,
            pattern: "\\.sink\\s*[({]",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanObservableStateTool: AssistTool {
    public init() {}
    public var id: String { "scan_observable_state" }
    public var name: String { "Observable State Scan" }
    public var description: String { "Scans the workspace (or `path`) for Observable State occurrences and returns file:line findings with remediation guidance. Prefer the Observation framework (@Observable) on modern deployment targets." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Observable State occurrences and returns file:line findings with remediation guidance. Prefer the Observation framework (@Observable) on modern deployment targets.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Observable State Scan",
            guidance: "Prefer the Observation framework (@Observable) on modern deployment targets.",
            input: input, context: context,
            pattern: "ObservableObject|@Published|@Observable\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanSwiftuiPropertyWrappersTool: AssistTool {
    public init() {}
    public var id: String { "scan_swiftui_property_wrappers" }
    public var name: String { "SwiftUI Property Wrapper Scan" }
    public var description: String { "Scans the workspace (or `path`) for SwiftUI Property Wrapper occurrences and returns file:line findings with remediation guidance. Verify ownership: @State/@StateObject own, @Binding/@ObservedObject borrow." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for SwiftUI Property Wrapper occurrences and returns file:line findings with remediation guidance. Verify ownership: @State/@StateObject own, @Binding/@ObservedObject borrow.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "SwiftUI Property Wrapper Scan",
            guidance: "Verify ownership: @State/@StateObject own, @Binding/@ObservedObject borrow.",
            input: input, context: context,
            pattern: "@(State|StateObject|ObservedObject|EnvironmentObject|Binding|Environment|Bindable|FocusState)\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanAnyviewUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_anyview_usage" }
    public var name: String { "AnyView Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for AnyView Usage occurrences and returns file:line findings with remediation guidance. AnyView erases identity and hurts diffing; prefer @ViewBuilder or generics." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for AnyView Usage occurrences and returns file:line findings with remediation guidance. AnyView erases identity and hurts diffing; prefer @ViewBuilder or generics.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "AnyView Usage Scan",
            guidance: "AnyView erases identity and hurts diffing; prefer @ViewBuilder or generics.",
            input: input, context: context,
            pattern: "\\bAnyView\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanGeometryReaderTool: AssistTool {
    public init() {}
    public var id: String { "scan_geometry_reader" }
    public var name: String { "GeometryReader Scan" }
    public var description: String { "Scans the workspace (or `path`) for GeometryReader occurrences and returns file:line findings with remediation guidance. GeometryReader is greedy; prefer containerRelativeFrame/onGeometryChange where possible." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for GeometryReader occurrences and returns file:line findings with remediation guidance. GeometryReader is greedy; prefer containerRelativeFrame/onGeometryChange where possible.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "GeometryReader Scan",
            guidance: "GeometryReader is greedy; prefer containerRelativeFrame/onGeometryChange where possible.",
            input: input, context: context,
            pattern: "GeometryReader",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanViewLifecycleTasksTool: AssistTool {
    public init() {}
    public var id: String { "scan_view_lifecycle_tasks" }
    public var name: String { "View Lifecycle Task Scan" }
    public var description: String { "Scans the workspace (or `path`) for View Lifecycle Task occurrences and returns file:line findings with remediation guidance. Prefer .task for async work so it is cancelled automatically." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for View Lifecycle Task occurrences and returns file:line findings with remediation guidance. Prefer .task for async work so it is cancelled automatically.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "View Lifecycle Task Scan",
            guidance: "Prefer .task for async work so it is cancelled automatically.",
            input: input, context: context,
            pattern: "\\.onAppear\\s*\\{|\\.task\\s*(\\(|\\{)|\\.onDisappear",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanNavigationViewDeprecatedTool: AssistTool {
    public init() {}
    public var id: String { "scan_navigation_view_deprecated" }
    public var name: String { "NavigationView Scan" }
    public var description: String { "Scans the workspace (or `path`) for NavigationView occurrences and returns file:line findings with remediation guidance. NavigationView is deprecated; migrate to NavigationStack / NavigationSplitView." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for NavigationView occurrences and returns file:line findings with remediation guidance. NavigationView is deprecated; migrate to NavigationStack / NavigationSplitView.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "NavigationView Scan",
            guidance: "NavigationView is deprecated; migrate to NavigationStack / NavigationSplitView.",
            input: input, context: context,
            pattern: "\\bNavigationView\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanHardcodedColorsTool: AssistTool {
    public init() {}
    public var id: String { "scan_hardcoded_colors" }
    public var name: String { "Hardcoded Color Scan" }
    public var description: String { "Scans the workspace (or `path`) for Hardcoded Color occurrences and returns file:line findings with remediation guidance. Use asset catalog or semantic colors for dark mode and accessibility." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Hardcoded Color occurrences and returns file:line findings with remediation guidance. Use asset catalog or semantic colors for dark mode and accessibility.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Hardcoded Color Scan",
            guidance: "Use asset catalog or semantic colors for dark mode and accessibility.",
            input: input, context: context,
            pattern: "Color\\(\\s*red:|UIColor\\(\\s*red:|NSColor\\(\\s*red:|#colorLiteral",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanFixedFontSizesTool: AssistTool {
    public init() {}
    public var id: String { "scan_fixed_font_sizes" }
    public var name: String { "Fixed Font Size Scan" }
    public var description: String { "Scans the workspace (or `path`) for Fixed Font Size occurrences and returns file:line findings with remediation guidance. Fixed sizes ignore Dynamic Type; prefer text styles." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Fixed Font Size occurrences and returns file:line findings with remediation guidance. Fixed sizes ignore Dynamic Type; prefer text styles.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Fixed Font Size Scan",
            guidance: "Fixed sizes ignore Dynamic Type; prefer text styles.",
            input: input, context: context,
            pattern: "\\.font\\(\\.system\\(size:|UIFont\\.systemFont\\(ofSize:|NSFont\\.systemFont\\(ofSize:",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanAccessibilityModifiersTool: AssistTool {
    public init() {}
    public var id: String { "scan_accessibility_modifiers" }
    public var name: String { "Accessibility Modifier Scan" }
    public var description: String { "Scans the workspace (or `path`) for Accessibility Modifier occurrences and returns file:line findings with remediation guidance. Confirm interactive controls carry labels and identifiers." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Accessibility Modifier occurrences and returns file:line findings with remediation guidance. Confirm interactive controls carry labels and identifiers.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Accessibility Modifier Scan",
            guidance: "Confirm interactive controls carry labels and identifiers.",
            input: input, context: context,
            pattern: "\\.accessibility(Label|Hint|Value|Identifier|AddTraits|Hidden|Element)\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanSfSymbolImagesTool: AssistTool {
    public init() {}
    public var id: String { "scan_sf_symbol_images" }
    public var name: String { "SF Symbol Image Scan" }
    public var description: String { "Scans the workspace (or `path`) for SF Symbol Image occurrences and returns file:line findings with remediation guidance. Icon-only buttons need accessibility labels." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for SF Symbol Image occurrences and returns file:line findings with remediation guidance. Icon-only buttons need accessibility labels.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "SF Symbol Image Scan",
            guidance: "Icon-only buttons need accessibility labels.",
            input: input, context: context,
            pattern: "Image\\(systemName:|NSImage\\(systemSymbolName:|UIImage\\(systemName:",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanTestSkipsTool: AssistTool {
    public init() {}
    public var id: String { "scan_test_skips" }
    public var name: String { "Skipped/Disabled Test Scan" }
    public var description: String { "Scans the workspace (or `path`) for Skipped/Disabled Test occurrences and returns file:line findings with remediation guidance. Re-enable or justify skipped tests." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Skipped/Disabled Test occurrences and returns file:line findings with remediation guidance. Re-enable or justify skipped tests.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Skipped/Disabled Test Scan",
            guidance: "Re-enable or justify skipped tests.",
            input: input, context: context,
            pattern: "XCTSkip|\\.disabled\\(|\\.enabled\\(if:",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanTestExpectationsTool: AssistTool {
    public init() {}
    public var id: String { "scan_test_expectations" }
    public var name: String { "Test Expectation Scan" }
    public var description: String { "Scans the workspace (or `path`) for Test Expectation occurrences and returns file:line findings with remediation guidance. Prefer async tests with await over expectation waits where possible." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Test Expectation occurrences and returns file:line findings with remediation guidance. Prefer async tests with await over expectation waits where possible.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Test Expectation Scan",
            guidance: "Prefer async tests with await over expectation waits where possible.",
            input: input, context: context,
            pattern: "expectation\\(description:|wait\\(for:|fulfillment\\(of:|confirmation\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanSwiftTestingMacrosTool: AssistTool {
    public init() {}
    public var id: String { "scan_swift_testing_macros" }
    public var name: String { "Swift Testing Macro Scan" }
    public var description: String { "Scans the workspace (or `path`) for Swift Testing Macro occurrences and returns file:line findings with remediation guidance. Inventory of Swift Testing usage." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Swift Testing Macro occurrences and returns file:line findings with remediation guidance. Inventory of Swift Testing usage.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Swift Testing Macro Scan",
            guidance: "Inventory of Swift Testing usage.",
            input: input, context: context,
            pattern: "#expect\\(|#require\\(|@Test\\b|@Suite\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanXctassertUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_xctassert_usage" }
    public var name: String { "XCTAssert Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for XCTAssert Usage occurrences and returns file:line findings with remediation guidance. Inventory of XCTest assertions; consider migrating to #expect." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for XCTAssert Usage occurrences and returns file:line findings with remediation guidance. Inventory of XCTest assertions; consider migrating to #expect.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "XCTAssert Usage Scan",
            guidance: "Inventory of XCTest assertions; consider migrating to #expect.",
            input: input, context: context,
            pattern: "XCTAssert\\w*\\(|XCTFail\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanEnvironmentVariableReadsTool: AssistTool {
    public init() {}
    public var id: String { "scan_environment_variable_reads" }
    public var name: String { "Environment Variable Read Scan" }
    public var description: String { "Scans the workspace (or `path`) for Environment Variable Read occurrences and returns file:line findings with remediation guidance. Document every environment variable the code depends on." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Environment Variable Read occurrences and returns file:line findings with remediation guidance. Document every environment variable the code depends on.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Environment Variable Read Scan",
            guidance: "Document every environment variable the code depends on.",
            input: input, context: context,
            pattern: "ProcessInfo\\.processInfo\\.environment|getenv\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanProcessLaunchesTool: AssistTool {
    public init() {}
    public var id: String { "scan_process_launches" }
    public var name: String { "Process Launch Scan" }
    public var description: String { "Scans the workspace (or `path`) for Process Launch occurrences and returns file:line findings with remediation guidance. Avoid shell interpolation; pass fixed argv arrays." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Process Launch occurrences and returns file:line findings with remediation guidance. Avoid shell interpolation; pass fixed argv arrays.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Process Launch Scan",
            guidance: "Avoid shell interpolation; pass fixed argv arrays.",
            input: input, context: context,
            pattern: "Process\\(\\)|NSTask|posix_spawn|\\bsystem\\(|/bin/sh|/bin/zsh",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanFileManagerMutationsTool: AssistTool {
    public init() {}
    public var id: String { "scan_file_manager_mutations" }
    public var name: String { "FileManager Mutation Scan" }
    public var description: String { "Scans the workspace (or `path`) for FileManager Mutation occurrences and returns file:line findings with remediation guidance. Check destructive file operations are scoped and error-handled." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for FileManager Mutation occurrences and returns file:line findings with remediation guidance. Check destructive file operations are scoped and error-handled.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "FileManager Mutation Scan",
            guidance: "Check destructive file operations are scoped and error-handled.",
            input: input, context: context,
            pattern: "FileManager\\.default\\.(removeItem|moveItem|copyItem|createFile|trashItem)",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanUrlSessionUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_url_session_usage" }
    public var name: String { "URLSession Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for URLSession Usage occurrences and returns file:line findings with remediation guidance. Verify timeouts, cancellation and status-code handling." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for URLSession Usage occurrences and returns file:line findings with remediation guidance. Verify timeouts, cancellation and status-code handling.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "URLSession Usage Scan",
            guidance: "Verify timeouts, cancellation and status-code handling.",
            input: input, context: context,
            pattern: "URLSession\\.shared|URLSession\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanJsonDecodingTool: AssistTool {
    public init() {}
    public var id: String { "scan_json_decoding" }
    public var name: String { "JSON Decoding Scan" }
    public var description: String { "Scans the workspace (or `path`) for JSON Decoding occurrences and returns file:line findings with remediation guidance. Prefer Codable models; surface decoding errors." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for JSON Decoding occurrences and returns file:line findings with remediation guidance. Prefer Codable models; surface decoding errors.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "JSON Decoding Scan",
            guidance: "Prefer Codable models; surface decoding errors.",
            input: input, context: context,
            pattern: "JSONDecoder\\(\\)|JSONSerialization\\.jsonObject",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanCoreDataUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_core_data_usage" }
    public var name: String { "Core Data Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for Core Data Usage occurrences and returns file:line findings with remediation guidance. Ensure contexts are used on their own queues." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Core Data Usage occurrences and returns file:line findings with remediation guidance. Ensure contexts are used on their own queues.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Core Data Usage Scan",
            guidance: "Ensure contexts are used on their own queues.",
            input: input, context: context,
            pattern: "NSManagedObject|NSPersistentContainer|NSFetchRequest|NSManagedObjectContext",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanSwiftdataUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_swiftdata_usage" }
    public var name: String { "SwiftData Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for SwiftData Usage occurrences and returns file:line findings with remediation guidance. Inventory of SwiftData models and queries." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for SwiftData Usage occurrences and returns file:line findings with remediation guidance. Inventory of SwiftData models and queries.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "SwiftData Usage Scan",
            guidance: "Inventory of SwiftData models and queries.",
            input: input, context: context,
            pattern: "@Model\\b|ModelContainer|ModelContext|@Query\\b",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanMainThreadChecksTool: AssistTool {
    public init() {}
    public var id: String { "scan_main_thread_checks" }
    public var name: String { "Main Thread Check Scan" }
    public var description: String { "Scans the workspace (or `path`) for Main Thread Check occurrences and returns file:line findings with remediation guidance. Prefer compile-time isolation over runtime main-thread checks." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Main Thread Check occurrences and returns file:line findings with remediation guidance. Prefer compile-time isolation over runtime main-thread checks.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Main Thread Check Scan",
            guidance: "Prefer compile-time isolation over runtime main-thread checks.",
            input: input, context: context,
            pattern: "Thread\\.isMainThread|dispatchPrecondition|MainActor\\.assumeIsolated",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanLockUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_lock_usage" }
    public var name: String { "Lock Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for Lock Usage occurrences and returns file:line findings with remediation guidance. Hold locks briefly and never across await." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Lock Usage occurrences and returns file:line findings with remediation guidance. Hold locks briefly and never across await.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Lock Usage Scan",
            guidance: "Hold locks briefly and never across await.",
            input: input, context: context,
            pattern: "NSLock|os_unfair_lock|NSRecursiveLock|OSAllocatedUnfairLock|Mutex<|pthread_mutex",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanStrongDelegatesTool: AssistTool {
    public init() {}
    public var id: String { "scan_strong_delegates" }
    public var name: String { "Strong Delegate Property Scan" }
    public var description: String { "Scans the workspace (or `path`) for Strong Delegate Property occurrences and returns file:line findings with remediation guidance. Delegates should usually be weak to avoid retain cycles." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Strong Delegate Property occurrences and returns file:line findings with remediation guidance. Delegates should usually be weak to avoid retain cycles.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Strong Delegate Property Scan",
            guidance: "Delegates should usually be weak to avoid retain cycles.",
            input: input, context: context,
            pattern: "^(?!.*\\bweak\\b).*\\bvar\\s+\\w*[dD]elegate\\s*:",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanStringFormatCallsTool: AssistTool {
    public init() {}
    public var id: String { "scan_string_format_calls" }
    public var name: String { "String(format:) Scan" }
    public var description: String { "Scans the workspace (or `path`) for String(format:) occurrences and returns file:line findings with remediation guidance. Prefer string interpolation or FormatStyle; check specifiers match argument types." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for String(format:) occurrences and returns file:line findings with remediation guidance. Prefer string interpolation or FormatStyle; check specifiers match argument types.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "String(format:) Scan",
            guidance: "Prefer string interpolation or FormatStyle; check specifiers match argument types.",
            input: input, context: context,
            pattern: "String\\(format:",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanFormatterAllocationsTool: AssistTool {
    public init() {}
    public var id: String { "scan_formatter_allocations" }
    public var name: String { "Formatter Allocation Scan" }
    public var description: String { "Scans the workspace (or `path`) for Formatter Allocation occurrences and returns file:line findings with remediation guidance. Formatters are expensive; cache them or use FormatStyle." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Formatter Allocation occurrences and returns file:line findings with remediation guidance. Formatters are expensive; cache them or use FormatStyle.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Formatter Allocation Scan",
            guidance: "Formatters are expensive; cache them or use FormatStyle.",
            input: input, context: context,
            pattern: "DateFormatter\\(\\)|NumberFormatter\\(\\)|ISO8601DateFormatter\\(\\)",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanLoggerUsageTool: AssistTool {
    public init() {}
    public var id: String { "scan_logger_usage" }
    public var name: String { "Unified Logging Usage Scan" }
    public var description: String { "Scans the workspace (or `path`) for Unified Logging Usage occurrences and returns file:line findings with remediation guidance. Inventory of unified logging; confirm privacy levels on dynamic values." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for Unified Logging Usage occurrences and returns file:line findings with remediation guidance. Inventory of unified logging; confirm privacy levels on dynamic values.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "Unified Logging Usage Scan",
            guidance: "Inventory of unified logging; confirm privacy levels on dynamic values.",
            input: input, context: context,
            pattern: "Logger\\(|os_log\\(|OSLog\\(",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}


public struct XKScanPreviewDeclarationsTool: AssistTool {
    public init() {}
    public var id: String { "scan_preview_declarations" }
    public var name: String { "SwiftUI Preview Scan" }
    public var description: String { "Scans the workspace (or `path`) for SwiftUI Preview occurrences and returns file:line findings with remediation guidance. Inventory of previews; every reusable view should have one." }
    public var capability: ToolCapability { .diagnostics }
    public var riskLevel: ToolRiskLevel { .safeRead }
    public var isReadOnly: Bool { true }
    public var isMutating: Bool { false }
    public var parametersSchema: JSONSchema {
        JSONSchema(type: "object", description: "Scans the workspace (or `path`) for SwiftUI Preview occurrences and returns file:line findings with remediation guidance. Inventory of previews; every reusable view should have one.", properties: ["path": JSONSchema(type: "string", description: "Workspace-relative file or directory to inspect (default: workspace root)."), "max_results": JSONSchema(type: "integer", description: "Maximum findings to return (default 200, max 2000)."), "extensions": JSONSchema(type: "array", description: "Optional file extensions to scan instead of the default (e.g. [\"swift\",\"m\"]).", items: JSONSchema(type: "string"))], required: [])
    }
    public func execute(input: [String: Any], context: AssistContext) async throws -> AssistToolResult {
        let extensions: Set<String>? = AssistToolKit.stringArray(input, "extensions").isEmpty ? ["swift"] : Set(AssistToolKit.stringArray(input, "extensions").map { $0.lowercased() })
        return AssistToolKit.scanResult(
            title: "SwiftUI Preview Scan",
            guidance: "Inventory of previews; every reusable view should have one.",
            input: input, context: context,
            pattern: "#Preview|PreviewProvider",
            extensions: extensions,
            skipComments: true,
            caseInsensitive: false
        )
    }
}
