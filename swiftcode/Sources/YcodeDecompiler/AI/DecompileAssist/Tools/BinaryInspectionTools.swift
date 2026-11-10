import Foundation

/// Binary-level inspection tools: metadata, slices, segments, sections,
/// entry point, code signature, entitlements, and dependencies.
/// All data comes from the parsed `BinaryImage` in the session store.

public struct InspectBinaryTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_binary"
    public let displayName = "Inspect Binary"
    public let description = "Return a summary of the loaded binary: identity, format, architecture, entry point, counts of functions/symbols/strings/imports/exports, and security flags."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [:] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded in this session")
        }
        let store = await session.analysisStore()
        let counts = await store.overviewCounts
        let progress = await store.progress
        var d: [String: Any] = [
            "ok": true,
            "name": image.identity.originalFileName,
            "sha256": image.identity.sha256,
            "file_size": image.identity.fileSize,
            "format": image.format.rawValue,
            "format_display": image.format.displayName,
            "architecture": image.architecture.rawValue,
            "architecture_display": image.architecture.displayName,
            "cpu_identifier": image.cpuIdentifier,
            "file_type": image.fileType,
            "slice_index": image.identity.sliceIndex,
            "slice_name": image.identity.sliceName,
            "stable_id": image.identity.stableID,
            "entry_point": DecompileAssistToolSupport.opt(image.entryPoint?.hexString),
            "is_encrypted": image.isEncrypted,
            "is_signed": image.isSigned,
            "has_debug_info": image.hasDebugInfo,
            "build_version": DecompileAssistToolSupport.opt(image.buildVersion),
            "min_os_version": DecompileAssistToolSupport.opt(image.minOSVersion),
            "binary_uuid": DecompileAssistToolSupport.opt(image.identity.binaryUUID),
            "counts": [
                "functions": counts.functions,
                "symbols": counts.symbols,
                "imports": counts.imports,
                "exports": counts.exports,
                "strings": counts.strings,
                "sections": counts.sections,
            ],
            "analysis_stage": progress.stage.rawValue,
            "analysis_message": progress.message,
        ]
        if let cs = image.codeSignatureInfo, !cs.isEmpty { d["code_signature"] = cs }
        if let ent = image.entitlements, !ent.isEmpty { d["entitlements"] = ent }
        return DecompileAssistToolSupport.encode(d)
    }
}

public struct GetBinaryMetadataTool: DecompileAssistTool {
    public init() {}
    public let id = "get_binary_metadata"
    public let displayName = "Binary Metadata"
    public let description = "Detailed binary metadata: identity hash, UUID, versions, flags, and import provenance."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [:] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        let id = image.identity
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "sha256": id.sha256,
            "original_file_name": id.originalFileName,
            "original_location": id.originalLocation,
            "file_size": id.fileSize,
            "format": id.format.rawValue,
            "architecture": id.architecture.rawValue,
            "slice_index": id.sliceIndex,
            "slice_name": id.sliceName,
            "binary_uuid": DecompileAssistToolSupport.opt(id.binaryUUID),
            "imported_at": ISO8601DateFormatter().string(from: id.importedAt),
            "parser_version": id.parserVersion,
            "stable_id": id.stableID,
            "byte_count": image.byteCount,
        ])
    }
}

public struct ListBinaryArchitecturesTool: DecompileAssistTool {
    public init() {}
    public let id = "list_binary_architectures"
    public let displayName = "List Architectures"
    public let description = "List all architecture slices detected in the binary container (for universal/fat binaries) and which slice is active."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [:] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let url = await sessionSourceURL(session) else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        let slices = try await session.availableSlices()
        let active = await session.selectedSliceIndex
        let image = await session.binary()
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "source": url.lastPathComponent,
            "active_slice": active,
            "slices": slices.map {
                [
                    "index": $0.index,
                    "architecture": $0.architecture.rawValue,
                    "architecture_display": $0.architecture.displayName,
                    "cpu_identifier": $0.cpuIdentifier,
                    "name": $0.name,
                    "offset": $0.offset,
                    "size": $0.size,
                ] as [String: Any]
            },
            "active_architecture": DecompileAssistToolSupport.opt(image?.architecture.displayName),
        ])
    }
}

public struct InspectBinarySliceTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_binary_slice"
    public let displayName = "Inspect Slice"
    public let description = "Inspect a specific architecture slice of a universal binary (metadata only; does not switch the active slice)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "slice_index": ["type": "integer", "description": "Slice index (default: active slice)"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let slices = try await session.availableSlices()
        guard !slices.isEmpty else { return DecompileAssistToolSupport.error("no binary loaded") }
        var idx = DecompileAssistToolSupport.int(arguments, "slice_index")
            ?? DecompileAssistToolSupport.int(arguments, "index")
        if idx == nil { idx = await session.selectedSliceIndex }
        guard let idx else { return DecompileAssistToolSupport.error("no slice selected") }
        guard let slice = slices.first(where: { $0.index == idx }) else {
            return DecompileAssistToolSupport.error("no slice with index \(idx); available: \(slices.map(\.index))")
        }
        let active = await session.selectedSliceIndex
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "index": slice.index,
            "architecture": slice.architecture.rawValue,
            "architecture_display": slice.architecture.displayName,
            "cpu_identifier": slice.cpuIdentifier,
            "name": slice.name,
            "offset": slice.offset,
            "size": slice.size,
            "is_active": slice.index == active,
        ])
    }
}

public struct InspectBinarySectionsTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_binary_sections"
    public let displayName = "List Sections"
    public let description = "List sections of the loaded binary with addresses, sizes, flags, and executability. Supports optional segment name filter and pagination."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "segment": ["type": "string", "description": "Optional segment name filter (e.g. __TEXT, .text)"],
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
        var sections = image.segments.flatMap(\.sections)
        if let seg = DecompileAssistToolSupport.string(arguments, "segment") {
            sections = sections.filter {
                $0.segment.localizedCaseInsensitiveContains(seg) || $0.name.localizedCaseInsensitiveContains(seg)
            }
        }
        sections.sort { $0.address.value < $1.address.value }
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments)
        let page = Array(sections.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total": sections.count,
            "offset": offset,
            "returned": page.count,
            "sections": page.map(DecompileAssistToolSupport.sectionDict),
        ])
    }
}

public struct InspectBinarySegmentsTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_binary_segments"
    public let displayName = "List Segments"
    public let description = "List load segments/sections of the loaded binary: VM ranges, file ranges, protections, executability."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "include_sections": ["type": "boolean", "description": "Include per-segment section lists (default false)"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        let includeSections = DecompileAssistToolSupport.bool(arguments, "include_sections")
        let segments = image.segments.map { seg -> [String: Any] in
            var d = DecompileAssistToolSupport.segmentDict(seg)
            if includeSections {
                d["sections"] = seg.sections.map(DecompileAssistToolSupport.sectionDict)
            }
            return d
        }
        return DecompileAssistToolSupport.encode(["ok": true, "segments": segments])
    }
}

public struct GetEntryPointTool: DecompileAssistTool {
    public init() {}
    public let id = "get_entry_point"
    public let displayName = "Entry Point"
    public let description = "Return the binary's entry point address and the function containing it, if known."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [:] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        guard let entry = image.entryPoint else {
            return DecompileAssistToolSupport.error("entry point not recorded for this binary")
        }
        let store = await session.analysisStore()
        var d: [String: Any] = [
            "ok": true,
            "entry_point": entry.hexString,
        ]
        if let fn = await store.function(containing: entry.value) {
            d["function"] = DecompileAssistToolSupport.functionDict(fn)
        }
        // Which section contains it?
        for seg in image.segments {
            for sec in seg.sections where entry.value >= sec.address.value && entry.value < sec.address.value + sec.size {
                d["section"] = "\(seg.name),\(sec.name)"
                d["section_address"] = sec.address.hexString
            }
        }
        return DecompileAssistToolSupport.encode(d)
    }
}

public struct InspectCodeSignatureTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_code_signature"
    public let displayName = "Code Signature"
    public let description = "Return code-signing information recorded during parsing (signature presence, blob summary)."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [:] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "is_signed": image.isSigned,
            "is_encrypted": image.isEncrypted,
            "code_signature": DecompileAssistToolSupport.opt(image.codeSignatureInfo),
            "binary_uuid": DecompileAssistToolSupport.opt(image.identity.binaryUUID),
        ])
    }
}

public struct InspectEntitlementsTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_entitlements"
    public let displayName = "Entitlements"
    public let description = "Return the entitlements property list extracted from the binary's code signature, if present."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [:] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        guard let ent = image.entitlements, !ent.isEmpty else {
            return DecompileAssistToolSupport.encode([
                "ok": true,
                "entitlements": NSNull(),
                "note": "no entitlements recorded for this binary",
            ])
        }
        return DecompileAssistToolSupport.encode(["ok": true, "entitlements": ent])
    }
}

public struct InspectBinaryDependenciesTool: DecompileAssistTool {
    public init() {}
    public let id = "inspect_binary_dependencies"
    public let displayName = "Dependencies"
    public let description = "List the binary's linked libraries/frameworks (load commands / DT_NEEDED / import table) with versions and linkage kind."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
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
        let (offset, limit) = DecompileAssistToolSupport.pagination(arguments, defaultLimit: 200)
        let page = Array(image.dependencies.dropFirst(offset).prefix(limit))
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "total": image.dependencies.count,
            "offset": offset,
            "dependencies": page.map {
                [
                    "path": $0.path,
                    "kind": $0.kind,
                    "current_version": DecompileAssistToolSupport.opt($0.currentVersion),
                    "compatibility_version": DecompileAssistToolSupport.opt($0.compatibilityVersion),
                ] as [String: Any]
            },
        ])
    }
}

/// Shared helper: the session's source file URL (internal to this module).
func sessionSourceURL(_ session: DecompilerSession) async -> URL? {
    // DecompilerSession keeps sourceURL private; recover it via availableSlices
    // fallback — but the public surface exposes it only indirectly. Use the
    // store's binary identity location instead.
    if let image = await session.binary() {
        let loc = image.identity.originalLocation
        if !loc.isEmpty { return URL(fileURLWithPath: loc) }
    }
    return nil
}
