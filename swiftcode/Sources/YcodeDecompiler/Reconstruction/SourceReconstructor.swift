import Foundation

public enum SourceReconstructor {
    public static func reconstruct(image: BinaryImage, functions: [DecompilerFunction],
                                   pseudocode: [UInt64: DecompilationResult],
                                   instructions: [Instruction],
                                   decompilerAvailable: Bool) -> ReconstructedSource {
        let libraryName = libraryName(for: image)
        let language = LanguageIdentification.identify(image: image)
        var diagnostics: [ReconstructionDiagnostic] = []
        var records: [ReconstructionRecord] = []
        var files: [GeneratedSourceFile] = []
        var exportedNames: [String] = []
        var unresolvedImports: [String] = []
        var enginesUsed: Set<String> = []

        if !decompilerAvailable {
            diagnostics.append(ReconstructionDiagnostic(
                severity: .warning,
                message: "No decompiler backend is available (Ghidra not installed). All functions fall back to verbatim assembly preservation; edit them in C by replacing their assembly with a C implementation."))
        }
        if image.symbols.isEmpty && image.exports.isEmpty {
            diagnostics.append(ReconstructionDiagnostic(
                severity: .warning,
                message: "Binary appears stripped: no symbol table or export list was recovered. Functions are identified by address only and names are inferred."))
        }

        var nameByAddress: [UInt64: String] = [:]
        var usedNames: Set<String> = []
        for fn in functions.sorted(by: { $0.address.value < $1.address.value }) {
            var cName = ReconstructionUtilities.cFunctionName(for: fn.originalName ?? fn.name)
            if usedNames.contains(cName) {
                var suffix = 2
                while usedNames.contains("\(cName)_\(suffix)") { suffix += 1 }
                cName = "\(cName)_\(suffix)"
                diagnostics.append(ReconstructionDiagnostic(
                    severity: .warning,
                    message: "Name collision for \(fn.address.hexString); renamed to \(cName).",
                    functionAddress: fn.address))
            }
            usedNames.insert(cName)
            nameByAddress[fn.address.value] = cName
        }

        var importNamesByAddress: [UInt64: String] = [:]
        for imp in image.imports {
            if let addr = imp.address {
                importNamesByAddress[addr.value] = ReconstructionUtilities.cFunctionName(for: imp.name)
            }
        }
        var symbolNamesByAddress: [UInt64: String] = [:]
        for sym in image.symbols {
            if let addr = sym.address {
                symbolNamesByAddress[addr.value] = ReconstructionUtilities.cFunctionName(for: sym.effectiveName)
            }
        }
        let stringAddresses = Set(image.strings.map(\.address.value))
        let instructionsByFunction = groupInstructions(instructions, functions: functions)

        let headerName = "\(libraryName).h"
        var cLines: [String] = []
        var cDefinitionLines: [UInt64: Int] = [:]
        var asmFunctions: [DecompilerFunction] = []
        var datBlobs: [(label: String, bytes: Data, address: UInt64)] = []
        var datBlobLabels: Set<String> = []
        var referencedStrings: Set<UInt64> = []

        let headerInclude = "#include \"\(headerName)\""
        cLines.append(headerInclude)
        cLines.append("")

        for fn in functions.sorted(by: { $0.address.value < $1.address.value }) {
            guard fn.kind != .importedSymbol else { continue }
            let cName = nameByAddress[fn.address.value] ?? "fn_\(String(fn.address.value, radix: 16))"
            let fnLanguage = LanguageIdentification.identifySymbol(fn.originalName ?? fn.name)
            let effectiveLanguage = fnLanguage == .unknown ? language : fnLanguage
            if let result = pseudocode[fn.address.value], !result.pseudocode.isEmpty {
                enginesUsed.insert(result.engineID)
                let mapped = result.signature.flatMap {
                    ReconstructionUtilities.mapGhidraSignature($0, functionName: result.functionName)
                }
                let returnType = mapped?.returnType
                    ?? (result.returnType.map { ReconstructionUtilities.ghidraTypeToC($0) })
                    ?? fn.returnType ?? "long"
                let params = mapped?.parameters ?? fn.parameters
                let signature = cSignature(returnType: returnType, name: cName, parameters: params)
                let body = extractBody(result.pseudocode) ?? result.pseudocode
                var rewrittenBody = body
                var unresolved: [String] = []
                let warnings: [String] = result.warnings
                rewrittenBody = rewriteSymbolReferences(rewrittenBody, image: image,
                                                        nameByAddress: nameByAddress,
                                                        referencedStrings: &referencedStrings,
                                                        datBlobs: &datBlobs, datBlobLabels: &datBlobLabels,
                                                        unresolved: &unresolved, diagnostics: &diagnostics,
                                                        functionAddress: fn.address)
                let definitionLine = cLines.count + 1
                cLines.append(signature + " {")
                for line in rewrittenBody.components(separatedBy: "\n") {
                    cLines.append(line)
                }
                cLines.append("}")
                cLines.append("")
                cDefinitionLines[fn.address.value] = definitionLine
                records.append(ReconstructionRecord(
                    functionAddress: fn.address, originalName: fn.originalName,
                    recoveredName: cName, language: effectiveLanguage,
                    architecture: image.architecture, signature: signature,
                    returnType: returnType, parameters: params,
                    callingConvention: fn.callingConvention, localVariables: result.localVariables,
                    quality: mapped == nil ? .inferred : .reconstructed,
                    provenance: AnalysisSource(provenance: .engine, engineID: result.engineID,
                                               engineVersion: result.engineVersion, pass: "decompile"),
                    generatedFile: "Sources/reconstructed.c", generatedLine: definitionLine,
                    instructionAddresses: (instructionsByFunction[fn.address.value] ?? []).map(\.address.value),
                    dependencies: [], unresolvedReferences: unresolved, warnings: warnings,
                    engineID: result.engineID, hasPseudocode: true, hasAssemblyFallback: false))
            } else {
                asmFunctions.append(fn)
            }
        }

        var mapEntries: [SourceMapping.Entry] = []
        for record in records {
            if let file = record.generatedFile, let line = record.generatedLine {
                mapEntries.append(SourceMapping.Entry(address: record.functionAddress.value, file: file,
                                                      line: line, function: record.recoveredName,
                                                      quality: record.quality))
            }
        }

        let fallbackContext = AssemblyFallback.Context(
            image: image, functionCNames: nameByAddress,
            importNamesByAddress: importNamesByAddress,
            symbolNamesByAddress: symbolNamesByAddress,
            stringAddresses: stringAddresses)
        var repaired: [AssemblyFallback.RepairedFunction] = []
        for fn in asmFunctions {
            let fnInstructions = instructionsByFunction[fn.address.value] ?? []
            let cName = nameByAddress[fn.address.value] ?? "fn_\(String(fn.address.value, radix: 16))"
            if fnInstructions.isEmpty {
                diagnostics.append(ReconstructionDiagnostic(
                    severity: .warning,
                    message: "Function \(cName) at \(fn.address.hexString) has no disassembly and no pseudocode; it is not emitted and its export will be missing from the rebuilt library.",
                    functionAddress: fn.address))
                records.append(ReconstructionRecord(
                    functionAddress: fn.address, originalName: fn.originalName,
                    recoveredName: cName, language: language, architecture: image.architecture,
                    quality: .unresolved,
                    provenance: AnalysisSource(provenance: .heuristic, pass: "reconstruct"),
                    warnings: ["No disassembly or pseudocode available."],
                    hasPseudocode: false, hasAssemblyFallback: false))
                continue
            }
            let rep = AssemblyFallback.repairFunction(fn, instructions: fnInstructions, context: fallbackContext)
            repaired.append(rep)
            for warning in rep.warnings {
                diagnostics.append(ReconstructionDiagnostic(severity: .warning, message: warning,
                                                            functionAddress: fn.address))
            }
            records.append(ReconstructionRecord(
                functionAddress: fn.address, originalName: fn.originalName,
                recoveredName: cName, language: language, architecture: image.architecture,
                signature: "long \(cName)()",
                quality: .partial,
                provenance: AnalysisSource(provenance: .engine, engineID: "objdump", pass: "disassemble"),
                generatedFile: "Assembly/original_text.s",
                instructionAddresses: fnInstructions.map(\.address.value),
                warnings: rep.warnings,
                hasPseudocode: false, hasAssemblyFallback: true))
        }
        for rep in repaired {
            mapEntries.append(SourceMapping.Entry(address: rep.function.address.value,
                                                  file: "Assembly/original_text.s", line: 1,
                                                  function: rep.cName, quality: .partial))
        }

        let asmText: String? = repaired.isEmpty ? nil : AssemblyFallback.emitAssemblyFile(
            functions: repaired, format: image.format, architecture: image.architecture)

        let headerText = buildHeader(image: image, libraryName: libraryName,
                                     functions: functions, nameByAddress: nameByAddress,
                                     records: records, referencedStrings: referencedStrings,
                                     datBlobs: datBlobs, diagnostics: &diagnostics,
                                     exportedNames: &exportedNames, unresolvedImports: &unresolvedImports)
        files.append(GeneratedSourceFile(relativePath: "Headers/\(headerName)", contents: headerText,
                                         language: .c, quality: .recovered))
        if records.contains(where: \.hasPseudocode) {
            files.append(GeneratedSourceFile(relativePath: "Headers/ghidra_types.h",
                                             contents: ghidraTypesHeader(), language: .c,
                                             quality: .reconstructed))
        }
        let objcClasses = objcClassNames(image: image)
        if !objcClasses.isEmpty {
            files.append(GeneratedSourceFile(relativePath: "Headers/\(libraryName)_objc.h",
                                             contents: objcHeader(classes: objcClasses, libraryName: libraryName),
                                             language: .objectiveC, quality: .partial))
        }
        if cLines.count > 2 {
            files.append(GeneratedSourceFile(relativePath: "Sources/reconstructed.c",
                                             contents: cLines.joined(separator: "\n"),
                                             language: .c, quality: .reconstructed))
        }
        let stringsFile = buildStringsFile(image: image, referenced: referencedStrings,
                                           diagnostics: &diagnostics)
        if let stringsFile {
            files.append(stringsFile)
        }
        if !datBlobs.isEmpty {
            files.append(GeneratedSourceFile(relativePath: "Sources/data.c",
                                             contents: buildDataFile(datBlobs: datBlobs, headerName: headerName),
                                             language: .c, quality: .partial))
        }
        if let asmText {
            files.append(GeneratedSourceFile(relativePath: "Assembly/original_text.s",
                                             contents: asmText, language: .assembly, quality: .partial))
        }
        if language == .swift {
            files.append(GeneratedSourceFile(
                relativePath: "Metadata/swift-symbols.txt",
                contents: swiftSymbolsNote(image: image),
                language: .unknown, quality: .unsupported))
            diagnostics.append(ReconstructionDiagnostic(
                severity: .warning,
                message: "Swift source reconstruction is not reliable: Swift symbols and metadata are preserved as a symbol list, and functions are reconstructed as C or assembly. Do not treat the output as original Swift source."))
        }

        let sourceMap = SourceMapping(entries: mapEntries.sorted { $0.address < $1.address },
                                      originalSHA256: image.identity.sha256,
                                      originalFileName: image.identity.originalFileName)
        return ReconstructedSource(
            libraryName: libraryName, language: language, records: records, files: files,
            diagnostics: diagnostics, sourceMap: sourceMap, exportedNames: exportedNames,
            unresolvedImports: unresolvedImports, enginesUsed: Array(enginesUsed).sorted(),
            decompilerAvailable: decompilerAvailable)
    }

    private static func libraryName(for image: BinaryImage) -> String {
        var name = image.identity.originalFileName
        for ext in [".dylib", ".so", ".dll", ".o", ".a"] {
            if name.hasSuffix(ext) { name = String(name.dropLast(ext.count)); break }
        }
        if name.hasPrefix("lib") { name = String(name.dropFirst(3)) }
        let sanitized = ReconstructionUtilities.sanitizedCIdentifier(name)
        return sanitized.isEmpty ? "reconstructed" : sanitized
    }

    private static func groupInstructions(_ instructions: [Instruction],
                                          functions: [DecompilerFunction]) -> [UInt64: [Instruction]] {
        let sortedFunctions = functions.sorted { $0.address.value < $1.address.value }
        var out: [UInt64: [Instruction]] = [:]
        for ins in instructions {
            var owner: DecompilerFunction?
            for fn in sortedFunctions {
                if fn.address.value <= ins.address.value {
                    owner = fn
                } else {
                    break
                }
            }
            if let owner {
                out[owner.address.value, default: []].append(ins)
            }
        }
        return out
    }

    private static func cSignature(returnType: String, name: String, parameters: [String]) -> String {
        if parameters.isEmpty {
            return "\(returnType) \(name)()"
        }
        return "\(returnType) \(name)(\(parameters.joined(separator: ", ")))"
    }

    private static func extractBody(_ pseudocode: String) -> String? {
        guard let open = pseudocode.firstIndex(of: "{"),
              let close = pseudocode.lastIndex(of: "}"), close > open else { return nil }
        return String(pseudocode[pseudocode.index(after: open)..<close])
    }

    private static func rewriteSymbolReferences(_ body: String, image: BinaryImage,
                                                nameByAddress: [UInt64: String],
                                                referencedStrings: inout Set<UInt64>,
                                                datBlobs: inout [(label: String, bytes: Data, address: UInt64)],
                                                datBlobLabels: inout Set<String>,
                                                unresolved: inout [String],
                                                diagnostics: inout [ReconstructionDiagnostic],
                                                functionAddress: DecompilerAddress) -> String {
        var out = body
        out = rewritePattern(out, pattern: "FUN_(?:0x)?([0-9a-fA-F]+)") { hex in
            guard let addr = UInt64(hex, radix: 16), let name = nameByAddress[addr] else {
                unresolved.append("FUN_\(hex)")
                return nil
            }
            return name
        }
        out = rewritePattern(out, pattern: "DAT_(?:0x)?([0-9a-fA-F]+)") { hex in
            guard let addr = UInt64(hex, radix: 16) else {
                unresolved.append("DAT_\(hex)")
                return nil
            }
            if image.strings.contains(where: { $0.address.value == addr }) {
                referencedStrings.insert(addr)
                return "__sc_str_\(String(addr, radix: 16))"
            }
            let label = ReconstructionUtilities.dataLabel(for: addr)
            if !datBlobLabels.contains(label) {
                datBlobLabels.insert(label)
                let section = image.segments.flatMap(\.sections).first {
                    addr >= $0.address.value && addr < $0.address.value + $0.size
                }
                if let section {
                    let length = min(4096, Int(section.address.value + section.size - addr))
                    if length > 0, let bytes = try? image.bytes(virtualAddress: addr, length: length) {
                        datBlobs.append((label: label, bytes: bytes, address: addr))
                    }
                }
            }
            if datBlobLabels.contains(label) {
                return label
            }
            unresolved.append("DAT_\(hex)")
            diagnostics.append(ReconstructionDiagnostic(
                severity: .warning,
                message: "Data reference DAT_\(hex) could not be resolved to bytes in the binary.",
                functionAddress: functionAddress))
            return nil
        }
        return out
    }

    private static func rewritePattern(_ text: String, pattern: String,
                                       replace: (String) -> String?) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var out = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let hexRange = Range(match.range(at: 1), in: text),
                  let fullRange = Range(match.range, in: text) else { continue }
            let hex = String(text[hexRange])
            guard let replacement = replace(hex) else { continue }
            let startOffset = text.distance(from: text.startIndex, to: fullRange.lowerBound)
            let endOffset = text.distance(from: text.startIndex, to: fullRange.upperBound)
            let start = out.index(out.startIndex, offsetBy: startOffset)
            let end = out.index(out.startIndex, offsetBy: endOffset)
            out.replaceSubrange(start..<end, with: replacement)
        }
        return out
    }

    private static func buildHeader(image: BinaryImage, libraryName: String,
                                    functions: [DecompilerFunction],
                                    nameByAddress: [UInt64: String],
                                    records: [ReconstructionRecord],
                                    referencedStrings: Set<UInt64>,
                                    datBlobs: [(label: String, bytes: Data, address: UInt64)],
                                    diagnostics: inout [ReconstructionDiagnostic],
                                    exportedNames: inout [String],
                                    unresolvedImports: inout [String]) -> String {
        let guardName = "\(libraryName.uppercased())_RECONSTRUCTED_H"
        var lines: [String] = []
        lines.append("#ifndef \(guardName)")
        lines.append("#define \(guardName)")
        lines.append("")
        lines.append("#include <stdint.h>")
        lines.append("#include <stdbool.h>")
        lines.append("#include <stddef.h>")
        lines.append("#include \"ghidra_types.h\"")
        lines.append("")
        let knownHeaders: [(names: Set<String>, header: String)] = [
            (["strlen", "strcpy", "strncpy", "strcat", "strncat", "strcmp", "strncmp", "strchr", "strrchr", "strstr", "memcpy", "memmove", "memset", "memcmp", "strdup"], "<string.h>"),
            (["malloc", "calloc", "realloc", "free", "abort", "exit", "atoi", "atol", "rand", "srand"], "<stdlib.h>"),
            (["printf", "fprintf", "sprintf", "snprintf", "puts", "fputs", "fopen", "fclose", "fread", "fwrite"], "<stdio.h>"),
            (["pow", "sqrt", "sin", "cos", "tan", "exp", "log", "fabs", "floor", "ceil"], "<math.h>"),
        ]
        var includedHeaders: [String] = []
        for imp in image.imports {
            let cName = ReconstructionUtilities.cFunctionName(for: imp.name)
            for (names, header) in knownHeaders where names.contains(cName) {
                if !includedHeaders.contains(header) { includedHeaders.append(header) }
            }
        }
        for header in includedHeaders.sorted() {
            lines.append("#include \(header)")
        }
        if !includedHeaders.isEmpty { lines.append("") }
        for exp in image.exports {
            guard let record = records.first(where: { $0.functionAddress.value == exp.address.value }) else {
                continue
            }
            exportedNames.append(record.recoveredName)
            lines.append("\(record.signature ?? "long \(record.recoveredName)()");")
        }
        if !image.exports.isEmpty { lines.append("") }
        for imp in image.imports {
            let cName = ReconstructionUtilities.cFunctionName(for: imp.name)
            if knownHeaders.contains(where: { $0.names.contains(cName) }) { continue }
            unresolvedImports.append(cName)
            lines.append("extern long \(cName)();")
        }
        if !image.imports.isEmpty { lines.append("") }
        for addr in referencedStrings.sorted() {
            lines.append("extern const char __sc_str_\(String(addr, radix: 16))[];")
        }
        if !referencedStrings.isEmpty { lines.append("") }
        for blob in datBlobs {
            lines.append("extern unsigned char \(blob.label)[];")
        }
        if !datBlobs.isEmpty { lines.append("") }
        lines.append("#endif")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func buildStringsFile(image: BinaryImage, referenced: Set<UInt64>,
                                         diagnostics: inout [ReconstructionDiagnostic]) -> GeneratedSourceFile? {
        var lines: [String] = []
        lines.append("#include \"\(libraryName(for: image)).h\"")
        lines.append("")
        var emitted = 0
        for str in image.strings.sorted(by: { $0.address.value < $1.address.value }) {
            guard str.encoding == .ascii || str.encoding == .utf8 else { continue }
            guard !str.text.isEmpty, str.text.count <= 4096,
                  str.text.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value < 0x7f || $0.value >= 0xa0 }) else {
                continue
            }
            lines.append("const char __sc_str_\(String(str.address.value, radix: 16))[] = \"\(ReconstructionUtilities.escapeCString(str.text))\";")
            emitted += 1
        }
        if emitted == 0 { return nil }
        _ = diagnostics
        return GeneratedSourceFile(relativePath: "Sources/strings.c",
                                   contents: lines.joined(separator: "\n") + "\n",
                                   language: .c, quality: .recovered)
    }

    private static func buildDataFile(datBlobs: [(label: String, bytes: Data, address: UInt64)],
                                      headerName: String) -> String {
        var lines: [String] = []
        lines.append("#include \"\(headerName)\"")
        lines.append("")
        for blob in datBlobs {
            lines.append("__attribute__((aligned(16))) unsigned char \(blob.label)[] = {")
            var offset = blob.bytes.startIndex
            while offset < blob.bytes.endIndex {
                let end = blob.bytes.index(offset, offsetBy: 16, limitedBy: blob.bytes.endIndex) ?? blob.bytes.endIndex
                let chunk = blob.bytes[offset..<end]
                lines.append("    " + chunk.map { String(format: "0x%02x", $0) }.joined(separator: ", ") + ",")
                offset = end
            }
            lines.append("};")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func ghidraTypesHeader() -> String {
        var lines: [String] = []
        lines.append("#ifndef SC_GHIDRA_TYPES_H")
        lines.append("#define SC_GHIDRA_TYPES_H")
        lines.append("")
        lines.append("#include <stdint.h>")
        lines.append("#include <stdbool.h>")
        lines.append("")
        lines.append("typedef uint8_t undefined;")
        lines.append("typedef uint8_t undefined1;")
        lines.append("typedef uint16_t undefined2;")
        lines.append("typedef uint32_t undefined4;")
        lines.append("typedef uint64_t undefined8;")
        lines.append("typedef uint8_t byte;")
        lines.append("typedef uint16_t word;")
        lines.append("typedef uint32_t dword;")
        lines.append("typedef uint64_t qword;")
        lines.append("typedef uint64_t ulong;")
        lines.append("typedef uint32_t uint;")
        lines.append("typedef uint16_t ushort;")
        lines.append("typedef uint8_t uchar;")
        lines.append("typedef void code;")
        lines.append("")
        lines.append("#define CONCAT11(a, b) ((uint8_t)(a))")
        lines.append("#define CONCAT12(a, b) ((uint16_t)((uint16_t)(a) | ((uint16_t)(b) << 8)))")
        lines.append("#define CONCAT21(a, b) ((uint16_t)((uint16_t)(a) | ((uint16_t)(b) << 8)))")
        lines.append("#define CONCAT22(a, b) ((uint32_t)((uint32_t)(a) | ((uint32_t)(b) << 16)))")
        lines.append("#define CONCAT24(a, b) ((uint64_t)((uint64_t)(a) | ((uint64_t)(b) << 32)))")
        lines.append("#define CONCAT42(a, b) ((uint64_t)((uint64_t)(a) | ((uint64_t)(b) << 32)))")
        lines.append("#define CONCAT44(a, b) ((uint64_t)((uint64_t)(a) | ((uint64_t)(b) << 32)))")
        lines.append("#define CONCAT88(a, b) ((unsigned __int128)((unsigned __int128)(a) | ((unsigned __int128)(b) << 64)))")
        lines.append("#define SUB11(a, b) ((uint8_t)(a))")
        lines.append("#define SUB41(a, b) ((uint32_t)((uint64_t)(a) >> (8 * (b))))")
        lines.append("#define SUB42(a, b) ((uint32_t)((uint64_t)(a) >> (8 * (b))))")
        lines.append("#define SUB44(a, b) ((uint32_t)((uint64_t)(a) >> (8 * (b))))")
        lines.append("#define SUB81(a, b) ((uint8_t)((uint64_t)(a) >> (8 * (b))))")
        lines.append("#define ZEXT11(a) ((uint8_t)(a))")
        lines.append("#define ZEXT14(a) ((uint32_t)(a))")
        lines.append("#define ZEXT18(a) ((uint64_t)(a))")
        lines.append("#define SEXT14(a) ((int32_t)(int8_t)(a))")
        lines.append("#define SEXT18(a) ((int64_t)(int8_t)(a))")
        lines.append("#define SEXT24(a) ((int32_t)(int16_t)(a))")
        lines.append("#define SEXT28(a) ((int64_t)(int16_t)(a))")
        lines.append("#define SEXT48(a) ((int64_t)(int32_t)(a))")
        lines.append("")
        lines.append("#endif")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func objcClassNames(image: BinaryImage) -> [String] {
        var classes: [String] = []
        for sym in image.symbols {
            if sym.name.hasPrefix("OBJC_CLASS_$_") {
                classes.append(String(sym.name.dropFirst("OBJC_CLASS_$_".count)))
            }
        }
        for exp in image.exports where exp.name.hasPrefix("OBJC_CLASS_$_") {
            classes.append(String(exp.name.dropFirst("OBJC_CLASS_$_".count)))
        }
        return Array(Set(classes)).sorted()
    }

    private static func objcHeader(classes: [String], libraryName: String) -> String {
        var lines: [String] = []
        lines.append("#import <Foundation/Foundation.h>")
        lines.append("")
        for cls in classes {
            lines.append("@class \(ReconstructionUtilities.sanitizedCIdentifier(cls));")
        }
        lines.append("")
        lines.append("/*")
        lines.append(" * Objective-C class list recovered from symbols. Method lists, ivars,")
        lines.append(" * properties, and categories are not recoverable from symbols alone;")
        lines.append(" * they require __objc_* metadata parsing, which is not implemented yet.")
        lines.append(" * Add method declarations here as they are recovered or rewritten.")
        lines.append(" */")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func swiftSymbolsNote(image: BinaryImage) -> String {
        var lines: [String] = []
        lines.append("Swift symbols recovered from this binary.")
        lines.append("Swift source reconstruction is not reliable: the functions in this")
        lines.append("project are reconstructed as C or preserved as assembly. The list")
        lines.append("below is evidence for manual rewriting, not recovered Swift source.")
        lines.append("")
        for sym in image.symbols.sorted(by: { $0.name < $1.name }) {
            lines.append("\(sym.address?.hexString ?? "-")  \(sym.effectiveName)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
