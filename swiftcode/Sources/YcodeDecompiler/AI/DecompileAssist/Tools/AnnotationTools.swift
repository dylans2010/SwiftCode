import Foundation

/// Annotation tools: rename symbols/functions, add comments, labels, and save
/// analysis findings. All of these MUTATE the analysis store (never the
/// binary on disk) and therefore require explicit user approval: the caller
/// must pass `"approved": true`. The registry additionally enforces
/// `requiresApproval` before dispatch.

/// Shared approval gate for mutation tools.
func decompileAssistCheckApproval(_ arguments: [String: Any], tool: String) -> String? {
    DecompileAssistToolSupport.bool(arguments, "approved")
        ? nil
        : DecompileAssistToolSupport.approvalRequired(tool)
}

public struct RenameSymbolTool: DecompileAssistTool {
    public init() {}
    public let id = "rename_symbol"
    public let displayName = "Rename Symbol"
    public let description = "Rename a symbol in the analysis database (reversible — the original name is preserved). Requires approved:true."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "name": ["type": "string", "description": "Current symbol name (original, demangled, or user name)"],
            "new_name": ["type": "string", "description": "New display name"],
            "approved": ["type": "boolean", "description": "Must be true — this mutates analysis data"],
        ] as [String: Any],
        "required": ["name", "new_name"],
        ]
    }
    public let requiresApproval = true

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        if let denial = decompileAssistCheckApproval(arguments, tool: id) { return denial }
        guard let name = DecompileAssistToolSupport.string(arguments, "name"),
              let newName = DecompileAssistToolSupport.string(arguments, "new_name"), !newName.isEmpty else {
            return DecompileAssistToolSupport.error("rename_symbol requires 'name' and 'new_name'")
        }
        let ok = await session.renameSymbol(name: name, to: newName)
        return ok
            ? DecompileAssistToolSupport.encode(["ok": true, "renamed": name, "new_name": newName])
            : DecompileAssistToolSupport.error("symbol '\(name)' not found")
    }
}

public struct RenameFunctionTool: DecompileAssistTool {
    public init() {}
    public let id = "rename_function"
    public let displayName = "Rename Function"
    public let description = "Rename the function at an address (reversible). Requires approved:true."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "Function entry address"],
            "new_name": ["type": "string"],
            "approved": ["type": "boolean"],
        ] as [String: Any],
        "required": ["address", "new_name"],
        ]
    }
    public let requiresApproval = true

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        if let denial = decompileAssistCheckApproval(arguments, tool: id) { return denial }
        let addr = try DecompileAssistToolSupport.requireAddress(
            arguments, keys: ["address", "function_address"], tool: id)
        guard let newName = DecompileAssistToolSupport.string(arguments, "new_name"), !newName.isEmpty else {
            return DecompileAssistToolSupport.error("rename_function requires 'new_name'")
        }
        let store = await session.analysisStore()
        guard let fn = await store.function(atOrContaining: addr.value) else {
            return DecompileAssistToolSupport.error("no function at \(addr.hexString)")
        }
        let ok = await session.renameFunction(at: fn.address, to: newName)
        return ok
            ? DecompileAssistToolSupport.encode(["ok": true, "address": fn.address.hexString,
                                                 "old_name": fn.originalName ?? fn.displayName,
                                                 "new_name": newName])
            : DecompileAssistToolSupport.error("rename failed")
    }
}

public struct AddAnalysisCommentTool: DecompileAssistTool {
    public init() {}
    public let id = "add_analysis_comment"
    public let displayName = "Add Comment"
    public let description = "Attach a user comment to an address in the analysis database. Requires approved:true."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string"],
            "comment": ["type": "string", "description": "Comment text"],
            "approved": ["type": "boolean"],
        ] as [String: Any],
        "required": ["address", "comment"],
        ]
    }
    public let requiresApproval = true

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        if let denial = decompileAssistCheckApproval(arguments, tool: id) { return denial }
        let addr = try DecompileAssistToolSupport.requireAddress(arguments, tool: id)
        guard let comment = DecompileAssistToolSupport.string(arguments, "comment"), !comment.isEmpty else {
            return DecompileAssistToolSupport.error("add_analysis_comment requires 'comment'")
        }
        await session.addComment(comment, at: addr)
        return DecompileAssistToolSupport.encode(["ok": true, "address": addr.hexString, "comment": comment])
    }
}

public struct AnnotateFunctionTool: DecompileAssistTool {
    public init() {}
    public let id = "annotate_function"
    public let displayName = "Annotate Function"
    public let description = "Attach a comment to a function entry address (convenience wrapper over add_analysis_comment). Requires approved:true."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string"],
            "comment": ["type": "string"],
            "approved": ["type": "boolean"],
        ] as [String: Any],
        "required": ["address", "comment"],
        ]
    }
    public let requiresApproval = true

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        if let denial = decompileAssistCheckApproval(arguments, tool: id) { return denial }
        let addr = try DecompileAssistToolSupport.requireAddress(
            arguments, keys: ["address", "function_address"], tool: id)
        guard let comment = DecompileAssistToolSupport.string(arguments, "comment"), !comment.isEmpty else {
            return DecompileAssistToolSupport.error("annotate_function requires 'comment'")
        }
        let store = await session.analysisStore()
        guard let fn = await store.function(atOrContaining: addr.value) else {
            return DecompileAssistToolSupport.error("no function at \(addr.hexString)")
        }
        await session.addComment(comment, at: fn.address)
        return DecompileAssistToolSupport.encode(["ok": true, "function": fn.address.hexString,
                                                  "comment": comment])
    }
}

public struct CreateUserLabelTool: DecompileAssistTool {
    public init() {}
    public let id = "create_user_label"
    public let displayName = "Create Label"
    public let description = "Create a user label at an address (shown in the UI instead of/in addition to auto names). Requires approved:true."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string"],
            "label": ["type": "string", "description": "Label text"],
            "approved": ["type": "boolean"],
        ] as [String: Any],
        "required": ["address", "label"],
        ]
    }
    public let requiresApproval = true

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        if let denial = decompileAssistCheckApproval(arguments, tool: id) { return denial }
        let addr = try DecompileAssistToolSupport.requireAddress(arguments, tool: id)
        guard let label = DecompileAssistToolSupport.string(arguments, "label"), !label.isEmpty else {
            return DecompileAssistToolSupport.error("create_user_label requires 'label'")
        }
        await session.addLabel(label, at: addr)
        return DecompileAssistToolSupport.encode(["ok": true, "address": addr.hexString, "label": label])
    }
}

public struct SaveAnalysisFindingTool: DecompileAssistTool {
    public init() {}
    public let id = "save_analysis_finding"
    public let displayName = "Save Finding"
    public let description = "Save an analysis finding (title + detail, optionally tied to an address) into the session's findings list. Findings start userConfirmed=false and carry aiSuggestion provenance unless confirmed. Requires approved:true."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "title": ["type": "string"],
            "detail": ["type": "string"],
            "address": ["type": "string", "description": "Optional related address"],
            "function_address": ["type": "string", "description": "Optional related function"],
            "confirmed": ["type": "boolean", "description": "Set true only when the user has verified the finding"],
            "approved": ["type": "boolean"],
        ] as [String: Any],
        "required": ["title", "detail"],
        ]
    }
    public let requiresApproval = true

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        if let denial = decompileAssistCheckApproval(arguments, tool: id) { return denial }
        guard let title = DecompileAssistToolSupport.string(arguments, "title"), !title.isEmpty,
              let detail = DecompileAssistToolSupport.string(arguments, "detail"), !detail.isEmpty else {
            return DecompileAssistToolSupport.error("save_analysis_finding requires 'title' and 'detail'")
        }
        let address = DecompileAssistToolSupport.address(arguments, keys: ["address"])
        let functionAddress = DecompileAssistToolSupport.address(arguments, keys: ["function_address"])
        let confirmed = DecompileAssistToolSupport.bool(arguments, "confirmed")
        let finding = AnalysisFinding(
            title: title,
            detail: detail,
            address: address,
            functionAddress: functionAddress,
            userConfirmed: confirmed,
            provenance: confirmed ? .user : .aiSuggestion
        )
        await session.analysisStore().addFinding(finding)
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "finding_id": finding.id,
            "user_confirmed": finding.userConfirmed,
            "provenance": finding.provenance.rawValue,
        ])
    }
}
