import Foundation

public struct AssemblyFallback {
    public struct DataBlob: Sendable {
        public enum Kind: Sendable { case bytes, cstring, page, gotSlot }
        public var label: String
        public var bytes: Data
        public var kind: Kind
        public var symbolName: String?
        public var pageAligned: Bool

        public init(label: String, bytes: Data = Data(), kind: Kind, symbolName: String? = nil,
                    pageAligned: Bool = false) {
            self.label = label
            self.bytes = bytes
            self.kind = kind
            self.symbolName = symbolName
            self.pageAligned = pageAligned
        }
    }

    public struct RepairedFunction: Sendable {
        public var function: DecompilerFunction
        public var cName: String
        public var lines: [String]
        public var blobs: [DataBlob]
        public var warnings: [String]
        public var repairedCount: Int
        public var unrepairedCount: Int

        public init(function: DecompilerFunction, cName: String, lines: [String] = [],
                    blobs: [DataBlob] = [], warnings: [String] = [], repairedCount: Int = 0,
                    unrepairedCount: Int = 0) {
            self.function = function
            self.cName = cName
            self.lines = lines
            self.blobs = blobs
            self.warnings = warnings
            self.repairedCount = repairedCount
            self.unrepairedCount = unrepairedCount
        }
    }

    public struct Context: Sendable {
        public var image: BinaryImage
        public var functionCNames: [UInt64: String]
        public var importNamesByAddress: [UInt64: String]
        public var symbolNamesByAddress: [UInt64: String]
        public var stringAddresses: Set<UInt64>

        public init(image: BinaryImage, functionCNames: [UInt64: String] = [:],
                    importNamesByAddress: [UInt64: String] = [:],
                    symbolNamesByAddress: [UInt64: String] = [:],
                    stringAddresses: Set<UInt64> = []) {
            self.image = image
            self.functionCNames = functionCNames
            self.importNamesByAddress = importNamesByAddress
            self.symbolNamesByAddress = symbolNamesByAddress
            self.stringAddresses = stringAddresses
        }
    }

    public static func repairFunction(_ function: DecompilerFunction, instructions: [Instruction],
                                      context: Context) -> RepairedFunction {
        let cName = ReconstructionUtilities.cFunctionName(for: function.originalName ?? function.name)
        var result = RepairedFunction(function: function, cName: cName)
        var blobsByLabel: [String: DataBlob] = [:]
        let sorted = instructions.sorted { $0.address.value < $1.address.value }
        switch context.image.architecture {
        case .x86_64, .i386:
            repairX86(sorted, context: context, result: &result, blobsByLabel: &blobsByLabel)
        case .arm64, .arm64_32, .armv7, .armv7s, .armv6:
            repairARM64(sorted, context: context, result: &result, blobsByLabel: &blobsByLabel)
        default:
            for ins in sorted {
                result.lines.append(contentsOf: byteLines(for: ins))
            }
            result.warnings.append("Architecture \(context.image.architecture.displayName) has no relocation repair; function bytes are emitted verbatim and PC-relative references are not repaired.")
            result.unrepairedCount += 1
        }
        result.blobs = blobsByLabel.values.sorted { $0.label < $1.label }
        return result
    }

    public static func emitAssemblyFile(functions: [RepairedFunction], format: BinaryFormat,
                                        architecture: BinaryArchitecture) -> String {
        var out: [String] = []
        out.append(".text")
        for fn in functions {
            let asmName = ReconstructionUtilities.asmSymbolName(fn.cName, format: format)
            out.append("")
            out.append("/* original: \(fn.function.originalName ?? fn.function.name) @ 0x\(String(fn.function.address.value, radix: 16)) */")
            out.append(".globl \(asmName)")
            if format == .elf {
                out.append(".type \(asmName),@function")
            }
            out.append(".p2align \(architecture == .x86_64 || architecture == .i386 ? 4 : 2)")
            out.append("\(asmName):")
            out.append(contentsOf: fn.lines)
            if format == .elf {
                out.append(".size \(asmName), .-\(asmName)")
            }
        }
        var allBlobs: [DataBlob] = []
        for fn in functions { allBlobs.append(contentsOf: fn.blobs) }
        var seen: Set<String> = []
        let uniqueBlobs = allBlobs.filter { seen.insert($0.label).inserted }
        let dataBlobs = uniqueBlobs.filter { $0.kind != .gotSlot }
        let gotBlobs = uniqueBlobs.filter { $0.kind == .gotSlot }
        if !dataBlobs.isEmpty {
            out.append("")
            switch format {
            case .machO: out.append(".section __DATA,__const")
            case .elf: out.append(".section .rodata")
            case .pe: out.append(".section .rdata")
            case .unknown: out.append(".section .rodata")
            }
            for blob in dataBlobs.sorted(by: { $0.label < $1.label }) {
                out.append("")
                if blob.pageAligned { out.append(".p2align 12") }
                out.append("\(blob.label):")
                out.append(contentsOf: ReconstructionUtilities.byteLines(blob.bytes))
            }
        }
        if !gotBlobs.isEmpty {
            out.append("")
            switch format {
            case .machO: out.append(".section __DATA,__data")
            case .elf: out.append(".section .data.rel.ro")
            case .pe: out.append(".section .data")
            case .unknown: out.append(".section .data")
            }
            for blob in gotBlobs.sorted(by: { $0.label < $1.label }) {
                out.append("")
                out.append("\(blob.label):")
                let sym = blob.symbolName.map { ReconstructionUtilities.asmSymbolName($0, format: format) } ?? "0"
                out.append("    .quad \(sym)")
            }
        }
        out.append("")
        return out.joined(separator: "\n")
    }

    private static func byteLines(for ins: Instruction) -> [String] {
        ReconstructionUtilities.byteLines(ins.rawBytes)
    }

    private static func section(containing address: UInt64, in image: BinaryImage) -> BinarySectionInfo? {
        image.segments.flatMap(\.sections).first {
            address >= $0.address.value && address < $0.address.value + $0.size
        }
    }

    private static func readBytes(at address: UInt64, length: Int, context: Context) -> Data? {
        guard length > 0 else { return nil }
        return try? context.image.bytes(virtualAddress: address, length: length)
    }

    private static func readCString(at address: UInt64, context: Context, cap: Int = 4096) -> Data? {
        guard let section = section(containing: address, in: context.image) else { return nil }
        let maxLength = min(cap, Int(section.address.value + section.size - address))
        guard maxLength > 0,
              let bytes = try? context.image.bytes(virtualAddress: address, length: maxLength) else { return nil }
        if let nul = bytes.firstIndex(of: 0) {
            return Data(bytes[bytes.startIndex...nul])
        }
        return Data(bytes)
    }

    private static func addBlob(_ blob: DataBlob, into map: inout [String: DataBlob]) {
        if map[blob.label] == nil {
            map[blob.label] = blob
        }
    }
}

extension AssemblyFallback {
    private static func repairX86(_ instructions: [Instruction], context: Context,
                                  result: inout RepairedFunction, blobsByLabel: inout [String: DataBlob]) {
        let image = context.image
        for ins in instructions {
            let mnemonic = ins.mnemonic.lowercased()
            let text = ins.text
            if let rewritten = rewriteX86Branch(ins, context: context, result: &result) {
                result.lines.append("    \(rewritten)")
                result.repairedCount += 1
                continue
            }
            if text.contains("@GOTPCREL") {
                if let rewritten = rewriteX86GOT(ins, context: context, result: &result,
                                                  blobsByLabel: &blobsByLabel) {
                    result.lines.append("    \(rewritten)")
                    result.repairedCount += 1
                    continue
                }
                result.lines.append(contentsOf: byteLines(for: ins))
                result.warnings.append("Unrepaired GOT reference at \(ins.address.hexString): \(text)")
                result.unrepairedCount += 1
                continue
            }
            if text.contains("(%rip)") {
                if let rewritten = rewriteX86RIP(ins, context: context, result: &result,
                                                  blobsByLabel: &blobsByLabel) {
                    result.lines.append("    \(rewritten)")
                    result.repairedCount += 1
                    continue
                }
                result.lines.append(contentsOf: byteLines(for: ins))
                if mnemonic != "lea" {
                    result.warnings.append("Unrepaired PC-relative reference at \(ins.address.hexString): \(text)")
                    result.unrepairedCount += 1
                }
                continue
            }
            _ = image
            result.lines.append(contentsOf: byteLines(for: ins))
        }
    }

    private static func rewriteX86Branch(_ ins: Instruction, context: Context,
                                         result: inout RepairedFunction) -> String? {
        guard ins.classification == .call || ins.classification == .branch,
              let target = ins.branchTarget else { return nil }
        if context.functionCNames[target.value] != nil { return nil }
        let name = context.importNamesByAddress[target.value]
            ?? context.symbolNamesByAddress[target.value]
        guard let name else {
            if ins.classification == .call {
                result.warnings.append("Call at \(ins.address.hexString) targets unknown external address \(target.hexString); emitted verbatim and likely to fail at link time.")
                result.unrepairedCount += 1
            }
            return nil
        }
        let mnemonic = ins.mnemonic.lowercased()
        guard mnemonic == "call" || mnemonic == "callq" || mnemonic == "jmp" || mnemonic == "jmpq" else {
            return nil
        }
        let cName = ReconstructionUtilities.cFunctionName(for: name)
        if context.image.format == .elf {
            return "\(mnemonic) \(cName)@PLT"
        }
        return "\(mnemonic) \(ReconstructionUtilities.asmSymbolName(cName, format: context.image.format))"
    }

    private static func rewriteX86GOT(_ ins: Instruction, context: Context,
                                      result: inout RepairedFunction,
                                      blobsByLabel: inout [String: DataBlob]) -> String? {
        guard let range = ins.operandText.range(of: "@GOTPCREL") else { return nil }
        let before = ins.operandText[..<range.lowerBound]
        let symbolChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.$"))
        var start = before.endIndex
        var cursor = before.endIndex
        while cursor > before.startIndex {
            let prev = before.index(before: cursor)
            if String(before[prev]).rangeOfCharacter(from: symbolChars) != nil {
                start = prev
                cursor = prev
            } else {
                break
            }
        }
        let rawName = String(before[start...])
        guard !rawName.isEmpty else { return nil }
        let cName = ReconstructionUtilities.cFunctionName(for: rawName)
        let label = ReconstructionUtilities.gotLabel(for: cName)
        addBlob(DataBlob(label: label, kind: .gotSlot, symbolName: cName), into: &blobsByLabel)
        let rewrittenOperand = ins.operandText.replacingOccurrences(
            of: rawName + "@GOTPCREL", with: label)
        return "\(ins.mnemonic) \(rewrittenOperand)"
    }

    private static func rewriteX86RIP(_ ins: Instruction, context: Context,
                                      result: inout RepairedFunction,
                                      blobsByLabel: inout [String: DataBlob]) -> String? {
        guard let ripRange = ins.operandText.range(of: "(%rip)") else { return nil }
        let before = String(ins.operandText[..<ripRange.lowerBound])
        let dispText = ripDisplacement(in: before)
        guard let disp = dispText.flatMap({ ReconstructionUtilities.parseSignedHex($0) }) else {
            return nil
        }
        let nextAddress = Int64(bitPattern: ins.address.value) + Int64(ins.size)
        let target = UInt64(bitPattern: nextAddress + disp)
        if let fnName = context.functionCNames[target] {
            let label = ReconstructionUtilities.asmSymbolName(fnName, format: context.image.format)
            let rewritten = ins.operandText.replacingOccurrences(of: before, with: label)
            return "\(ins.mnemonic) \(rewritten)"
        }
        guard let section = section(containing: target, in: context.image) else {
            result.warnings.append("PC-relative reference at \(ins.address.hexString) targets unmapped address 0x\(String(target, radix: 16)); emitted verbatim.")
            result.unrepairedCount += 1
            return nil
        }
        if section.isExecutable {
            result.warnings.append("PC-relative reference at \(ins.address.hexString) targets code at 0x\(String(target, radix: 16)) that is not a known function; emitted verbatim.")
            result.unrepairedCount += 1
            return nil
        }
        let label = ReconstructionUtilities.dataLabel(for: target)
        let mnemonic = ins.mnemonic.lowercased()
        if context.stringAddresses.contains(target) || mnemonic == "lea" {
            if let bytes = readCString(at: target, context: context) {
                addBlob(DataBlob(label: label, bytes: bytes, kind: .cstring), into: &blobsByLabel)
            } else if let bytes = readBytes(at: target, length: 64, context: context) {
                addBlob(DataBlob(label: label, bytes: bytes, kind: .bytes), into: &blobsByLabel)
            } else {
                return nil
            }
        } else {
            let width: Int
            if mnemonic.hasPrefix("movq") || mnemonic == "movabs" || mnemonic.hasPrefix("movsd") {
                width = 8
            } else if mnemonic.hasPrefix("movl") || mnemonic.hasPrefix("movss") {
                width = 4
            } else if mnemonic.hasPrefix("movw") {
                width = 2
            } else if mnemonic.hasPrefix("movb") {
                width = 1
            } else {
                width = 8
            }
            guard let bytes = readBytes(at: target, length: width, context: context) else { return nil }
            addBlob(DataBlob(label: label, bytes: bytes, kind: .bytes), into: &blobsByLabel)
        }
        let rewritten = ins.operandText.replacingOccurrences(of: before, with: label)
        return "\(ins.mnemonic) \(rewritten)"
    }

    private static func ripDisplacement(in before: String) -> String? {
        var end = before.endIndex
        while end > before.startIndex {
            let prev = before.index(before: end)
            let ch = before[prev]
            if ch.isHexDigit || ch == "x" || ch == "X" || ch == "-" || ch == "+" {
                end = prev
            } else {
                break
            }
        }
        let disp = String(before[end...]).trimmingCharacters(in: .whitespaces)
        return disp.isEmpty ? nil : disp
    }
}

extension AssemblyFallback {
    private static func repairARM64(_ instructions: [Instruction], context: Context,
                                    result: inout RepairedFunction, blobsByLabel: inout [String: DataBlob]) {
        var index = 0
        while index < instructions.count {
            let ins = instructions[index]
            let mnemonic = ins.mnemonic.lowercased()
            if mnemonic == "adrp",
               let next = index + 1 < instructions.count ? instructions[index + 1] : nil,
               let pair = rewriteARM64GOTPair(adrp: ins, ldr: next, context: context,
                                              blobsByLabel: &blobsByLabel) {
                result.lines.append(contentsOf: pair)
                result.repairedCount += 2
                index += 2
                continue
            }
            if mnemonic == "adrp" {
                if let rewritten = rewriteARM64Adrp(ins, context: context, result: &result,
                                                     blobsByLabel: &blobsByLabel) {
                    result.lines.append("    \(rewritten)")
                    result.repairedCount += 1
                    index += 1
                    continue
                }
                result.lines.append(contentsOf: byteLines(for: ins))
                result.warnings.append("Unrepaired adrp at \(ins.address.hexString): \(ins.text)")
                result.unrepairedCount += 1
                index += 1
                continue
            }
            if mnemonic == "adr" {
                if let rewritten = rewriteARM64Adr(ins, context: context, result: &result,
                                                    blobsByLabel: &blobsByLabel) {
                    result.lines.append("    \(rewritten)")
                    result.repairedCount += 1
                    index += 1
                    continue
                }
                result.lines.append(contentsOf: byteLines(for: ins))
                result.warnings.append("Unrepaired adr at \(ins.address.hexString): \(ins.text)")
                result.unrepairedCount += 1
                index += 1
                continue
            }
            if (ins.classification == .call || ins.classification == .branch),
               let target = ins.branchTarget {
                if context.functionCNames[target.value] == nil,
                   let name = context.importNamesByAddress[target.value]
                        ?? context.symbolNamesByAddress[target.value],
                   mnemonic == "bl" || mnemonic == "b" {
                    let cName = ReconstructionUtilities.cFunctionName(for: name)
                    let sym = ReconstructionUtilities.asmSymbolName(cName, format: context.image.format)
                    result.lines.append("    \(mnemonic) \(sym)")
                    result.repairedCount += 1
                    index += 1
                    continue
                }
                if context.functionCNames[target.value] == nil,
                   context.importNamesByAddress[target.value] == nil,
                   context.symbolNamesByAddress[target.value] == nil,
                   mnemonic == "bl" {
                    result.warnings.append("Branch-and-link at \(ins.address.hexString) targets unknown external address \(target.hexString); emitted verbatim and likely to fail at link time.")
                    result.unrepairedCount += 1
                }
            }
            result.lines.append(contentsOf: byteLines(for: ins))
            index += 1
        }
    }

    private static func rewriteARM64GOTPair(adrp: Instruction, ldr: Instruction, context: Context,
                                            blobsByLabel: inout [String: DataBlob]) -> [String]? {
        _ = blobsByLabel
        guard ldr.mnemonic.lowercased() == "ldr" else { return nil }
        let adrpParts = adrp.operandText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard adrpParts.count == 2, let page = ReconstructionUtilities.parseHex(adrpParts[1]) else { return nil }
        let baseReg = adrpParts[0]
        let ldrParts = ldr.operandText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard ldrParts.count == 3 else { return nil }
        let dstReg = ldrParts[0]
        guard ldrParts[1].trimmingCharacters(in: CharacterSet(charactersIn: "[] ")) == baseReg else { return nil }
        let immText = ldrParts[2].trimmingCharacters(in: CharacterSet(charactersIn: "#] "))
        guard let offset = ReconstructionUtilities.parseHex(immText) else { return nil }
        let slot = page + offset
        guard let name = context.importNamesByAddress[slot] ?? context.symbolNamesByAddress[slot] else {
            return nil
        }
        let cName = ReconstructionUtilities.cFunctionName(for: name)
        let sym = ReconstructionUtilities.asmSymbolName(cName, format: context.image.format)
        if context.image.format == .machO {
            return ["adrp \(baseReg), \(sym)@GOTPAGE",
                    "ldr \(dstReg), [\(baseReg), \(sym)@GOTPAGEOFF]"]
        }
        return ["adrp \(baseReg), :got:\(sym)",
                "ldr \(dstReg), [\(baseReg), #:got_lo12:\(sym)]"]
    }

    private static func rewriteARM64Adrp(_ ins: Instruction, context: Context,
                                         result: inout RepairedFunction,
                                         blobsByLabel: inout [String: DataBlob]) -> String? {
        let parts = ins.operandText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let page = ReconstructionUtilities.parseHex(parts[1]) else { return nil }
        let register = parts[0]
        guard let section = section(containing: page, in: context.image), !section.isExecutable else {
            return nil
        }
        let label = ReconstructionUtilities.pageLabel(for: page)
        let length = min(4096, Int(section.address.value + section.size - page))
        guard length > 0, let bytes = readBytes(at: page, length: length, context: context) else {
            return nil
        }
        addBlob(DataBlob(label: label, bytes: bytes, kind: .page, pageAligned: true), into: &blobsByLabel)
        return "adrp \(register), \(label)@PAGE"
    }

    private static func rewriteARM64Adr(_ ins: Instruction, context: Context,
                                        result: inout RepairedFunction,
                                        blobsByLabel: inout [String: DataBlob]) -> String? {
        let parts = ins.operandText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let target = ReconstructionUtilities.parseHex(parts[1]) else { return nil }
        let register = parts[0]
        if let fnName = context.functionCNames[target] {
            return "adr \(register), \(ReconstructionUtilities.asmSymbolName(fnName, format: context.image.format))"
        }
        guard let section = section(containing: target, in: context.image), !section.isExecutable else {
            return nil
        }
        let label = ReconstructionUtilities.dataLabel(for: target)
        if context.stringAddresses.contains(target) {
            if let bytes = readCString(at: target, context: context) {
                addBlob(DataBlob(label: label, bytes: bytes, kind: .cstring), into: &blobsByLabel)
            }
        } else if let bytes = readBytes(at: target, length: 64, context: context) {
            addBlob(DataBlob(label: label, bytes: bytes, kind: .bytes), into: &blobsByLabel)
        } else {
            return nil
        }
        return "adr \(register), \(label)"
    }
}
