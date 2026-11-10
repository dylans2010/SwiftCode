import Foundation

/// String tools: search the extracted string table, inspect individual
/// strings, find code that references them, and read surrounding context.

public struct SearchStringsTool: DecompileAssistTool {
    public init() {}
    public let id = "search_strings"
    public let displayName = "Search Strings"
    public let description = "Search extracted strings by substring (case-insensitive). Paginated."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "query": ["type": "string", "description": "Substring to search for"],
            "referenced_only": ["type": "boolean", "description": "Only strings known to be referenced by code"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        var strings = await session.strings()
        if DecompileAssistToolSupport.bool(arguments, "referenced_only") {
            strings = strings.filter(\.isReferenced)
        }
        if let q = DecompileAssistToolSupport.string(arguments, "query")?.lowercased(), !q.isEmpty {
            strings = strings.filter { $0.text.lowercased().contains(q) }
        }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(strings.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total": strings.count,
            "offset": offset,
            "strings": page.map(DecompileAssistToolSupport.stringDict),
        ])
    }
}

public struct InspectStringTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_string"
    public let displayName = "Inspect String"
    public let description = "Return details for the string at a given virtual address (or containing a file offset)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "Virtual address of the string (0x…)"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(arguments, tool: id)
        let strings = await session.strings()
        guard let s = strings.first(where: { $0.address == addr })
            ?? strings.first(where: {
                $0.address.value <= addr.value && addr.value < $0.address.value + UInt64($0.text.utf8.count + 1)
            }) else {
            return DecompileAssistToolSupport.error("no extracted string at \(addr.hexString)")
        }
        var d = DecompileAssistToolSupport.stringDict(s)
        d["ok"] = true
        // Which function references it?
        let store = await session.analysisStore()
        let xrefs = await store.crossReferences.filter {
            $0.destination == s.address || $0.destination.value == s.address.value
        }
        if !xrefs.isEmpty {
            d["referencing_xrefs"] = xrefs.prefix(20).map(DecompileAssistToolSupport.xrefDict)
        }
        return DecompileAssistToolSupport.encode(d)
    }
}

public struct InspectStringReferencesTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_string_references"
    public let displayName = "String References"
    public let description = "List code locations (xrefs) that reference a string address — typically adrp/add pairs on ARM64 or RIP-relative loads on x86_64."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "String virtual address"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(arguments, tool: id)
        let store = await session.analysisStore()
        let xrefs = await store.crossReferences.filter {
            $0.destination == addr || $0.destination.value == addr.value
        }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(xrefs.dropFirst(offset).prefix(limit))
        var entries: [[String: Any]] = []
        for x in page {
            var d = DecompileAssistToolSupport.xrefDict(x)
            if let sf = x.sourceFunction,
               let fn = await store.function(at: sf.value) {
                d["source_function_name"] = fn.displayName
            }
            entries.append(d)
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "address": addr.hexString,
            "total": xrefs.count,
            "references": entries,
        ])
    }
}

public struct GetStringContextTool: DecompileAssistTool {
    public init() {}
    public let id = "get_string_context"
    public let displayName = "String Context"
    public let description = "Return neighboring strings and the referencing functions around a string address — useful for understanding what a string is used for."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string"],
            "window": ["type": "integer", "description": "Number of neighboring strings before/after (default 5, max 50)"],
        ] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(arguments, tool: id)
        let strings = await session.strings()
        guard let index = strings.firstIndex(where: { $0.address == addr }) else {
            // Fall back: nearest preceding string.
            guard let nearest = strings.last(where: { $0.address.value <= addr.value }) else {
                return DecompileAssistToolSupport.error("no strings near \(addr.hexString)")
            }
            return try await context(for: nearest, strings: strings, session: session,
                                     arguments: arguments, fallbackAddress: addr)
        }
        return try await context(for: strings[index], strings: strings, session: session,
                                 arguments: arguments, fallbackAddress: nil)
    }

    private func context(for s: BinaryString, strings: [BinaryString],
                         session: DecompilerSession, arguments: [String: Any],
                         fallbackAddress: DecompilerAddress?) async throws -> String {
        let window = min(50, max(0, DecompileAssistToolSupport.int(arguments, "window", fallback: 5) ?? 5))
        guard let idx = strings.firstIndex(where: { $0.address == s.address }) else {
            return DecompileAssistToolSupport.error("string vanished")
        }
        let lo = max(0, idx - window)
        let hi = min(strings.count, idx + window + 1)
        let neighbors = strings[lo..<hi].map(DecompileAssistToolSupport.stringDict)

        let store = await session.analysisStore()
        let xrefs = await store.crossReferences.filter {
            $0.destination == s.address || $0.destination.value == s.address.value
        }
        var referencingFunctions: [[String: Any]] = []
        var seen = Set<UInt64>()
        for x in xrefs {
            if let sf = x.sourceFunction, seen.insert(sf.value).inserted,
               let fn = await store.function(at: sf.value) {
                referencingFunctions.append(DecompileAssistToolSupport.functionDict(fn))
                if referencingFunctions.count >= 20 { break }
            }
        }

        var d: [String: Any] = [
            "ok": true,
            "string": DecompileAssistToolSupport.stringDict(s),
            "neighbor_strings": neighbors,
            "referencing_functions": referencingFunctions,
        ]
        if let fb = fallbackAddress { d["queried_address"] = fb.hexString }
        return DecompileAssistToolSupport.encode(d)
    }
}
