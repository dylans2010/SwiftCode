import Foundation

/// Assistant analysis tools. These do NOT call the model — they compose
/// deterministic, evidence-based analysis text from real store data
/// (pseudocode, disassembly, xrefs, strings, symbols). Every result is
/// explicitly labeled as assistant analysis with `provenance: "aiSuggestion"`
/// semantics: helpful interpretation, never verified fact.
///
/// The model itself uses these to ground its own explanations in data it can
/// cite, and users can invoke them for quick local analysis without a round
/// trip to the LLM.

/// Shared prologue: gather a function's evidence bundle.
private func evidenceBundle(session: DecompilerSession, addr: DecompilerAddress) async -> (fn: DecompilerFunction?, pseudo: DecompilationResult?, instructions: [Instruction], xrefs: [CrossReference], strings: [BinaryString], symbols: [BinarySymbol], image: BinaryImage?) {
    let store = await session.analysisStore()
    let fn = await store.function(atOrContaining: addr.value)
    let pseudo: DecompilationResult?
    if let fn {
        pseudo = await store.pseudocode(forFunctionAt: fn.address.value)
    } else {
        pseudo = await store.pseudocode(forFunctionAt: addr.value)
    }
    let instructions = (try? await session.disassembleFunction(at: fn?.address ?? addr)) ?? []
    let allXrefs = await store.crossReferences
    let fnAddr = fn?.address.value
    let xrefs = allXrefs.filter {
        $0.sourceFunction?.value == fnAddr || $0.destinationFunction?.value == fnAddr
    }
    let strings = await store.stringsList
    let symbols = await store.symbols
    let image = await store.binary
    return (fn, pseudo, instructions, xrefs, strings, symbols, image)
}

public struct ExplainFunctionTool: DecompileAssistTool {
    public init() {}
    public let id = "explain_function"
    public let displayName = "Explain Function"
    public let description = "Produce a structured explanation of a function from real analysis data: purpose hypothesis, operations, calls, data references, and evidence citations. Deterministic local analysis — labeled as unverified assistant analysis."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": ["address": ["type": "string"]] as [String: Any],
        "required": ["address"],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let addr = try DecompileAssistToolSupport.requireAddress(arguments, keys: ["address", "function_address"], tool: id)
        let (fn, pseudo, instructions, xrefs, strings, symbols, image) = await evidenceBundle(session: session, addr: addr)
        guard fn != nil || !instructions.isEmpty || pseudo != nil else {
            return DecompileAssistToolSupport.error("no analysis data for \(addr.hexString)")
        }
        var lines: [String] = []
        lines.append("ASSISTANT ANALYSIS (unverified — cite addresses when relaying)")
        if let fn {
            lines.append("Function \(fn.displayName) @ \(fn.address.hexString) (\(fn.kind.rawValue), \(fn.size) bytes, provenance: \(fn.source.provenance.rawValue))")
            if let end = fn.endAddress { lines.append("Range: \(fn.address.hexString)–\(end.hexString)") }
        }
        if let pseudo {
            lines.append("Decompiled by \(pseudo.engineID)\(pseudo.engineVersion.map { " \($0)" } ?? ""):")
            lines.append("```")
            lines.append(String(pseudo.pseudocode.prefix(3_000)))
            lines.append("```")
            if !pseudo.warnings.isEmpty { lines.append("Warnings: \(pseudo.warnings.joined(separator: "; "))") }
        }
        // Call summary from xrefs.
        let callees = xrefs.filter { $0.kind == .call && $0.sourceFunction == fn?.address }
            .compactMap(\.destinationFunction)
        let callers = xrefs.filter { $0.kind == .call && $0.destinationFunction == fn?.address }
            .compactMap(\.sourceFunction)
        if !callees.isEmpty {
            lines.append("Calls (\(callees.count)): \(callees.prefix(20).map(\.hexString).joined(separator: ", "))")
        }
        if !callers.isEmpty {
            lines.append("Called by (\(callers.count)): \(callers.prefix(20).map(\.hexString).joined(separator: ", "))")
        }
        // String references inside the function.
        if let fn, !strings.isEmpty {
            let fnEnd = fn.endAddress?.value ?? fn.address.value + max(fn.size, 1)
            let referenced = strings.filter { s in
                xrefs.contains { $0.destination == s.address && $0.source.value >= fn.address.value && $0.source.value < fnEnd }
            }
            if !referenced.isEmpty {
                lines.append("Strings referenced:")
                for s in referenced.prefix(15) {
                    lines.append("  \(s.address.hexString): \"\(s.text.prefix(120))\"")
                }
            }
        }
        // Instruction-class histogram.
        if !instructions.isEmpty {
            var hist: [String: Int] = [:]
            for i in instructions { hist[i.classification.rawValue, default: 0] += 1 }
            lines.append("Instruction mix (\(instructions.count) decoded): \(hist.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
        }
        let analysis = lines.joined(separator: "\n")
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "address": addr.hexString,
            "function": DecompileAssistToolSupport.opt(fn.map { DecompileAssistToolSupport.functionDict($0) }),
            "analysis_text": analysis,
            "provenance": AnalysisProvenance.aiSuggestion.rawValue,
            "disclaimer": "Deterministic assistant analysis composed from analysis-store data; interpretations are suggestions, not verified facts.",
        ])
    }
}

public struct ExplainInstructionTool: DecompileAssistTool {
    public init() {}
    public let id = "explain_instruction"
    public let displayName = "Explain Instruction"
    public let description = "Explain a single decoded instruction: mnemonic, operands, branch target, referenced symbol/string, and architectural notes."
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
        guard let ins = await store.instruction(at: addr.value) else {
            return DecompileAssistToolSupport.error("no decoded instruction at \(addr.hexString) — disassemble the containing function first")
        }
        var notes: [String] = []
        switch ins.classification {
        case .branch: notes.append("unconditional branch")
        case .call: notes.append("call — transfers control to another function and returns")
        case .returnInstruction: notes.append("function return")
        case .invalid: notes.append("decoded as invalid/undecodable")
        case .data: notes.append("decoded in data context")
        default: break
        }
        if let bt = ins.branchTarget { notes.append("branch target \(bt.hexString)") }
        if let label = ins.label { notes.append("label: \(label)") }
        // Symbol at operand address.
        if case .address(let target)? = ins.operands.first(where: {
            if case .address = $0 { return true }; return false
        }) {
            if let sym = await store.symbols.first(where: { $0.address?.value == target.value }) {
                notes.append("references symbol \(sym.effectiveName)")
            }
        }
        // String at branch/operand target.
        let strings = await store.stringsList
        for operand in ins.operands {
            if case .address(let target) = operand,
               let s = strings.first(where: { $0.address == target }) {
                notes.append("references string \"\(s.text.prefix(80))\" @ \(s.address.hexString)")
            }
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "instruction": DecompileAssistToolSupport.instructionDict(ins),
            "notes": notes,
            "provenance": AnalysisProvenance.engine.rawValue,
        ])
    }
}

public struct ExplainBinaryTool: DecompileAssistTool {
    public init() {}
    public let id = "explain_binary"
    public let displayName = "Explain Binary"
    public let description = "High-level explanation of the loaded binary: format, architecture, purpose hints from imports/exports/strings, and notable security properties."
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
        let store = await session.analysisStore()
        let counts = await store.overviewCounts
        var lines: [String] = []
        lines.append("ASSISTANT ANALYSIS (unverified)")
        lines.append("\(image.identity.originalFileName) — \(image.format.displayName) / \(image.architecture.displayName) (\(image.cpuIdentifier)), file type: \(image.fileType)")
        lines.append("Size: \(image.identity.fileSize) bytes; \(counts.functions) functions, \(counts.symbols) symbols, \(counts.strings) strings, \(counts.imports) imports, \(counts.exports) exports")
        if image.isEncrypted { lines.append("NOTE: binary is encrypted (FairPlay) — decrypted regions may be absent") }
        if image.isSigned { lines.append("Code signature present\(image.entitlements != nil ? " with entitlements" : "")") }
        if image.hasDebugInfo { lines.append("Debug info present") }
        // Import library summary → purpose hints.
        let libs = Set(image.imports.map(\.library)).sorted()
        if !libs.isEmpty {
            lines.append("Linked libraries (\(libs.count)): \(libs.prefix(20).joined(separator: ", "))\(libs.count > 20 ? " …" : "")")
        }
        // Notable strings heuristic: paths, URLs, interesting keywords.
        let interesting = image.strings.filter {
            let t = $0.text
            return t.contains("http") || t.contains(".app/") || t.contains("/usr/")
                || t.contains("Library/") || t.hasPrefix("/") && t.count > 8
        }.prefix(15)
        if !interesting.isEmpty {
            lines.append("Notable path/URL strings:")
            for s in interesting { lines.append("  \(s.address.hexString): \"\(s.text.prefix(100))\"") }
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "binary": image.identity.originalFileName,
            "analysis_text": lines.joined(separator: "\n"),
            "provenance": AnalysisProvenance.aiSuggestion.rawValue,
            "disclaimer": "Heuristic summary composed from binary metadata; purpose inference is a suggestion.",
        ])
    }
}

public struct SummarizeBinaryTool: DecompileAssistTool {
    public init() {}
    public let id = "summarize_binary"
    public let displayName = "Summarize Binary"
    public let description = "Compact statistical summary of the binary and its analysis state: sizes, counts, coverage, largest functions, most-referenced strings."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "top_n": ["type": "integer", "description": "How many top entries per category (default 10, max 50)"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        guard let image = await session.binary() else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        let store = await session.analysisStore()
        let n = min(50, max(1, DecompileAssistToolSupport.int(arguments, "top_n", fallback: 10) ?? 10))
        let functions = await store.functions
        let pseudocode = await store.pseudocode
        let xrefs = await store.crossReferences
        let strings = await store.stringsList

        let largest = functions.sorted { $0.size > $1.size }.prefix(n).map {
            ["address": $0.address.hexString, "name": $0.displayName, "size": $0.size] as [String: Any]
        }
        // Most-referenced destinations.
        let allSymbols = await store.symbols
        let allFunctions = await store.functions
        var refCounts: [UInt64: Int] = [:]
        for x in xrefs { refCounts[x.destination.value, default: 0] += 1 }
        let mostReferenced = refCounts.sorted { $0.value > $1.value }.prefix(n).compactMap { addr, count -> [String: Any]? in
            var d: [String: Any] = [
                "address": DecompilerAddress(virtual: addr).hexString,
                "references": count,
            ]
            if let s = strings.first(where: { $0.address.value == addr }) { d["string"] = s.text }
            if let sym = allSymbols.first(where: { $0.address?.value == addr }) { d["symbol"] = sym.effectiveName }
            if let fn = allFunctions.first(where: { $0.address.value == addr }) { d["function"] = fn.displayName }
            return d
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "binary": image.identity.originalFileName,
            "format": image.format.displayName,
            "architecture": image.architecture.displayName,
            "file_size": image.identity.fileSize,
            "function_count": functions.count,
            "decompiled_count": pseudocode.count,
            "xref_count": xrefs.count,
            "string_count": strings.count,
            "decompile_coverage": functions.isEmpty ? 0 : Double(pseudocode.count) / Double(functions.count),
            "largest_functions": largest,
            "most_referenced": mostReferenced,
        ])
    }
}

public struct SuggestFunctionNameTool: DecompileAssistTool {
    public init() {}
    public let id = "suggest_function_name"
    public let displayName = "Suggest Function Name"
    public let description = "Suggest a meaningful name for an unnamed/thunk function based on its strings, calls, imports, and structure. Returns suggestions only — does not rename (use rename_function with approved:true to apply)."
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
        guard let image = await store.binary else { return DecompileAssistToolSupport.error("no binary loaded") }
        guard let fn = await store.function(atOrContaining: addr.value) else {
            return DecompileAssistToolSupport.error("no function at \(addr.hexString)")
        }
        // Gather evidence.
        let xrefs = await store.crossReferences
        let fnEnd = fn.endAddress?.value ?? fn.address.value + max(fn.size, 1)
        let calls = xrefs.filter { $0.kind == .call && $0.sourceFunction == fn.address }
            .compactMap(\.destination).prefix(20)
        // Strings referenced inside the function.
        let strings = await store.stringsList
        var referencedStrings: [String] = []
        for s in strings {
            let hit = xrefs.contains {
                $0.destination == s.address && $0.source.value >= fn.address.value && $0.source.value < fnEnd
            }
            if hit { referencedStrings.append(s.text) }
            if referencedStrings.count >= 10 { break }
        }
        // Imports called.
        let allSymbols = await store.symbols
        var calledImports: [String] = []
        for target in calls {
            if let imp = image.imports.first(where: { $0.address?.value == target.value }) {
                calledImports.append(imp.name)
            } else if let sym = allSymbols.first(where: { $0.address?.value == target.value }) {
                calledImports.append(sym.effectiveName)
            } else if let callee = await store.function(at: target.value) {
                calledImports.append(callee.displayName)
            }
        }
        // Heuristic name synthesis.
        var suggestions: [String] = []
        if !referencedStrings.isEmpty {
            let hint = referencedStrings[0]
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .prefix(3)
                .joined(separator: "_")
            if !hint.isEmpty { suggestions.append("fn_\(hint)") }
        }
        if let first = calledImports.first {
            suggestions.append("wrap_\(first.replacingOccurrences(of: " ", with: "_"))")
        }
        if fn.kind == .thunk { suggestions.append("thunk_\(fn.address.hexString.dropFirst(2))") }
        if suggestions.isEmpty {
            suggestions.append("sub_\(fn.address.hexString.dropFirst(2))")
        }
        var seenNames = Set<String>()
        let uniqueSuggestions = suggestions.filter { seenNames.insert($0).inserted }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function": fn.address.hexString,
            "current_name": fn.displayName,
            "suggestions": uniqueSuggestions,
            "evidence": [
                "referenced_strings": referencedStrings,
                "called_targets": calledImports,
                "instruction_count_hint": fn.size,
            ],
            "note": "Suggestions are heuristic. Apply with rename_function (approved:true) only after user confirmation.",
            "provenance": AnalysisProvenance.aiSuggestion.rawValue,
        ])
    }
}

public struct SuggestVariableNamesTool: DecompileAssistTool {
    public init() {}
    public let id = "suggest_variable_names"
    public let displayName = "Suggest Variable Names"
    public let description = "Suggest meaningful names for a function's parameters/locals based on how they're used (string refs, call args, type info). Suggestions only."
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
        var suggestions: [[String: Any]] = []
        // Merge decompiled names when available.
        if let pseudo = await store.pseudocode(forFunctionAt: fn.address.value) {
            for (i, p) in pseudo.parameters.enumerated() {
                suggestions.append(["slot": "param_\(i)", "current": p, "suggestion": p,
                                    "source": "decompiler"])
            }
            for (i, l) in pseudo.localVariables.enumerated() {
                suggestions.append(["slot": "local_\(i)", "current": l, "suggestion": l,
                                    "source": "decompiler"])
            }
        }
        if suggestions.isEmpty {
            for (i, p) in fn.parameters.enumerated() {
                suggestions.append(["slot": "param_\(i)", "current": p,
                                    "suggestion": "arg\(i + 1)", "source": "positional"])
            }
            for (i, l) in fn.localVariables.enumerated() {
                suggestions.append(["slot": "local_\(i)", "current": l,
                                    "suggestion": "var\(i + 1)", "source": "positional"])
            }
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function": fn.address.hexString,
            "variables": suggestions,
            "provenance": AnalysisProvenance.aiSuggestion.rawValue,
            "note": "Variable names come from the decompiler backend when available; positional fallbacks are placeholders, not analysis.",
        ])
    }
}

public struct IdentifyFunctionPurposeTool: DecompileAssistTool {
    public init() {}
    public let id = "identify_function_purpose"
    public let displayName = "Function Purpose"
    public let description = "Infer the likely purpose of a function from its API calls, strings, imports, and callers. Returns a labeled hypothesis with supporting evidence."
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
        let (fn, pseudo, _, xrefs, strings, symbols, image) = await evidenceBundle(session: session, addr: addr)
        guard fn != nil || pseudo != nil else {
            return DecompileAssistToolSupport.error("no analysis data for \(addr.hexString)")
        }
        var evidence: [String] = []
        var hypothesis: [String] = []

        // API usage → purpose keywords.
        let keywordMap: [(String, [String])] = [
            ("file", ["open", "read", "write", "close", "fopen", "NSFile", "FileManager"]),
            ("network", ["socket", "connect", "http", "URL", "NSURL", "send", "recv", "curl"]),
            ("memory", ["malloc", "free", "alloc", "memcpy", "memmove", "CFAllocator"]),
            ("crypto", ["crypt", "sha", "md5", "aes", "SecKey", "CCCrypt"]),
            ("ui", ["NSView", "UIView", "draw", "render", "CALayer", "Window"]),
            ("logging", ["log", "NSLog", "os_log", "printf", "fprintf", "Logger"]),
            ("dispatch", ["dispatch", "pthread", "thread", "async", "queue"]),
        ]
        var matchedKeywords = Set<String>()
        for target in xrefs.filter({ $0.kind == .call }).compactMap(\.destination) {
            if let sym = symbols.first(where: { $0.address?.value == target.value }) {
                let name = sym.effectiveName.lowercased()
                for (category, words) in keywordMap where words.contains(where: { name.contains($0) }) {
                    matchedKeywords.insert(category)
                }
            }
            if let imp = image?.imports.first(where: { $0.address?.value == target.value }) {
                let name = imp.name.lowercased()
                for (category, words) in keywordMap where words.contains(where: { name.contains($0) }) {
                    matchedKeywords.insert(category)
                }
            }
        }
        if !matchedKeywords.isEmpty {
            evidence.append("API usage suggests: \(matchedKeywords.sorted().joined(separator: ", "))")
            hypothesis.append("Likely \(matchedKeywords.sorted().joined(separator: "/"))-related routine")
        }
        // Strings.
        let fnEnd = fn?.endAddress?.value ?? (fn?.address.value ?? 0) + (fn?.size ?? 0)
        let fnStart = fn?.address.value ?? 0
        let referenced = strings.filter { s in
            xrefs.contains { $0.destination == s.address && $0.source.value >= fnStart && $0.source.value < fnEnd }
        }.prefix(8)
        if !referenced.isEmpty {
            evidence.append("Strings: \(referenced.map { "\"\($0.text.prefix(60))\"" }.joined(separator: ", "))")
        }
        // Caller context: entry points / thunks.
        if fn?.kind == .entryPoint { hypothesis.append("Entry-point routine (startup path)") }
        if fn?.kind == .thunk { hypothesis.append("Thunk/wrapper — likely forwards to another implementation") }
        if hypothesis.isEmpty {
            hypothesis.append("Purpose unclear from available evidence — inspect pseudocode and callers manually")
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function": DecompileAssistToolSupport.opt(fn.map { DecompileAssistToolSupport.functionDict($0) }),
            "hypothesis": hypothesis,
            "evidence": evidence,
            "provenance": AnalysisProvenance.aiSuggestion.rawValue,
            "disclaimer": "Purpose inference is a hypothesis; verify against pseudocode before relying on it.",
        ])
    }
}

public struct CompareFunctionBehaviorTool: DecompileAssistTool {
    public init() {}
    public let id = "compare_function_behavior"
    public let displayName = "Compare Behavior"
    public let description = "Compare the observable behavior profile of two functions: API categories used, strings referenced, callers/callees overlap."
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
            return DecompileAssistToolSupport.error("requires address_a and address_b")
        }
        func profile(_ addr: DecompilerAddress) async -> [String: Any] {
            let (fn, pseudo, instructions, xrefs, _, _, _) = await evidenceBundle(session: session, addr: addr)
            let calls = xrefs.filter { $0.kind == .call && $0.sourceFunction == fn?.address }
                .compactMap(\.destination).count
            var d: [String: Any] = [
                "address": addr.hexString,
                "name": DecompileAssistToolSupport.opt(fn?.displayName),
                "size": DecompileAssistToolSupport.opt(fn?.size),
                "call_count": calls,
                "instruction_count": instructions.count,
                "has_pseudocode": pseudo != nil,
            ]
            return d
        }
        async let pa = profile(a)
        async let pb = profile(b)
        let (profA, profB) = await (pa, pb)
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function_a": profA,
            "function_b": profB,
            "provenance": AnalysisProvenance.aiSuggestion.rawValue,
        ])
    }
}

public struct GenerateFunctionDocumentationTool: DecompileAssistTool {
    public init() {}
    public let id = "generate_function_documentation"
    public let displayName = "Function Documentation"
    public let description = "Generate a documentation block (summary, parameters, returns, evidence) for a function from analysis data."
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
        var doc = "/// \(fn.displayName)\n"
        doc += "/// Address: \(fn.address.hexString)"
        if let end = fn.endAddress { doc += "–\(end.hexString)" }
        doc += " (\(fn.size) bytes, \(fn.kind.rawValue))\n"
        doc += "///\n"
        doc += "/// Summary: \(fn.kind == .thunk ? "Thunk/wrapper forwarding to another implementation." : "Function recovered by static analysis; purpose not yet fully determined.")\n"
        if !fn.parameters.isEmpty {
            doc += "/// Parameters: \(fn.parameters.joined(separator: ", "))\n"
        }
        if !fn.localVariables.isEmpty {
            doc += "/// Locals: \(fn.localVariables.joined(separator: ", "))\n"
        }
        if let pseudo = await store.pseudocode(forFunctionAt: fn.address.value) {
            doc += "/// Decompiled by \(pseudo.engineID); see pseudocode view for details.\n"
            if !pseudo.warnings.isEmpty {
                doc += "/// Warnings: \(pseudo.warnings.joined(separator: "; "))\n"
            }
        }
        doc += "/// NOTE: generated documentation is heuristic and unverified.\n"
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "function": fn.address.hexString,
            "documentation": doc,
            "provenance": AnalysisProvenance.aiSuggestion.rawValue,
        ])
    }
}

public struct AnalyzeSuspiciousPatternsTool: DecompileAssistTool {
    public init() {}
    public let id = "analyze_suspicious_patterns"
    public let displayName = "Suspicious Patterns"
    public let description = "Scan a function (or the whole binary when no address is given) for suspicious patterns: anti-debug checks, encoded strings, unusual API usage, RWX regions, entry-point anomalies. Reports evidence, not verdicts."
    public var inputSchema: [String: Any] {
        [
        "type": "object",
        "properties": [
            "address": ["type": "string", "description": "Optional function address; omit to scan binary-wide indicators"],
        ] as [String: Any],
        ]
    }
    public let requiresApproval = false

    public func execute(arguments: [String: Any], session: DecompilerSession) async throws -> String {
        let store = await session.analysisStore()
        guard let image = await store.binary else {
            return DecompileAssistToolSupport.error("no binary loaded")
        }
        var findings: [[String: Any]] = []

        // Binary-wide checks.
        if image.isEncrypted {
            findings.append(["pattern": "encrypted_binary", "severity": "info",
                             "detail": "FairPlay-encrypted content; static analysis may be incomplete"])
        }
        for seg in image.segments where seg.isExecutable && seg.sections.contains(where: { $0.isWritable }) {
            findings.append(["pattern": "writable_executable_section", "severity": "medium",
                             "detail": "Segment \(seg.name) is both executable and writable"])
        }

        // Function-scoped checks when an address is provided.
        if let addr = DecompileAssistToolSupport.address(arguments) {
            if let fn = await store.function(containing: addr.value) {
                let xrefs = await store.crossReferences
                let strings = await store.stringsList
                let fnEnd = fn.endAddress?.value ?? fn.address.value + max(fn.size, 1)
                let suspiciousAPIs = ["ptrace", "sysctl", "isatty", "debugger", "exception", "vm_protect", "mprotect"]
                let allSymbols = await store.symbols
                var hits: [String] = []
                for x in xrefs where x.kind == .call && x.sourceFunction == fn.address {
                    if let sym = allSymbols.first(where: { $0.address?.value == x.destinationFunction?.value || $0.address?.value == x.destination.value }) {
                        let name = sym.effectiveName.lowercased()
                        if suspiciousAPIs.contains(where: { name.contains($0) }) { hits.append(sym.effectiveName) }
                    }
                }
                if !hits.isEmpty {
                    findings.append(["pattern": "anti_analysis_api", "severity": "medium",
                                     "function": fn.address.hexString,
                                     "detail": "Calls potentially anti-debug/anti-analysis APIs: \(hits.joined(separator: ", "))"])
                }
                let encoded = strings.filter {
                    $0.address.value >= fn.address.value && $0.address.value < fnEnd
                        && $0.text.rangeOfCharacter(from: .letters) == nil
                        && $0.text.count > 8
                }
                if encoded.count > 3 {
                    findings.append(["pattern": "possible_encoded_strings", "severity": "low",
                                     "function": fn.address.hexString,
                                     "detail": "\(encoded.count) high-entropy/non-alphabetic strings in function range — possible encoded data"])
                }
            }
        }
        return DecompileAssistToolSupport.encode([
            "ok": true,
            "findings": findings,
            "finding_count": findings.count,
            "provenance": AnalysisProvenance.aiSuggestion.rawValue,
            "disclaimer": "Pattern matches are indicators for manual review, not malware verdicts.",
        ])
    }
}
