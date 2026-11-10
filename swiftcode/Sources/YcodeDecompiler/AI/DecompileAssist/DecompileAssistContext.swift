import Foundation

/// What part of the analysis the user is currently looking at. All fields are
/// optional; the builder gathers whatever context is available.
public struct DecompileAssistFocus: Sendable {
    /// Virtual address (hex string or plain) of a function entry.
    public var functionAddress: String?
    /// Virtual address of the current cursor / selection.
    public var address: String?
    /// Inclusive instruction range "start-end" (hex strings), or start only.
    public var instructionRange: String?
    /// Free-text query the user typed alongside the context.
    public var query: String?

    public init(functionAddress: String? = nil, address: String? = nil,
                instructionRange: String? = nil, query: String? = nil) {
        self.functionAddress = functionAddress
        self.address = address
        self.instructionRange = instructionRange
        self.query = query
    }
}

/// A bounded, JSON-serializable snapshot of the analysis state sent to the
/// model alongside each user message. Everything here is real store/session
/// data — nothing is fabricated.
public struct DecompileAssistContext: Sendable, Codable {
    public var binaryName: String
    public var format: String
    public var architecture: String
    public var cpuIdentifier: String
    public var fileType: String
    public var sliceIndex: Int
    public var sliceName: String
    public var fileSize: Int64
    public var entryPoint: String?
    public var isEncrypted: Bool
    public var isSigned: Bool
    public var hasDebugInfo: Bool
    public var buildVersion: String?
    public var minOSVersion: String?

    public struct ActiveFunction: Sendable, Codable {
        public var address: String
        public var name: String
        public var size: UInt64
        public var kind: String
        public var provenance: String
        public var pseudocodeExcerpt: String?
    }
    public var activeFunction: ActiveFunction?

    public var activeAddress: String?
    /// Disassembly text for the focused instructions, bounded.
    public var selectedInstructions: String?

    public var analysis: AnalysisSummary
    public var mode: String
    /// User annotations near the focus (address → comment/label), bounded.
    public var annotations: [String: String]

    public struct AnalysisSummary: Sendable, Codable {
        public var stage: String
        public var isAnalyzing: Bool
        public var functionCount: Int
        public var symbolCount: Int
        public var stringCount: Int
        public var xrefCount: Int
        public var typeCount: Int
        public var decompiledCount: Int
        public var instructionCount: Int
        /// Small samples so the model has concrete anchors.
        public var sampleSymbols: [String]
        public var sampleStrings: [String]
        public var sampleXrefs: [String]
    }

    public static func build(session: DecompilerSession, focus: DecompileAssistFocus) async -> DecompileAssistContext {
        let store = await session.analysisStore()
        let image = await store.binary
        let functions = await store.functions
        let symbols = await store.symbols
        let stringsList = await store.stringsList
        let xrefs = await store.crossReferences
        let types = await store.types
        let pseudocode = await store.pseudocode
        let comments = await store.comments
        let labels = await store.userLabels
        let progress = await store.progress
        let isAnalyzing = await session.isAnalyzing
        let mode = await session.mode

        var ctx = DecompileAssistContext(
            binaryName: image?.identity.originalFileName ?? "unknown",
            format: image?.format.displayName ?? "unknown",
            architecture: image?.architecture.displayName ?? "unknown",
            cpuIdentifier: image?.cpuIdentifier ?? "unknown",
            fileType: image?.fileType ?? "unknown",
            sliceIndex: image?.identity.sliceIndex ?? 0,
            sliceName: image?.identity.sliceName ?? "",
            fileSize: image?.identity.fileSize ?? 0,
            entryPoint: image?.entryPoint?.hexString,
            isEncrypted: image?.isEncrypted ?? false,
            isSigned: image?.isSigned ?? false,
            hasDebugInfo: image?.hasDebugInfo ?? false,
            buildVersion: image?.buildVersion,
            minOSVersion: image?.minOSVersion,
            activeFunction: nil,
            activeAddress: nil,
            selectedInstructions: nil,
            analysis: AnalysisSummary(
                stage: progress.stage.rawValue,
                isAnalyzing: isAnalyzing,
                functionCount: functions.count,
                symbolCount: symbols.count,
                stringCount: stringsList.count,
                xrefCount: xrefs.count,
                typeCount: types.count,
                decompiledCount: pseudocode.count,
                instructionCount: await store.instructions.count,
                sampleSymbols: symbols.prefix(10).map(\.effectiveName),
                sampleStrings: stringsList.prefix(10).map(\.text),
                sampleXrefs: xrefs.prefix(10).map {
                    "\($0.source.hexString)->\($0.destination.hexString) (\($0.kind.rawValue))"
                }
            ),
            mode: mode.rawValue,
            annotations: [:]
        )

        // Resolve focus addresses.
        var focusAddress: DecompilerAddress? = nil
        if let raw = focus.address, let parsed = DecompilerAddress.parse(raw) {
            focusAddress = parsed
            ctx.activeAddress = parsed.hexString
        }

        var function: DecompilerFunction? = nil
        if let raw = focus.functionAddress, let parsed = DecompilerAddress.parse(raw) {
            function = await store.function(at: parsed.value)
            if function == nil { function = await store.function(containing: parsed.value) }
        } else if let addr = focusAddress {
            function = await store.function(containing: addr.value)
        }

        if let fn = function {
            var excerpt: String? = nil
            if let result = pseudocode[fn.address.value] {
                excerpt = String(result.pseudocode.prefix(4_000))
            }
            ctx.activeFunction = ActiveFunction(
                address: fn.address.hexString,
                name: fn.displayName,
                size: fn.size,
                kind: fn.kind.rawValue,
                provenance: fn.source.provenance.rawValue,
                pseudocodeExcerpt: excerpt
            )
            ctx.activeAddress = ctx.activeAddress ?? fn.address.hexString
        }

        // Selected instructions within the requested range (bounded).
        if let rangeText = focus.instructionRange {
            let parts = rangeText.split(separator: "-").map { String($0) }
            if let start = DecompilerAddress.parse(parts[0]) {
                let endValue = parts.count > 1
                    ? (DecompilerAddress.parse(parts[1])?.value ?? start.value + 0x400)
                    : start.value + 0x400
                let ins = await store.instructions(inRange: start.value...min(endValue, start.value + 0x2000))
                let lines = ins.prefix(200).map { "\($0.address.hexString): \($0.text)" }
                ctx.selectedInstructions = lines.joined(separator: "\n")
                if ctx.selectedInstructions!.count > 2_000 {
                    ctx.selectedInstructions = String(ctx.selectedInstructions!.prefix(2_000)) + "\n…"
                }
            }
        }

        // Annotations: comments + user labels, bounded to those near focus or first 50.
        var annotations: [String: String] = [:]
        for (addr, text) in comments { annotations["comment@\(addr)"] = text }
        for (addr, name) in labels { annotations["label@\(addr)"] = name }
        if annotations.count > 50 {
            annotations = Dictionary(annotations.sorted { $0.key < $1.key }.prefix(50).map { ($0.key, $0.value) },
                                     uniquingKeysWith: { first, _ in first })
        }
        ctx.annotations = annotations

        return ctx
    }

    /// Serialize the context as a JSON block for the prompt.
    public func jsonBlock() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }
}
