import Foundation

/// Function-level tools: listing, inspection, pseudocode/disassembly,
/// signatures, references, callers/callees, comparison, and basic blocks.
/// Pseudocode is produced on demand through `session.decompileFunction` —
/// a real backend call — and cached in the store.

public struct ListFunctionsTool: DecompileAssistTool {
    public init() {}
    public let id = "list_functions"
    public let displayName = "List Functions"
    public let description = "List discovered functions with pagination. Optional filters: name substring, address range, kind."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "offset": ["type": "integer", "description": "Pagination offset (default 0)"],
            "limit": ["type": "integer", "description": "Max results (default 100, max 1000)"],
            "name_contains": ["type": "string", "description": "Case-insensitive substring filter on function name"],
            "kind": ["type": "string", "description": "Function kind filter: importedSymbol, exportedSymbol, discovered, entryPoint, userLabel, thunk"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        var functions = await session.functions()
        if let needle = DecompileAssistToolSupport.string(arguments, "name_contains")?.lowercased() {
            functions = functions.filter { $0.displayName.lowercased().contains(needle) || ($0.originalName ?? "").lowercased().contains(needle) }
        }
        if let kindRaw = DecompileAssistToolSupport.string(arguments, "kind"),
           let kind = DecompilerFunction.Kind(rawValue: kindRaw) {
            functions = functions.filter { $0.kind == kind }
        }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments)
        let page = Array(functions.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total": functions.count,
            "offset": offset,
            "returned": page.count,
            "functions": page.map(DecompileAssistToolSupport.functionDict),
        ])
    }
}

public struct InspectFunctionTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_function"
    public let displayName = "Inspect Function"
    public let description = "Return full metadata for the function at a given address (or containing an address): bounds, kind, provenance, callers/callees, variables."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "Function entry address (0x…) or any address inside it"],
            "function_address": ["type": "string"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(
            arguments, keys: ["address", "function_address", "functionAddress"], tool: id)
        let store = await session.analysisStore()
        guard let fn = await store.function(atOrContaining: addr.value) else {
            return DecompileAssistToolSupport.error("no function at or containing \(addr.hexString)")
        }
        var d = DecompileAssistToolSupport.functionDict(fn)
        d["ok"] = true
        if let comment = await store.comment(at: fn.address) { d["user_comment"] = comment }
        return DecompileAssistToolSupport.encode(d)
    }
}

public struct GetFunctionPseudocodeTool: DecompileAssistTool {
    public init() {}
    public let id = "get_function_pseudocode"
    public let displayName = "Function Pseudocode"
    public let description = "Return C-like pseudocode for a function. Decompiles on demand via the resolved backend when no cached result exists."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "Function entry address (0x…)"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(
            arguments, keys: ["address", "function_address"], tool: id)
        let store = await session.analysisStore()
        guard await store.function(at: addr.value) != nil else {
            return DecompileAssistToolSupport.error("no function at \(addr.hexString)")
        }
        do {
            let result = try await session.decompileFunction(at: addr)
            return DecompileAssistToolSupport.encode([
                "ok": true,
                "function_address": result.functionAddress.hexString,
                "function_name": result.functionName,
                "signature": DecompileAssistToolSupport.opt(result.signature),
                "return_type": DecompileAssistToolSupport.opt(result.returnType),
                "parameters": result.parameters,
                "local_variables": result.localVariables,
                "pseudocode": result.pseudocode,
                "warnings": result.warnings,
                "engine": result.engineID,
                "engine_version": DecompileAssistToolSupport.opt(result.engineVersion),
                "provenance": "engine",
            ])
        } catch {
            return DecompileAssistToolSupport.error("decompilation failed: \(error.localizedDescription)")
        }
    }
}

public struct GetFunctionAssemblyTool: DecompileAssistTool {
    public init() {}
    public let id = "get_function_assembly"
    public let displayName = "Function Assembly"
    public let description = "Return the disassembled instruction listing for a function (decoded on demand through the disassembler backend and cached)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string"],
            "max_instructions": ["type": "integer", "description": "Cap on returned instructions (default 500, max 2000)"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(
            arguments, keys: ["address", "function_address"], tool: id)
        let maxCount = min(2_000, max(1, DecompileAssistToolSupport.int(arguments, "max_instructions", fallback: 500) ?? 500))
        do {
            let instructions = try await session.disassembleFunction(at: addr)
            let total = instructions.count
            let page = Array(instructions.prefix(maxCount))
            return DecompileAssistToolSupport.encode([
                "ok": true,
                "function_address": addr.hexString,
                "total_instructions": total,
                "returned": page.count,
                "truncated": total > page.count,
                "instructions": page.map(DecompileAssistToolSupport.instructionDict),
            ])
        } catch {
            return DecompileAssistToolSupport.error("disassembly failed: \(error.localizedDescription)")
        }
    }
}

public struct GetFunctionSignatureTool: DecompileAssistTool {
    public init() {}
    public let id = "get_function_signature"
    public let displayName = "Function Signature"
    public let description = "Return the function's signature information: name, return type, parameters, locals, calling convention — from analysis data or cached pseudocode."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": ["address": ["type": "string"]] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(
            arguments, keys: ["address", "function_address"], tool: id)
        let store = await session.analysisStore()
        guard let fn = await store.function(atOrContaining: addr.value) else {
            return DecompileAssistToolSupport.error("no function at \(addr.hexString)")
        }
        var d: [String: Any] = [
            "ok": true,
            "address": fn.address.hexString,
            "name": fn.displayName,
            "original_name": DecompileAssistToolSupport.opt(fn.originalName),
            "kind": fn.kind.rawValue,
            "size": fn.size,
            "return_type": DecompileAssistToolSupport.opt(fn.returnType),
            "calling_convention": DecompileAssistToolSupport.opt(fn.callingConvention),
            "parameters": fn.parameters,
            "local_variables": fn.localVariables,
            "provenance": fn.source.provenance.rawValue,
        ]
        if let pseudo = await store.pseudocode(forFunctionAt: fn.address.value) {
            d["decompiled_signature"] = DecompileAssistToolSupport.opt(pseudo.signature)
            d["decompiled_return_type"] = DecompileAssistToolSupport.opt(pseudo.returnType)
            d["decompiled_parameters"] = pseudo.parameters
            d["decompiled_locals"] = pseudo.localVariables
        }
        return DecompileAssistToolSupport.encode(d)
    }
}

public struct GetFunctionReferencesTool: DecompileAssistTool {
    public init() {}
    public let id = "get_function_references"
    public let displayName = "Function References"
    public let description = "List cross-references to and from a function: calls, jumps, data references."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string"],
            "direction": ["type": "string", "description": "to|from|both (default both)"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(
            arguments, keys: ["address", "function_address"], tool: id)
        let store = await session.analysisStore()
        guard let fn = await store.function(atOrContaining: addr.value) else {
            return DecompileAssistToolSupport.error("no function at \(addr.hexString)")
        }
        let direction = DecompileAssistToolSupport.string(arguments, "direction")?.lowercased() ?? "both"
        let xrefs = await store.crossReferences
        var matched = xrefs.filter { x in
            let to = x.destinationFunction == fn.address || x.destination == fn.address
            let from = x.sourceFunction == fn.address
            switch direction {
            case "to": return to
            case "from": return from
            default: return to || from
            }
        }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let total = matched.count
        matched = Array(matched.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function": fn.address.hexString,
            "total": total,
            "references": matched.map(DecompileAssistToolSupport.xrefDict),
        ])
    }
}

public struct GetFunctionCallersTool: DecompileAssistTool {
    public init() {}
    public let id = "get_function_callers"
    public let displayName = "Function Callers"
    public let description = "List functions that call the target function (from stored call edges and xrefs)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(
            arguments, keys: ["address", "function_address"], tool: id)
        let store = await session.analysisStore()
        guard let fn = await store.function(atOrContaining: addr.value) else {
            return DecompileAssistToolSupport.error("no function at \(addr.hexString)")
        }
        // Prefer recorded caller edges; fall back to call xrefs.
        var callerAddrs = Set(fn.callers.map(\.value))
        let xrefs = await store.crossReferences
        for x in xrefs where x.kind == .call && x.destinationFunction == fn.address {
            if let sf = x.sourceFunction { callerAddrs.insert(sf.value) }
        }
        let functions = await store.functions
        let callers = functions.filter { callerAddrs.contains($0.address.value) }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(callers.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function": fn.address.hexString,
            "total": callers.count,
            "callers": page.map(DecompileAssistToolSupport.functionDict),
        ])
    }
}

public struct GetFunctionCalleesTool: DecompileAssistTool {
    public init() {}
    public let id = "get_function_callees"
    public let displayName = "Function Callees"
    public let description = "List functions called by the target function (from stored call edges and xrefs)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(
            arguments, keys: ["address", "function_address"], tool: id)
        let store = await session.analysisStore()
        guard let fn = await store.function(atOrContaining: addr.value) else {
            return DecompileAssistToolSupport.error("no function at \(addr.hexString)")
        }
        var calleeAddrs = Set(fn.callees.map(\.value))
        let xrefs = await store.crossReferences
        for x in xrefs where x.kind == .call && x.sourceFunction == fn.address {
            if let df = x.destinationFunction { calleeAddrs.insert(df.value) }
        }
        let functions = await store.functions
        let callees = functions.filter { calleeAddrs.contains($0.address.value) }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(callees.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function": fn.address.hexString,
            "total": callees.count,
            "callees": page.map(DecompileAssistToolSupport.functionDict),
        ])
    }
}

public struct CompareFunctionsTool: DecompileAssistTool {
    public init() {}
    public let id = "compare_functions"
    public let displayName = "Compare Functions"
    public let description = "Compare two functions side by side: size, kind, callers/callees overlap, and (when available) pseudocode similarity hints."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address_a": ["type": "string"],
            "address_b": ["type": "string"],
        ] as [String: Any],
        "required": ["address_a", "address_b"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let a = DecompileAssistToolSupport.address(arguments, keys: ["address_a", "a"]),
              let b = DecompileAssistToolSupport.address(arguments, keys: ["address_b", "b"]) else {
            return DecompileAssistToolSupport.error("compare_functions requires address_a and address_b")
        }
        let store = await session.analysisStore()
        guard let fa = await store.function(atOrContaining: a.value),
              let fb = await store.function(atOrContaining: b.value) else {
            return DecompileAssistToolSupport.error("could not resolve one or both function addresses")
        }
        let callersA = Set(fa.callers.map(\.value))
        let callersB = Set(fb.callers.map(\.value))
        let calleesA = Set(fa.callees.map(\.value))
        let calleesB = Set(fb.callees.map(\.value))
        var d: [String: Any] = [
            "ok": true,
            "function_a": DecompileAssistToolSupport.functionDict(fa),
            "function_b": DecompileAssistToolSupport.functionDict(fb),
            "same_size": fa.size == fb.size,
            "size_delta": Int64(fa.size) - Int64(fb.size),
            "same_kind": fa.kind == fb.kind,
            "shared_callers": callersA.intersection(callersB).count,
            "shared_callees": calleesA.intersection(calleesB).count,
        ]
        if let pa = await store.pseudocode(forFunctionAt: fa.address.value),
           let pb = await store.pseudocode(forFunctionAt: fb.address.value) {
            let linesA = Set(pa.pseudocode.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
            let linesB = Set(pb.pseudocode.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
            let common = linesA.intersection(linesB).count
            let union = max(1, linesA.union(linesB).count)
            d["pseudocode_line_overlap"] = Double(common) / Double(union)
            d["note"] = "pseudocode overlap is a heuristic similarity hint, not proof of equivalence"
        }
        return DecompileAssistToolSupport.encode(d)
    }
}

public struct InspectBasicBlockTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_basic_block"
    public let displayName = "Basic Block"
    public let description = "Return the basic block containing an address within a function, built structurally from decoded instructions (leaders at branch targets and after branches/returns)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "Any address inside the function"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(arguments, tool: id)
        let store = await session.analysisStore()
        guard let fn = await store.function(containing: addr.value) else {
            return DecompileAssistToolSupport.error("no function contains \(addr.hexString)")
        }
        let instructions: [Instruction]
        do {
            instructions = try await session.disassembleFunction(at: fn.address)
        } catch {
            return DecompileAssistToolSupport.error("disassembly failed: \(error.localizedDescription)")
        }
        guard !instructions.isEmpty else {
            return DecompileAssistToolSupport.error("no instructions decoded for \(fn.address.hexString)")
        }

        // Structural basic-block partition.
        var leaders = Set<UInt64>([instructions[0].address.value])
        for ins in instructions {
            if let target = ins.branchTarget { leaders.insert(target.value) }
            if ins.classification == .branch || ins.classification == .call || ins.classification == .returnInstruction {
                if let next = instructions.first(where: { $0.address.value > ins.address.value }) {
                    leaders.insert(next.address.value)
                }
            }
        }
        let sortedLeaders = leaders.sorted()
        var blocks: [(start: UInt64, end: UInt64, ins: [Instruction])] = []
        for (i, leader) in sortedLeaders.enumerated() {
            let nextLeader = i + 1 < sortedLeaders.count ? sortedLeaders[i + 1] : UInt64.max
            let members = instructions.filter {
                $0.address.value >= leader && $0.address.value < nextLeader
            }
            if !members.isEmpty {
                blocks.append((leader, members.last!.address.value, members))
            }
        }
        guard let block = blocks.first(where: {
            addr.value >= $0.start && addr.value <= $0.end
        }) else {
            return DecompileAssistToolSupport.error("address \(addr.hexString) is outside decoded instructions")
        }
        let last = block.ins.last
        var successors: [String] = []
        if let bt = last?.branchTarget { successors.append(bt.hexString) }
        if let nextBlock = blocks.first(where: { $0.start > block.start }) {
            if last?.classification != Instruction.Classification.returnInstruction {
                successors.append(DecompilerAddress(virtual: nextBlock.start).hexString)
            }
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function": fn.address.hexString,
            "block_start": DecompilerAddress(virtual: block.start).hexString,
            "block_end": DecompilerAddress(virtual: block.end).hexString,
            "instruction_count": block.ins.count,
            "terminator": DecompileAssistToolSupport.opt(last.map { "\($0.mnemonic) \($0.operandText)".trimmingCharacters(in: .whitespaces) }),
            "terminator_classification": DecompileAssistToolSupport.opt(last?.classification.rawValue),
            "successors": successors,
            "instructions": block.ins.map(DecompileAssistToolSupport.instructionDict),
            "note": "basic blocks derived structurally from decoded instructions; may differ from backend CFG analysis",
        ])
    }
}
