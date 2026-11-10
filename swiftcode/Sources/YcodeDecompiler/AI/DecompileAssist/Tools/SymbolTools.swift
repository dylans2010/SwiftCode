import Foundation

/// Symbol tools: search, inspect, demangle (via the Swift demangler
/// subprocess when available), imports, exports.

public struct SearchSymbolsTool: DecompileAssistTool {
    public init() {}
    public let id = "search_symbols"
    public let displayName = "Search Symbols"
    public let description = "Search the symbol table by name substring (matches original, demangled, and user-assigned names). Paginated."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "query": ["type": "string", "description": "Substring to search for"],
            "kind": ["type": "string", "description": "Symbol kind filter: local, global, external, undefined, absolute, common"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        var symbols = await session.symbols()
        if let q = DecompileAssistToolSupport.string(arguments, "query")?.lowercased(), !q.isEmpty {
            symbols = symbols.filter {
                $0.name.lowercased().contains(q)
                    || ($0.demangledName ?? "").lowercased().contains(q)
                    || ($0.effectiveName.lowercased().contains(q))
            }
        }
        if let kindRaw = DecompileAssistToolSupport.string(arguments, "kind"),
           let kind = BinarySymbol.Kind(rawValue: kindRaw) {
            symbols = symbols.filter { $0.kind == kind }
        }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(symbols.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total": symbols.count,
            "offset": offset,
            "symbols": page.map(DecompileAssistToolSupport.symbolDict),
        ])
    }
}

public struct InspectSymbolTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_symbol"
    public let displayName = "Inspect Symbol"
    public let description = "Return details for a symbol by name or address, including provenance and any function at its address."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "name": ["type": "string", "description": "Symbol name (original, demangled, or user name)"],
            "address": ["type": "string", "description": "Symbol address (0x…)"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let store = await session.analysisStore()
        var symbol: BinarySymbol? = nil
        if let addr = DecompileAssistToolSupport.address(arguments, keys: ["address"]) {
            symbol = await store.symbols.first { $0.address?.value == addr.value }
        }
        if symbol == nil, let name = DecompileAssistToolSupport.string(arguments, "name") {
            symbol = await store.symbols.first {
                $0.name == name || $0.effectiveName == name || $0.demangledName == name
            }
            // Case-insensitive fallback.
            if symbol == nil {
                symbol = await store.symbols.first {
                    $0.name.caseInsensitiveCompare(name) == .orderedSame
                        || $0.effectiveName.caseInsensitiveCompare(name) == .orderedSame
                }
            }
        }
        guard let s = symbol else {
            return DecompileAssistToolSupport.error("symbol not found")
        }
        var d = DecompileAssistToolSupport.symbolDict(s)
        d["ok"] = true
        if let addr = s.address,
           let fn = await store.function(atOrContaining: addr.value) {
            d["function"] = DecompileAssistToolSupport.functionDict(fn)
        }
        if let addr = s.address {
            let xrefs = await store.crossReferences.filter {
                $0.destination == addr || $0.source == addr
            }
            if !xrefs.isEmpty { d["xref_count"] = xrefs.count }
        }
        return DecompileAssistToolSupport.encode(d)
    }
}

public struct DemangleSymbolTool: DecompileAssistTool {
    public init() {}
    public let id = "demangle_symbol"
    public let displayName = "Demangle Symbol"
    public let description = "Demangle a symbol name. Uses the stored demangled name when present; otherwise runs the module's SymbolDemangler (Swift via xcrun swift-demangle, C++ via c++filt, Mach-O underscore stripping)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "name": ["type": "string", "description": "Mangled symbol name"],
            "symbol_address": ["type": "string", "description": "Optional address to look the symbol up first"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        var name = DecompileAssistToolSupport.string(arguments, "name")
        var storedDemangled: String? = nil

        // Resolve via store when only an address or a lookup is possible.
        let store = await session.analysisStore()
        if name == nil, let addr = DecompileAssistToolSupport.address(arguments, keys: ["symbol_address", "address"]) {
            if let s = await store.symbols.first(where: { $0.address?.value == addr.value }) {
                name = s.name
                storedDemangled = s.demangledName
            }
        }
        if let lookup = name, storedDemangled == nil {
            if let s = await store.symbols.first(where: {
                $0.name == lookup || $0.effectiveName == lookup || $0.demangledName == lookup
            }), let dm = s.demangledName {
                storedDemangled = dm
            }
        }
        guard let mangled = name, !mangled.isEmpty else {
            return DecompileAssistToolSupport.error("demangle_symbol requires a 'name' argument or a resolvable symbol_address")
        }

        if let stored = storedDemangled, !stored.isEmpty {
            return DecompileAssistToolSupport.encode([
                "ok": true, "mangled": mangled, "demangled": stored,
                "method": "symbol_table",
            ])
        }

        // Use the module's demangler: Swift ($s…) via `xcrun swift-demangle`,
        // Itanium C++ (_Z…) via `c++filt`, Mach-O underscore stripping, and a
        // raw-name fallback.
        let demangled = await Task.detached(priority: .userInitiated) {
            SymbolDemangler.demangle(mangled)
        }.value
        let changed = demangled != mangled && demangled != String(mangled.dropFirst())
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "mangled": mangled,
            "demangled": DecompileAssistToolSupport.opt(changed ? demangled : nil),
            "effective_name": demangled,
            "method": changed ? "symbol_demangler" : "passthrough",
            "note": DecompileAssistToolSupport.opt(changed ? nil : "name is not a recognized mangled symbol; returned unchanged"),
        ])
    }
}

public struct ListImportsTool: DecompileAssistTool {
    public init() {}
    public let id = "list_imports"
    public let displayName = "List Imports"
    public let description = "List imported symbols/libraries the binary depends on."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "query": ["type": "string", "description": "Optional substring filter on import name or library"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        var imports = image.imports
        if let q = DecompileAssistToolSupport.string(arguments, "query")?.lowercased(), !q.isEmpty {
            imports = imports.filter {
                $0.name.lowercased().contains(q) || $0.library.lowercased().contains(q)
            }
        }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(imports.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total": imports.count,
            "offset": offset,
            "imports": page.map {
                [
                    "name": $0.name,
                    "library": $0.library,
                    "address": DecompileAssistToolSupport.opt($0.address?.hexString),
                    "is_weak": $0.isWeak,
                ] as [String: Any]
            },
        ])
    }
}

public struct ListExportsTool: DecompileAssistTool {
    public init() {}
    public let id = "list_exports"
    public let displayName = "List Exports"
    public let description = "List symbols the binary exports (entry points other modules can call)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "query": ["type": "string"],
            "offset": ["type": "integer"],
            "limit": ["type": "integer"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        var exports = image.exports
        if let q = DecompileAssistToolSupport.string(arguments, "query")?.lowercased(), !q.isEmpty {
            exports = exports.filter { $0.name.lowercased().contains(q) }
        }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(exports.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total": exports.count,
            "offset": offset,
            "exports": page.map {
                [
                    "name": $0.name,
                    "address": $0.address.hexString,
                    "kind": $0.kind.rawValue,
                ] as [String: Any]
            },
        ])
    }
}

public struct InspectImportTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_import"
    public let displayName = "Inspect Import"
    public let description = "Return details for a single imported symbol by name."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": ["name": ["type": "string"]] as [String: Any],
        "required": ["name"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        guard let name = DecompileAssistToolSupport.string(arguments, "name") else {
            return DecompileAssistToolSupport.error("inspect_import requires 'name'")
        }
        guard let imp = image.imports.first(where: {
            $0.name == name || $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) else {
            return DecompileAssistToolSupport.error("import '\(name)' not found")
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "name": imp.name,
            "library": imp.library,
            "address": DecompileAssistToolSupport.opt(imp.address?.hexString),
            "is_weak": imp.isWeak,
        ])
    }
}

public struct InspectExportTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_export"
    public let displayName = "Inspect Export"
    public let description = "Return details for a single exported symbol by name, including the function at its address when known."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": ["name": ["type": "string"]] as [String: Any],
        "required": ["name"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        guard let name = DecompileAssistToolSupport.string(arguments, "name") else {
            return DecompileAssistToolSupport.error("inspect_export requires 'name'")
        }
        guard let exp = image.exports.first(where: {
            $0.name == name || $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) else {
            return DecompileAssistToolSupport.error("export '\(name)' not found")
        }
        let store = await session.analysisStore()
        var d: [String: Any] = [
            "ok": true,
            "name": exp.name,
            "address": exp.address.hexString,
            "kind": exp.kind.rawValue,
        ]
        if let fn = await store.function(atOrContaining: exp.address.value) {
            d["function"] = DecompileAssistToolSupport.functionDict(fn)
        }
        return DecompileAssistToolSupport.encode(d)
    }
}
