import Foundation

/// Analysis tools: control-flow graph, call graph, cross-references,
/// variables, types, raw byte-pattern search, navigation, memory regions.
/// Everything derives from real store/session data.

public struct GetControlFlowGraphTool: DecompileAssistTool {
    public init() {}
    public let id = "get_control_flow_graph"
    public let displayName = "Control Flow Graph"
    public let description = "Build the function's control-flow graph from decoded instructions: basic blocks, successors, and branch kinds. Requires disassembly (decoded on demand)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "Function entry address"],
            "max_blocks": ["type": "integer", "description": "Cap on returned blocks (default 200, max 1000)"],
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
        let instructions: [Instruction]
        do {
            instructions = try await session.disassembleFunction(at: fn.address)
        } catch {
            return DecompileAssistToolSupport.error("disassembly failed: \(error.localizedDescription)")
        }
        guard !instructions.isEmpty else {
            return DecompileAssistToolSupport.error("no instructions decoded for \(fn.address.hexString)")
        }

        // Basic-block leaders: function entry, branch targets, and the
        // instruction following any branch/call/return.
        var leaders = Set<UInt64>([instructions[0].address.value])
        for ins in instructions {
            if let target = ins.branchTarget { leaders.insert(target.value) }
            switch ins.classification {
            case .branch, .call, .returnInstruction:
                if let next = instructions.first(where: { $0.address.value > ins.address.value }) {
                    leaders.insert(next.address.value)
                }
            default: break
            }
        }
        let sorted = leaders.sorted()
        var blocks: [[String: Any]] = []
        var edges: [[String: Any]] = []
        let maxBlocks = min(1_000, max(1, DecompileAssistToolSupport.int(arguments, "max_blocks", fallback: 200) ?? 200))

        for (i, leader) in sorted.enumerated() {
            let nextLeader = i + 1 < sorted.count ? sorted[i + 1] : UInt64.max
            let members = instructions.filter { $0.address.value >= leader && $0.address.value < nextLeader }
            guard let first = members.first, let last = members.last else { continue }
            var successors: [UInt64] = []
            var branchKind: String? = nil
            switch last.classification {
            case .branch:
                branchKind = "unconditional"
                if let t = last.branchTarget { successors.append(t.value) }
            case .returnInstruction:
                branchKind = "return"
            default:
                // Could be conditional branch (branchTarget set) or fallthrough.
                if let t = last.branchTarget {
                    branchKind = "conditional"
                    successors.append(t.value)
                    if let next = instructions.first(where: { $0.address.value > last.address.value }),
                       next.address.value < nextLeader || nextLeader == UInt64.max {
                        successors.append(next.address.value)
                    }
                } else {
                    if let next = instructions.first(where: { $0.address.value > last.address.value }) {
                        successors.append(next.address.value)
                    }
                }
            }
            for s in successors { edges.append(["from": first.address.hexString, "to": DecompilerAddress(virtual: s).hexString]) }
            blocks.append([
                "start": first.address.hexString,
                "end": last.address.hexString,
                "instructions": members.count,
                "terminator": "\(last.mnemonic) \(last.operandText)".trimmingCharacters(in: .whitespaces),
                "branch_kind": DecompileAssistToolSupport.opt(branchKind),
                "is_entry": i == 0,
            ])
            if blocks.count >= maxBlocks { break }
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function": fn.address.hexString,
            "total_instructions": instructions.count,
            "blocks": blocks,
            "edges": edges,
            "note": "CFG derived structurally from decoded instructions",
        ])
    }
}

public struct GetCallGraphTool: DecompileAssistTool {
    public init() {}
    public let id = "get_call_graph"
    public let displayName = "Call Graph"
    public let description = "Return call edges (caller → callee) built from stored function call edges and call-kind cross-references. Optional depth-limited neighborhood around an address."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "Optional center address; when given returns the neighborhood up to depth"],
            "depth": ["type": "integer", "description": "Neighborhood depth (default 1, max 3)"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let store = await session.analysisStore()
        let functions = await store.functions
        let xrefs = await store.crossReferences
        var edges = Set<String>()
        var edgeList: [[String: Any]] = []
        func addEdge(_ from: UInt64, _ to: UInt64, _ via: String) {
            let key = "\(from)->\(to)"
            guard edges.insert(key).inserted else { return }
            edgeList.append([
                "caller": DecompilerAddress(virtual: from).hexString,
                "callee": DecompilerAddress(virtual: to).hexString,
                "via": via,
            ])
        }
        for f in functions {
            for c in f.callees { addEdge(f.address.value, c.value, "function_record") }
        }
        for x in xrefs where x.kind == .call {
            if let s = x.sourceFunction, let d = x.destinationFunction {
                addEdge(s.value, d.value, "xref")
            }
        }

        if let addr = DecompileAssistToolSupport.address(arguments) {
            let depth = min(3, max(1, DecompileAssistToolSupport.int(arguments, "depth", fallback: 1) ?? 1))
            guard let center = await store.function(containing: addr.value) else {
                return DecompileAssistToolSupport.error("no function at \(addr.hexString)")
            }
            // BFS over edges.
            var frontier: Set<UInt64> = [center.address.value]
            var visited: Set<UInt64> = [center.address.value]
            var neighborhood: [[String: Any]] = []
            for _ in 0..<depth {
                var next: Set<UInt64> = []
                for e in edgeList {
                    let fromHex = e["caller"] as? String ?? ""
                    let toHex = e["callee"] as? String ?? ""
                    guard let from = UInt64(fromHex.dropFirst(2), radix: 16),
                          let to = UInt64(toHex.dropFirst(2), radix: 16) else { continue }
                    if frontier.contains(from) && !visited.contains(to) {
                        visited.insert(to); next.insert(to)
                        neighborhood.append(e)
                    }
                }
                frontier = next
                if frontier.isEmpty { break }
            }
            return DecompileAssistToolSupport.encode([
                "ok": true,
                "center": center.address.hexString,
                "depth": depth,
                "total_edges": edgeList.count,
                "neighborhood_edges": neighborhood,
            ])
        }

        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 500)
        let page = Array(edgeList.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total_edges": edgeList.count,
            "offset": offset,
            "edges": page,
        ])
    }
}

public struct GetCrossReferencesTool: DecompileAssistTool {
    public init() {}
    public let id = "get_cross_references"
    public let displayName = "Cross References"
    public let description = "Query the cross-reference database. Filter by source/destination address, kind (call, jump, branch, data, string, symbol, section, memory), or function."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "Match xrefs touching this address (source or destination)"],
            "kind": ["type": "string", "description": "call|jump|branch|data|string|symbol|section|memory"],
            "direction": ["type": "string", "description": "to|from|both (default both)"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        var xrefs = await session.xrefs()
        if let kindRaw = DecompileAssistToolSupport.string(arguments, "kind"),
           let kind = CrossReference.Kind(rawValue: kindRaw) {
            xrefs = xrefs.filter { $0.kind == kind }
        }
        if let addr = DecompileAssistToolSupport.address(arguments) {
            let direction = DecompileAssistToolSupport.string(arguments, "direction")?.lowercased() ?? "both"
            xrefs = xrefs.filter { x in
                let touches = x.source == addr || x.destination == addr
                    || x.source.value == addr.value || x.destination.value == addr.value
                switch direction {
                case "to": return x.destination == addr || x.destination.value == addr.value
                case "from": return x.source == addr || x.source.value == addr.value
                default: return touches
                }
            }
        }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(xrefs.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total": xrefs.count,
            "offset": offset,
            "references": page.map(DecompileAssistToolSupport.xrefDict),
        ])
    }
}

public struct GetVariableInformationTool: DecompileAssistTool {
    public init() {}
    public let id = "get_variable_information"
    public let displayName = "Variable Information"
    public let description = "Return parameter/local-variable information for a function from analysis records and cached decompilation results."
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
            "function": fn.address.hexString,
            "parameters": fn.parameters,
            "local_variables": fn.localVariables,
            "provenance": fn.source.provenance.rawValue,
        ]
        if let pseudo = await store.pseudocode(forFunctionAt: fn.address.value) {
            d["decompiled_parameters"] = pseudo.parameters
            d["decompiled_locals"] = pseudo.localVariables
            d["decompiled_signature"] = DecompileAssistToolSupport.opt(pseudo.signature)
            d["decompiled_return_type"] = DecompileAssistToolSupport.opt(pseudo.returnType)
        } else {
            d["note"] = "no decompilation result cached; variable names may be incomplete"
        }
        return DecompileAssistToolSupport.encode(d)
    }
}

public struct GetTypeInformationTool: DecompileAssistTool {
    public init() {}
    public let id = "get_type_information"
    public let displayName = "Type Information"
    public let description = "Query recovered type information (structures, enums, typedefs) produced by type-recovery analysis. Filter by name substring."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "query": ["type": "string", "description": "Case-insensitive name substring"],
            "kind": ["type": "string", "description": "primitive|pointer|array|structure|union|enumeration|function|typeDef|unknown|backendSpecific"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        var types = await session.types()
        if let q = DecompileAssistToolSupport.string(arguments, "query")?.lowercased(), !q.isEmpty {
            types = types.filter { $0.name.lowercased().contains(q) }
        }
        if let kindRaw = DecompileAssistToolSupport.string(arguments, "kind"),
           let kind = TypeInfo.Kind(rawValue: kindRaw) {
            types = types.filter { $0.kind == kind }
        }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(types.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total": types.count,
            "offset": offset,
            "types": page.map(DecompileAssistToolSupport.typeDict),
        ])
    }
}

public struct SearchBinaryTool: DecompileAssistTool {
    public init() {}
    public let id = "search_binary"
    public let displayName = "Search Binary"
    public let description = "Search raw bytes for a pattern. Accepts a hex string (e.g. '4889e5', spaces optional) or plain text. Scans mapped sections; results are file offsets and virtual addresses. Bounded."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "pattern": ["type": "string", "description": "Hex byte pattern or plain text to find"],
            "max_results": ["type": "integer", "description": "Result cap (default 100, max 1000)"],
        ] as [String: Any],
        "required": ["pattern"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let patternText = DecompileAssistToolSupport.string(arguments, "pattern"), !patternText.isEmpty else {
            return DecompileAssistToolSupport.error("search_binary requires 'pattern'")
        }
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        let pattern = Self.parsePattern(patternText)
        guard !pattern.isEmpty else {
            return DecompileAssistToolSupport.error("pattern produced zero bytes")
        }
        let maxResults = min(1_000, max(1, DecompileAssistToolSupport.int(arguments, "max_results", fallback: 100) ?? 100))
        let patternData = Data(pattern)
        // Bound total bytes scanned.
        let maxScan = 64 * 1024 * 1024
        var scanned = 0
        var results: [[String: Any]] = []
        var truncated = false

        let sections = image.segments.flatMap(\.sections).sorted { $0.address.value < $1.address.value }
        for sec in sections {
            if results.count >= maxResults || scanned >= maxScan { truncated = true; break }
            let remaining = min(Int(sec.size), maxScan - scanned)
            guard remaining > 0 else { continue }
            guard let data = try? image.bytes(virtualAddress: sec.address.value, length: remaining) else { continue }
            scanned += data.count
            var searchFrom = data.startIndex
            while results.count < maxResults,
                  let range = data.range(of: patternData, in: searchFrom..<data.endIndex) {
                let fileOffset = sec.fileOffset + UInt64(range.lowerBound - data.startIndex)
                // Translate file offset back to a virtual address.
                var va: UInt64? = nil
                for seg in image.segments where fileOffset >= seg.fileOffset && fileOffset < seg.fileOffset + seg.fileSize {
                    va = seg.vmAddress + (fileOffset - seg.fileOffset)
                }
                results.append([
                    "file_offset": fileOffset,
                    "virtual_address": DecompileAssistToolSupport.opt(va.map { DecompilerAddress(virtual: $0).hexString }),
                    "section": "\(sec.segment),\(sec.name)",
                ])
                searchFrom = range.upperBound
            }
            if data.range(of: patternData, in: searchFrom..<data.endIndex) != nil { truncated = true }
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "pattern": pattern.map { String(format: "%02x", $0) }.joined(),
            "bytes_scanned": scanned,
            "total_matches": results.count,
            "truncated": truncated,
            "matches": results,
        ])
    }

    /// Interpret the pattern as hex when it looks like hex, else UTF-8 text.
    private static func parsePattern(_ text: String) -> [UInt8] {
        let cleaned = text.replacingOccurrences(of: " ", with: "")
        let isHex = cleaned.count >= 2 && cleaned.count % 2 == 0
            && cleaned.allSatisfy { $0.isHexDigit }
        if isHex, let data = Data(hexString: cleaned) { return [UInt8](data) }
        return [UInt8](text.utf8)
    }
}

public struct NavigateToAddressTool: DecompileAssistTool {
    public init() {}
    public let id = "navigate_to_address"
    public let displayName = "Navigate to Address"
    public let description = "Resolve an address to its containing function/section and return a navigation payload. The UI performs the actual navigation; this tool returns the target metadata."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": ["address": ["type": "string"]] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(arguments, tool: id)
        let store = await session.analysisStore()
        var d: [String: Any] = ["ok": true, "address": addr.hexString]
        if let fn = await store.function(containing: addr.value) {
            d["function"] = DecompileAssistToolSupport.functionDict(fn)
            d["function_entry"] = fn.address.hexString
        }
        if let image = await store.binary {
            for seg in image.segments {
                for sec in seg.sections
                where addr.value >= sec.address.value && addr.value < sec.address.value + sec.size {
                    d["section"] = [
                        "name": sec.name,
                        "segment": seg.name,
                        "address": sec.address.hexString,
                        "is_executable": sec.isExecutable,
                    ]
                }
            }
        }
        if let sym = await store.symbols.first(where: { $0.address?.value == addr.value }) {
            d["symbol"] = DecompileAssistToolSupport.symbolDict(sym)
        }
        if let ins = await store.instruction(at: addr.value) {
            d["instruction"] = DecompileAssistToolSupport.instructionDict(ins)
        }
        return DecompileAssistToolSupport.encode(d)
    }
}

public struct InspectMemoryRegionTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_memory_region"
    public let displayName = "Memory Region"
    public let description = "Inspect the mapped region containing an address: owning segment/section, VM range, protection, and raw bytes (hex dump, bounded)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string"],
            "length": ["type": "integer", "description": "Bytes to dump (default 64, max 4096)"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(arguments, tool: id)
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        var region: [String: Any] = ["ok": true, "address": addr.hexString]
        var found = false
        for seg in image.segments {
            guard addr.value >= seg.vmAddress, addr.value < seg.vmAddress + seg.vmSize else { continue }
            found = true
            region["segment"] = DecompileAssistToolSupport.segmentDict(seg)
            for sec in seg.sections
            where addr.value >= sec.address.value && addr.value < sec.address.value + sec.size {
                region["section"] = DecompileAssistToolSupport.sectionDict(sec)
            }
            break
        }
        guard found else {
            return DecompileAssistToolSupport.error("address \(addr.hexString) is not mapped in any segment")
        }
        let length = min(4_096, max(1, DecompileAssistToolSupport.int(arguments, "length", fallback: 64) ?? 64))
        do {
            let data = try image.bytes(virtualAddress: addr.value, length: length)
            region["bytes_hex"] = data.map { String(format: "%02x", $0) }.joined()
            region["length"] = data.count
            region["file_offset"] = DecompileAssistToolSupport.opt(image.fileOffset(forVirtualAddress: addr.value).map { String(format: "0x%llx", $0) })
        } catch {
            region["bytes_error"] = error.localizedDescription
        }
        return DecompileAssistToolSupport.encode(region)
    }
}

private extension Data {
    init?(hexString: String) {
        var bytes: [UInt8] = []
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self = Data(bytes)
    }
}
