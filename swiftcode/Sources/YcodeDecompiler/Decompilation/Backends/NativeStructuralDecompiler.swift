import Foundation

public struct NativeStructuralDecompiler: DecompilerProvider {
    public static let engineID = "swiftcode-native"

    public enum Dialect: String, CaseIterable, Sendable {
        case c = "C"
        case swift = "Swift Pseudocode"
        case ir = "Lifted IR"
    }

    public let id = Self.engineID
    public let displayName = "SwiftCode Structural Lifter"
    public let version: String? = "2.0"
    public let isPrimary = false

    public init() {}

    public var supportedFormats: Set<BinaryFormat> { [.machO, .elf, .pe] }

    public var supportedArchitectures: Set<BinaryArchitecture> {
        [.arm64, .arm64_32, .x86_64, .i386, .armv7, .armv7s, .riscv64]
    }

    public func isAvailable() async -> Bool { true }

    public func availabilityDetail() async -> String {
        "Built-in multi-architecture structural lifter (ARM64 & x86_64 CFG + data-flow recovery)."
    }

    public func capabilities(for image: BinaryImage) -> DecompilerCapabilitiesSet {
        _ = image
        return [.decompileFunction, .decompileBatch, .typeRecovery, .controlFlowGraph]
    }

    public func decompile(_ request: DecompilationRequest,
                          progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> DecompilationResult {
        let results = try await decompileBatch([request], progress: progress)
        guard let first = results.first else {
            throw DecompilerError.engineFailure("Native structural lifter returned no result")
        }
        return first
    }

    public func decompileBatch(_ requests: [DecompilationRequest],
                               progress: (@Sendable (AnalysisProgress) -> Void)?) async throws -> [DecompilationResult] {
        guard let firstReq = requests.first else { return [] }
        let url = URL(fileURLWithPath: firstReq.imagePath)
        let loader = BinaryLoader(registry: .shared)
        let container = try await loader.loadContainer(at: url)
        let sliceIdx = container.slices.first(where: { $0.architecture == firstReq.architecture })?.index
            ?? container.slices.first?.index ?? 0
        let image = try await loader.parseSlice(container: container, sliceIndex: sliceIdx, sourceURL: url)
        let disassembler = await EngineRegistry.shared.resolveDisassembler(for: image)

        var allFunctions = FunctionDiscovery.discover(
            image: image,
            provenance: AnalysisSource(provenance: .formatParser, pass: "native-decompile")
        )
        var out: [DecompilationResult] = []
        out.reserveCapacity(requests.count)

        for (index, req) in requests.enumerated() {
            try Task.checkCancellation()
            progress?(AnalysisProgress(
                stage: .decompiling,
                fraction: Double(index) / Double(max(requests.count, 1)),
                message: "Lifting \(req.functionName ?? req.functionAddress.hexString)",
                itemsProcessed: index,
                itemsTotal: requests.count
            ))
            let endAddr: DecompilerAddress = {
                if let hex = req.options["endAddress"],
                   let v = UInt64(hex.replacingOccurrences(of: "0x", with: ""), radix: 16),
                   v > req.functionAddress.value {
                    return DecompilerAddress(virtual: v)
                }
                if let known = allFunctions.first(where: { $0.address.value == req.functionAddress.value }),
                   let knownEnd = known.endAddress, knownEnd.value > req.functionAddress.value {
                    return knownEnd
                }
                return DecompilerAddress(virtual: req.functionAddress.value + 256)
            }()
            let fnIns: [Instruction]
            if let disassembler {
                fnIns = (try? await disassembler.disassemble(
                    image: image, start: req.functionAddress, end: endAddr, progress: nil
                )) ?? []
            } else {
                fnIns = []
            }
            let fn = allFunctions.first { $0.address.value == req.functionAddress.value }
                ?? DecompilerFunction(
                    address: req.functionAddress,
                    endAddress: endAddr,
                    size: endAddr.value - req.functionAddress.value,
                    name: req.functionName ?? "sub_\(String(req.functionAddress.value, radix: 16))",
                    kind: .discovered,
                    source: AnalysisSource(provenance: .engine, engineID: Self.engineID)
                )
            if !allFunctions.contains(where: { $0.address.value == fn.address.value }) {
                allFunctions.append(fn)
            }
            let dialect = req.options["dialect"].flatMap(Dialect.init(rawValue:)) ?? .c
            out.append(Self.decompileFunction(fn, instructions: fnIns, image: image, allFunctions: allFunctions, dialect: dialect))
        }
        return out
    }

    public static func decompileFunction(
        _ fn: DecompilerFunction,
        instructions: [Instruction],
        image: BinaryImage?,
        allFunctions: [DecompilerFunction] = [],
        dialect: Dialect = .c
    ) -> DecompilationResult {
        let start = fn.address.value
        let end = fn.endAddress?.value ?? (fn.size > 0 ? start + fn.size : (instructions.last.map { $0.address.value + UInt64(max($0.size, 4)) } ?? start + 4))
        let scoped = instructions
            .filter { $0.address.value >= start && $0.address.value < max(end, start + 1) }
            .sorted { $0.address.value < $1.address.value }
        let effectiveIns = scoped.isEmpty ? instructions.sorted { $0.address.value < $1.address.value } : scoped

        let ctx = LiftingContext(function: fn, image: image, allFunctions: allFunctions)
        var lifter = FunctionLifter(context: ctx, architecture: image?.architecture ?? .arm64, dialect: dialect)
        return lifter.decompile(instructions: effectiveIns)
    }
}

private struct LiftingContext {
    let function: DecompilerFunction
    let image: BinaryImage?
    var stringsByAddress: [UInt64: String] = [:]
    var symbolsByAddress: [UInt64: String] = [:]

    init(function: DecompilerFunction, image: BinaryImage?, allFunctions: [DecompilerFunction]) {
        self.function = function
        self.image = image
        if let image {
            for s in image.strings {
                stringsByAddress[s.address.value] = s.text
            }
            for sym in image.symbols {
                if let a = sym.address?.value {
                    symbolsByAddress[a] = SymbolDemangler.demangle(sym.effectiveName)
                }
            }
            for imp in image.imports {
                if let a = imp.address?.value {
                    symbolsByAddress[a] = SymbolDemangler.demangle(imp.name)
                }
            }
            for exp in image.exports {
                symbolsByAddress[exp.address.value] = SymbolDemangler.demangle(exp.name)
            }
        }
        for f in allFunctions {
            if symbolsByAddress[f.address.value] == nil {
                symbolsByAddress[f.address.value] = SymbolDemangler.demangle(f.originalName ?? f.name)
            }
        }
    }

    func resolveAddress(_ addr: UInt64) -> ResolvedReference? {
        if let str = stringsByAddress[addr] {
            return .stringLiteral(str)
        }
        if let sym = symbolsByAddress[addr] {
            return .symbol(sym)
        }
        return nil
    }
}

private enum ResolvedReference {
    case stringLiteral(String)
    case symbol(String)
}

private struct LiftedStatement {
    var address: UInt64
    var text: String
}

private struct FunctionLifter {
    let context: LiftingContext
    let architecture: BinaryArchitecture
    let dialect: NativeStructuralDecompiler.Dialect

    private var regValues: [String: String] = [:]
    private var adrpPages: [String: UInt64] = [:]
    private var wideImmediates: [String: UInt64] = [:]
    private var lastCmpLHS: String = "v0"
    private var lastCmpRHS: String = "0"
    private var readArgIndices: Set<Int> = []
    private var writtenRegs: Set<String> = []
    private var stackLocals: [Int64: (name: String, type: String)] = [:]
    private var tempCounter = 1
    private var returnsValue = false
    private var warnings: [String] = []

    init(context: LiftingContext, architecture: BinaryArchitecture, dialect: NativeStructuralDecompiler.Dialect) {
        self.context = context
        self.architecture = architecture
        self.dialect = dialect
    }

    mutating func decompile(instructions: [Instruction]) -> DecompilationResult {
        let rawName = context.function.originalName ?? context.function.name
        let demangled = SymbolDemangler.demangle(rawName)
        let cName = ReconstructionUtilities.cFunctionName(for: rawName)

        guard !instructions.isEmpty else {
            let stub = dialect == .swift
                ? "func \(cName)() {\n    // No decoded instructions in range \(context.function.address.hexString)\n}\n"
                : "void \(cName)(void) {\n    /* No decoded instructions in range \(context.function.address.hexString) */\n}\n"
            return DecompilationResult(
                functionAddress: context.function.address,
                functionName: cName,
                pseudocode: stub,
                signature: "void \(cName)(void)",
                warnings: ["No instructions decoded for function range."],
                engineID: NativeStructuralDecompiler.engineID,
                engineVersion: "2.0"
            )
        }

        if dialect == .ir {
            return emitLiftedIR(instructions: instructions, cName: cName, demangled: demangled)
        }

        let blocks = ControlFlowAnalyzer.basicBlocks(instructions: instructions, functionStart: context.function.address)
        let insByAddr = Dictionary(uniqueKeysWithValues: instructions.map { ($0.address.value, $0) })

        var liftedBlocks: [UInt64: [LiftedStatement]] = [:]
        var blockCond: [UInt64: (cond: String, trueTarget: UInt64, falseTarget: UInt64?)] = [:]
        var unconditionalNext: [UInt64: UInt64] = [:]

        for block in blocks {
            regValues.removeAll()
            adrpPages.removeAll()
            var stmts: [LiftedStatement] = []
            let blockIns = block.instructions.compactMap { insByAddr[$0.value] }
            for (idx, ins) in blockIns.enumerated() {
                let isLast = idx == blockIns.count - 1
                if let branch = liftInstruction(ins, isBlockTerminator: isLast, statements: &stmts) {
                    switch branch {
                    case .conditional(let cond, let t):
                        let fallthroughAddr = block.successors.first { $0.value != t }?.value
                        blockCond[block.startAddress.value] = (cond, t, fallthroughAddr)
                    case .unconditional(let t):
                        unconditionalNext[block.startAddress.value] = t
                    }
                }
            }
            if blockCond[block.startAddress.value] == nil && unconditionalNext[block.startAddress.value] == nil,
               !block.isExit, let fall = block.successors.first?.value {
                unconditionalNext[block.startAddress.value] = fall
            }
            liftedBlocks[block.startAddress.value] = stmts
        }

        let maxArg = readArgIndices.max() ?? -1
        let paramCount = min(max(maxArg + 1, 0), 8)
        let params: [String] = (0..<paramCount).map { "int64_t arg\($0)" }
        let retType = returnsValue ? "int64_t" : "void"
        let cSig = "\(retType) \(cName)(\(params.isEmpty ? "void" : params.joined(separator: ", ")))"

        var outLines: [String] = []
        var addressLineMap: [UInt64: Int] = [:]

        if demangled != rawName && demangled != cName {
            outLines.append("// Demangled: \(demangled)")
        }
        if dialect == .swift {
            let swiftParams = (0..<paramCount).map { "_ arg\($0): Int" }.joined(separator: ", ")
            let swiftRet = returnsValue ? " -> Int" : ""
            outLines.append("func \(cName)(\(swiftParams))\(swiftRet) {")
        } else {
            outLines.append("\(cSig) {")
        }

        let sortedLocals = stackLocals.sorted { $0.key < $1.key }
        for (_, local) in sortedLocals {
            if dialect == .swift {
                outLines.append("    var \(local.name): Int = 0")
            } else {
                outLines.append("    \(local.type) \(local.name) = 0;")
            }
        }
        if !sortedLocals.isEmpty { outLines.append("") }

        var visited: Set<UInt64> = []
        let orderedStarts = blocks.map(\.startAddress.value)
        let blockSet = Set(orderedStarts)
        let backEdgeHeaders: Set<UInt64> = Set(blocks.flatMap { b in
            b.successors.map(\.value).filter { $0 <= b.startAddress.value && blockSet.contains($0) }
        })

        func emitBlockChain(_ addr: UInt64, indent: Int, stopAt: UInt64?) {
            var current: UInt64? = addr
            let pad = { (d: Int) in String(repeating: "    ", count: d) }
            while let cur = current, cur != stopAt, blockSet.contains(cur) {
                if visited.contains(cur) {
                    if !backEdgeHeaders.contains(cur) {
                        outLines.append("\(pad(indent))goto loc_\(String(cur, radix: 16));")
                    }
                    return
                }
                visited.insert(cur)

                let isLoopHeader = backEdgeHeaders.contains(cur)
                var bodyIndent = indent
                if isLoopHeader {
                    outLines.append("\(pad(indent))while (true) {")
                    bodyIndent += 1
                } else if blocks.first(where: { $0.startAddress.value == cur })?.predecessors.count ?? 0 > 1 && cur != orderedStarts.first {
                    outLines.append("\(pad(max(0, indent - 1)))loc_\(String(cur, radix: 16)):")
                }

                for stmt in liftedBlocks[cur] ?? [] {
                    let lineNum = outLines.count + 1
                    if addressLineMap[stmt.address] == nil {
                        addressLineMap[stmt.address] = lineNum
                    }
                    let formatted = dialect == .swift ? swiftify(stmt.text) : stmt.text
                    outLines.append("\(pad(bodyIndent))\(formatted)")
                }

                if let condInfo = blockCond[cur] {
                    let t = condInfo.trueTarget
                    let f = condInfo.falseTarget
                    if t == cur {
                        let condText = dialect == .swift ? condInfo.cond : "(\(condInfo.cond))"
                        outLines.append("\(pad(bodyIndent))if !\(condText) { break\(dialect == .swift ? "" : ";") }")
                        current = f
                        if isLoopHeader { outLines.append("\(pad(indent))}") }
                        continue
                    }
                    if backEdgeHeaders.contains(t) && visited.contains(t) {
                        let inverted = invertCondition(condInfo.cond)
                        if dialect == .swift {
                            outLines.append("\(pad(bodyIndent))if \(inverted) { break }")
                        } else {
                            outLines.append("\(pad(bodyIndent))if (\(inverted)) break;")
                        }
                        if isLoopHeader { outLines.append("\(pad(indent))}") }
                        current = f
                        continue
                    }

                    let joinPoint = findMergeBlock(t, f, blocks: blocks)
                    let condHeader = dialect == .swift ? "if \(condInfo.cond) {" : "if (\(condInfo.cond)) {"
                    outLines.append("\(pad(bodyIndent))\(condHeader)")
                    emitBlockChain(t, indent: bodyIndent + 1, stopAt: joinPoint ?? f)
                    if let f, f != joinPoint, !visited.contains(f) {
                        outLines.append("\(pad(bodyIndent))} else {")
                        emitBlockChain(f, indent: bodyIndent + 1, stopAt: joinPoint)
                    }
                    outLines.append("\(pad(bodyIndent))}")
                    if isLoopHeader { outLines.append("\(pad(indent))}") }
                    current = joinPoint ?? (f != nil && !visited.contains(f!) ? f : nil)
                } else {
                    let next = unconditionalNext[cur]
                    if let next, backEdgeHeaders.contains(next), visited.contains(next) {
                        if isLoopHeader { outLines.append("\(pad(indent))}") }
                        return
                    }
                    if isLoopHeader { outLines.append("\(pad(indent))}") }
                    current = next
                }
            }
        }

        if let entry = orderedStarts.first {
            emitBlockChain(entry, indent: 1, stopAt: nil)
        }
        for start in orderedStarts where !visited.contains(start) {
            emitBlockChain(start, indent: 1, stopAt: nil)
        }

        outLines.append("}")

        return DecompilationResult(
            functionAddress: context.function.address,
            functionName: cName,
            pseudocode: outLines.joined(separator: "\n") + "\n",
            signature: cSig,
            parameters: params,
            returnType: retType,
            localVariables: sortedLocals.map { "\($0.value.type) \($0.value.name)" },
            addressLineMap: addressLineMap,
            warnings: warnings,
            engineID: NativeStructuralDecompiler.engineID,
            engineVersion: "2.0"
        )
    }

    private func emitLiftedIR(instructions: [Instruction], cName: String, demangled: String) -> DecompilationResult {
        var lines: [String] = ["// Lifted Low-Level IR for \(demangled) (\(cName))"]
        var map: [UInt64: Int] = [:]
        var stmts: [LiftedStatement] = []
        var copy = self
        for ins in instructions {
            _ = copy.liftInstruction(ins, isBlockTerminator: false, statements: &stmts)
        }
        for s in stmts {
            map[s.address] = lines.count + 1
            lines.append(String(format: "/* 0x%llx */  %@", s.address, s.text))
        }
        return DecompilationResult(
            functionAddress: context.function.address,
            functionName: cName,
            pseudocode: lines.joined(separator: "\n") + "\n",
            signature: "void \(cName)(void)",
            addressLineMap: map,
            engineID: NativeStructuralDecompiler.engineID,
            engineVersion: "2.0"
        )
    }

    private enum TerminatingBranch {
        case conditional(String, UInt64)
        case unconditional(UInt64)
    }

    private mutating func liftInstruction(
        _ ins: Instruction,
        isBlockTerminator: Bool,
        statements: inout [LiftedStatement]
    ) -> TerminatingBranch? {
        let m = ins.mnemonic.lowercased()
        let ops = splitOperands(ins.operandText)
        let addr = ins.address.value

        if ["nop", "pacibsp", "paciasp", "autibsp", "autiasp", "bti", "endbr64", "endbr32", " hint"].contains(m) {
            return nil
        }

        if architecture == .x86_64 || architecture == .i386 {
            return liftX86(ins, m: m, ops: ops, isBlockTerminator: isBlockTerminator, statements: &statements)
        }
        return liftARM64(ins, m: m, ops: ops, isBlockTerminator: isBlockTerminator, statements: &statements)
    }

    private mutating func liftARM64(
        _ ins: Instruction,
        m: String,
        ops: [String],
        isBlockTerminator: Bool,
        statements: inout [LiftedStatement]
    ) -> TerminatingBranch? {
        let addr = ins.address.value

        if (m == "stp" || m == "ldp"), ops.count >= 3,
           (ops[0].contains("29") || ops[0] == "fp" || ops[1].contains("30") || ops[1] == "lr") {
            return nil
        }
        if (m == "add" || m == "sub"), ops.count >= 2, (ops[0] == "sp" || ops[0] == "x29" || ops[0] == "fp"),
           (ops[1] == "sp" || ops[1] == "x29" || ops[1] == "fp") {
            return nil
        }

        if m.hasPrefix("ret") {
            if let r0 = regValues["x0"] ?? regValues["w0"] {
                returnsValue = true
                statements.append(.init(address: addr, text: "return \(r0);"))
            } else {
                statements.append(.init(address: addr, text: "return;"))
            }
            return nil
        }

        if m == "adrp" || m == "adr", ops.count >= 2 {
            let dst = canonicalReg(ops[0])
            if let page = parseHexOrInt(ops[1]) {
                let resolved = m == "adrp" && (page & 0xFFF) != 0 ? page : page
                adrpPages[dst] = resolved
                if let ref = context.resolveAddress(resolved) {
                    regValues[dst] = formatResolved(ref)
                }
            }
            writtenRegs.insert(dst)
            return nil
        }

        if m == "movz" || m == "movn", ops.count >= 2 {
            let dst = canonicalReg(ops[0])
            let imm = UInt64(bitPattern: parseSigned(ops[1]) ?? 0)
            let shift = ops.count >= 3 ? parseShift(ops[2]) : 0
            let val = m == "movn" ? ~(imm << shift) : (imm << shift)
            wideImmediates[dst] = val
            regValues[dst] = formatImmediate(Int64(bitPattern: val))
            writtenRegs.insert(dst)
            return nil
        }

        if m == "movk", ops.count >= 2 {
            let dst = canonicalReg(ops[0])
            let imm = UInt64(bitPattern: parseSigned(ops[1]) ?? 0) & 0xFFFF
            let shift = ops.count >= 3 ? parseShift(ops[2]) : 0
            let prev = wideImmediates[dst] ?? 0
            let next = (prev & ~(0xFFFF << shift)) | (imm << shift)
            wideImmediates[dst] = next
            if let ref = context.resolveAddress(next) {
                regValues[dst] = formatResolved(ref)
            } else {
                regValues[dst] = String(format: "0x%llx", next)
            }
            writtenRegs.insert(dst)
            return nil
        }

        if m == "mov", ops.count >= 2 {
            let dst = canonicalReg(ops[0])
            let rhs = readExpr(ops[1])
            regValues[dst] = rhs
            writtenRegs.insert(dst)
            return nil
        }

        if ["add", "adds", "sub", "subs", "mul", "sdiv", "udiv", "and", "ands", "orr", "eor", "lsl", "lsr", "asr"].contains(m), ops.count >= 3 {
            let dst = canonicalReg(ops[0])
            let srcReg = canonicalReg(ops[1])
            if (m == "add" || m == "sub"), let page = adrpPages[srcReg], let off = parseSigned(ops[2]) {
                let full = m == "add" ? page &+ UInt64(bitPattern: off) : page &- UInt64(bitPattern: off)
                adrpPages.removeValue(forKey: dst)
                if let ref = context.resolveAddress(full) {
                    regValues[dst] = formatResolved(ref)
                    writtenRegs.insert(dst)
                    return nil
                }
            }
            let a = readExpr(ops[1])
            let b = readExpr(ops[2])
            let opSym: String = switch m {
            case "add", "adds": "+"
            case "sub", "subs": "-"
            case "mul": "*"
            case "sdiv", "udiv": "/"
            case "and", "ands": "&"
            case "orr": "|"
            case "eor": "^"
            case "lsl": "<<"
            case "lsr", "asr": ">>"
            default: "+"
            }
            let expr = "(\(a) \(opSym) \(b))"
            if m.hasSuffix("s") {
                lastCmpLHS = expr
                lastCmpRHS = "0"
            }
            regValues[dst] = expr
            writtenRegs.insert(dst)
            return nil
        }

        if (m == "madd" || m == "msub"), ops.count >= 4 {
            let dst = canonicalReg(ops[0])
            let a = readExpr(ops[1]), b = readExpr(ops[2]), c = readExpr(ops[3])
            regValues[dst] = m == "madd" ? "(\(c) + (\(a) * \(b)))" : "(\(c) - (\(a) * \(b)))"
            writtenRegs.insert(dst)
            return nil
        }

        if (m == "csel" || m == "csinc"), ops.count >= 4 {
            let dst = canonicalReg(ops[0])
            let a = readExpr(ops[1])
            let b = m == "csinc" ? "(\(readExpr(ops[2])) + 1)" : readExpr(ops[2])
            let cond = conditionString(code: ops[3])
            regValues[dst] = "(\(cond) ? \(a) : \(b))"
            writtenRegs.insert(dst)
            return nil
        }

        if m == "cset", ops.count >= 2 {
            let dst = canonicalReg(ops[0])
            regValues[dst] = "(\(conditionString(code: ops[1])) ? 1 : 0)"
            writtenRegs.insert(dst)
            return nil
        }

        if m == "sxtw" || m == "uxtb" || m == "uxth" || m == "sxtb" || m == "sxth", ops.count >= 2 {
            let dst = canonicalReg(ops[0])
            let cast = m == "sxtw" ? "(int32_t)" : (m == "uxtb" ? "(uint8_t)" : (m == "uxth" ? "(uint16_t)" : "(int16_t)"))
            regValues[dst] = "\(cast)\(readExpr(ops[1]))"
            writtenRegs.insert(dst)
            return nil
        }

        if m == "cmp" || m == "cmn" || m == "fcmp", ops.count >= 2 {
            lastCmpLHS = readExpr(ops[0])
            lastCmpRHS = m == "cmn" ? "-\(readExpr(ops[1]))" : readExpr(ops[1])
            return nil
        }

        if m == "tst", ops.count >= 2 {
            lastCmpLHS = "(\(readExpr(ops[0])) & \(readExpr(ops[1])))"
            lastCmpRHS = "0"
            return nil
        }

        if m.hasPrefix("ldr") || m.hasPrefix("ldur"), ops.count >= 2 {
            let dst = canonicalReg(ops[0])
            let mem = ops[1...].joined(separator: ", ")
            if let pageLoad = resolvePageLoad(mem) {
                regValues[dst] = pageLoad
                writtenRegs.insert(dst)
                return nil
            }
            if let stackVar = resolveStackSlot(mem, cType: cTypeForLoadStore(m)) {
                regValues[dst] = stackVar
            } else {
                let addrExpr = memoryAddressExpr(mem)
                regValues[dst] = "*(\(cTypeForLoadStore(m)) *)(\(addrExpr))"
            }
            writtenRegs.insert(dst)
            return nil
        }

        if m.hasPrefix("str") || m.hasPrefix("stur"), ops.count >= 2 {
            let val = readExpr(ops[0])
            let mem = ops[1...].joined(separator: ", ")
            if let stackVar = resolveStackSlot(mem, cType: cTypeForLoadStore(m)) {
                statements.append(.init(address: addr, text: "\(stackVar) = \(val);"))
            } else {
                let addrExpr = memoryAddressExpr(mem)
                statements.append(.init(address: addr, text: "*(\(cTypeForLoadStore(m)) *)(\(addrExpr)) = \(val);"))
            }
            return nil
        }

        if m == "stp", ops.count >= 3 {
            let v1 = readExpr(ops[0]), v2 = readExpr(ops[1])
            let mem = ops[2...].joined(separator: ", ")
            let base = memoryAddressExpr(mem)
            statements.append(.init(address: addr, text: "*(int64_t *)(\(base)) = \(v1);"))
            statements.append(.init(address: addr, text: "*(int64_t *)(\(base) + 8) = \(v2);"))
            return nil
        }

        if m == "bl" || m == "blr" || (m == "b" && !isLocalTarget(ins.branchTarget)) {
            let callee = resolveCallee(ins: ins, ops: ops)
            let callArgs = collectARM64CallArgs(callee: callee)
            let callExpr = formatCall(callee: callee, args: callArgs)
            if m == "b" {
                returnsValue = true
                statements.append(.init(address: addr, text: "return \(callExpr);"))
                return nil
            }
            let tmp = "v\(tempCounter)"
            tempCounter += 1
            statements.append(.init(address: addr, text: "int64_t \(tmp) = \(callExpr);"))
            regValues["x0"] = tmp
            writtenRegs.insert("x0")
            for clobber in ["x1", "x2", "x3", "x4", "x5", "x6", "x7"] {
                regValues.removeValue(forKey: clobber)
            }
            return nil
        }

        if (m == "cbz" || m == "cbnz"), ops.count >= 2, let target = ins.branchTarget?.value ?? parseHexOrInt(ops[1]) {
            let cond = "\(readExpr(ops[0])) \(m == "cbz" ? "==" : "!=") 0"
            return .conditional(cond, target)
        }

        if (m == "tbz" || m == "tbnz"), ops.count >= 3, let target = ins.branchTarget?.value ?? parseHexOrInt(ops[2]) {
            let bit = parseSigned(ops[1]) ?? 0
            let cond = "((\(readExpr(ops[0])) >> \(bit)) & 1) \(m == "tbz" ? "==" : "!=") 0"
            return .conditional(cond, target)
        }

        if m.hasPrefix("b."), let target = ins.branchTarget?.value ?? ops.first.flatMap(parseHexOrInt) {
            let cc = String(m.dropFirst(2))
            return .conditional(conditionString(code: cc), target)
        }

        if m == "b", let target = ins.branchTarget?.value ?? ops.first.flatMap(parseHexOrInt) {
            if isBlockTerminator { return .unconditional(target) }
        }

        statements.append(.init(address: addr, text: "/* \(ins.text) */"))
        return nil
    }

    private mutating func liftX86(
        _ ins: Instruction,
        m: String,
        ops: [String],
        isBlockTerminator: Bool,
        statements: inout [LiftedStatement]
    ) -> TerminatingBranch? {
        let addr = ins.address.value
        if m == "push" || m == "pop" || m == "leave" { return nil }
        if (m == "mov" || m == "movq"), ops.count == 2,
           (ops[0].contains("rbp") || ops[0].contains("ebp")) && (ops[1].contains("rsp") || ops[1].contains("esp")) {
            return nil
        }
        if m == "sub" || m == "add", ops.count == 2, ops[0].contains("rsp") || ops[1].contains("rsp") {
            return nil
        }
        if m.hasPrefix("ret") {
            if let r = regValues["rax"] {
                returnsValue = true
                statements.append(.init(address: addr, text: "return \(r);"))
            } else {
                statements.append(.init(address: addr, text: "return;"))
            }
            return nil
        }
        if m == "xor" || m == "xorl" || m == "xorq", ops.count == 2, canonicalX86(ops[0]) == canonicalX86(ops[1]) {
            let dst = canonicalX86(ops[0])
            regValues[dst] = "0"
            writtenRegs.insert(dst)
            return nil
        }
        if m.hasPrefix("mov") || m.hasPrefix("lea"), ops.count == 2 {
            let att = ops[0].hasPrefix("%") || ops[0].hasPrefix("$") || ops[1].hasPrefix("%")
            let srcRaw = att ? ops[0] : ops[1]
            let dstRaw = att ? ops[1] : ops[0]
            if dstRaw.contains("[") || dstRaw.contains("(") {
                let val = readX86Expr(srcRaw)
                if let slot = resolveX86StackSlot(dstRaw) {
                    statements.append(.init(address: addr, text: "\(slot) = \(val);"))
                } else {
                    statements.append(.init(address: addr, text: "*(int64_t *)(\(dstRaw)) = \(val);"))
                }
            } else {
                let dst = canonicalX86(dstRaw)
                regValues[dst] = readX86Expr(srcRaw)
                writtenRegs.insert(dst)
            }
            return nil
        }
        if ["add", "addl", "addq", "sub", "subl", "subq", "imul", "imull", "imulq", "and", "or", "shl", "shr", "sar"].contains(m), ops.count >= 2 {
            let att = ops[0].hasPrefix("%") || ops[0].hasPrefix("$") || ops[1].hasPrefix("%")
            let srcRaw = att ? ops[0] : ops[1]
            let dstRaw = att ? ops[1] : ops[0]
            let dst = canonicalX86(dstRaw)
            let sym = m.hasPrefix("add") ? "+" : (m.hasPrefix("sub") ? "-" : (m.hasPrefix("imul") ? "*" : (m.hasPrefix("and") ? "&" : (m.hasPrefix("or") ? "|" : (m.hasPrefix("shl") ? "<<" : ">>")))))
            regValues[dst] = "(\(readX86Expr(dstRaw)) \(sym) \(readX86Expr(srcRaw)))"
            writtenRegs.insert(dst)
            return nil
        }
        if m.hasPrefix("cmp") || m.hasPrefix("test"), ops.count == 2 {
            let att = ops[0].hasPrefix("%") || ops[0].hasPrefix("$") || ops[1].hasPrefix("%")
            let a = readX86Expr(att ? ops[1] : ops[0])
            let b = readX86Expr(att ? ops[0] : ops[1])
            if m.hasPrefix("test") {
                lastCmpLHS = a == b ? a : "(\(a) & \(b))"
                lastCmpRHS = "0"
            } else {
                lastCmpLHS = a
                lastCmpRHS = b
            }
            return nil
        }
        if m.hasPrefix("call") {
            let callee = resolveCallee(ins: ins, ops: ops)
            let args = collectX86CallArgs()
            let tmp = "v\(tempCounter)"; tempCounter += 1
            statements.append(.init(address: addr, text: "int64_t \(tmp) = \(callee)(\(args.joined(separator: ", ")));"))
            regValues["rax"] = tmp
            writtenRegs.insert("rax")
            return nil
        }
        if m == "jmp", let t = ins.branchTarget?.value ?? ops.first.flatMap(parseHexOrInt) {
            if isBlockTerminator { return .unconditional(t) }
        }
        if m.hasPrefix("j"), let t = ins.branchTarget?.value ?? ops.first.flatMap(parseHexOrInt) {
            let cc = String(m.dropFirst())
            return .conditional(conditionString(code: cc), t)
        }
        statements.append(.init(address: addr, text: "/* \(ins.text) */"))
        return nil
    }

    private func splitOperands(_ text: String) -> [String] {
        var result: [String] = []
        var cur = ""
        var depth = 0
        for ch in text {
            if ch == "[" || ch == "(" { depth += 1; cur.append(ch) }
            else if ch == "]" || ch == ")" { depth = max(0, depth - 1); cur.append(ch) }
            else if ch == "," && depth == 0 {
                result.append(cur.trimmingCharacters(in: .whitespaces))
                cur = ""
            } else {
                cur.append(ch)
            }
        }
        let tail = cur.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    private func canonicalReg(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if t == "wzr" || t == "xzr" { return "xzr" }
        if t == "fp" { return "x29" }
        if t == "lr" { return "x30" }
        if t.hasPrefix("w"), let n = Int(t.dropFirst()) { return "x\(n)" }
        return t
    }

    private func canonicalX86(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: CharacterSet(charactersIn: " %")).lowercased()
        switch t {
        case "eax", "ax", "al": return "rax"
        case "edi", "di", "dil": return "rdi"
        case "esi", "si", "sil": return "rsi"
        case "edx", "dx", "dl": return "rdx"
        case "ecx", "cx", "cl": return "rcx"
        case "r8d", "r8w", "r8b": return "r8"
        case "r9d", "r9w", "r9b": return "r9"
        default: return t
        }
    }

    private mutating func readExpr(_ operand: String) -> String {
        let trimmed = operand.trimmingCharacters(in: .whitespaces)
        if trimmed == "xzr" || trimmed == "wzr" { return "0" }
        if let imm = parseSigned(trimmed) { return formatImmediate(imm) }
        let reg = canonicalReg(trimmed)
        if let val = regValues[reg] { return val }
        if reg.hasPrefix("x"), let idx = Int(reg.dropFirst()), (0...7).contains(idx), !writtenRegs.contains(reg) {
            readArgIndices.insert(idx)
            return "arg\(idx)"
        }
        return reg
    }

    private mutating func readX86Expr(_ operand: String) -> String {
        let t = operand.trimmingCharacters(in: .whitespaces)
        let stripped = t.hasPrefix("$") ? String(t.dropFirst()) : t
        if let imm = parseSigned(stripped) { return formatImmediate(imm) }
        if let slot = resolveX86StackSlot(t) { return slot }
        let reg = canonicalX86(t)
        if let val = regValues[reg] { return val }
        let argMap = ["rdi": 0, "rsi": 1, "rdx": 2, "rcx": 3, "r8": 4, "r9": 5]
        if let idx = argMap[reg], !writtenRegs.contains(reg) {
            readArgIndices.insert(idx)
            return "arg\(idx)"
        }
        return reg
    }

    private func resolvePageLoad(_ mem: String) -> String? {
        let inner = mem.trimmingCharacters(in: CharacterSet(charactersIn: "[]! "))
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let base = parts.first else { return nil }
        let reg = canonicalReg(base)
        guard let page = adrpPages[reg] else { return nil }
        let off = parts.count >= 2 ? (parseSigned(parts[1]) ?? 0) : 0
        let target = page &+ UInt64(bitPattern: off)
        if let ref = context.resolveAddress(target) {
            return formatResolved(ref)
        }
        return nil
    }

    private mutating func resolveStackSlot(_ mem: String, cType: String) -> String? {
        let inner = mem.trimmingCharacters(in: CharacterSet(charactersIn: "[]! "))
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let base = parts.first?.lowercased(), base == "sp" || base == "x29" || base == "fp" else { return nil }
        let off = parts.count >= 2 ? (parseSigned(parts[1]) ?? 0) : 0
        let key = (base == "sp" ? 10_000 : 0) + off
        if let existing = stackLocals[key] { return existing.name }
        let suffix = String(abs(off), radix: 16)
        let name = off < 0 ? "local_\(suffix)" : "stack_\(suffix)"
        stackLocals[key] = (name, cType)
        return name
    }

    private mutating func resolveX86StackSlot(_ mem: String) -> String? {
        guard mem.contains("rbp") || mem.contains("ebp") else { return nil }
        let nums = mem.components(separatedBy: CharacterSet(charactersIn: "-+()[]% "))
            .compactMap { parseSigned($0) }
        let off = -(nums.first ?? 8)
        if let existing = stackLocals[off] { return existing.name }
        let name = "local_\(String(abs(off), radix: 16))"
        stackLocals[off] = (name, "int64_t")
        return name
    }

    private mutating func memoryAddressExpr(_ mem: String) -> String {
        let inner = mem.trimmingCharacters(in: CharacterSet(charactersIn: "[]! "))
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = parts.first else { return "0" }
        let base = readExpr(first)
        if parts.count >= 2 {
            let off = readExpr(parts[1])
            return off == "0" ? base : "\(base) + \(off)"
        }
        return base
    }

    private func cTypeForLoadStore(_ m: String) -> String {
        if m.hasSuffix("b") { return "uint8_t" }
        if m.hasSuffix("h") { return "uint16_t" }
        if m.hasSuffix("sw") { return "int32_t" }
        return "int64_t"
    }

    private func conditionString(code: String) -> String {
        switch code.lowercased() {
        case "eq", "e", "z": return "\(lastCmpLHS) == \(lastCmpRHS)"
        case "ne", "nz": return "\(lastCmpLHS) != \(lastCmpRHS)"
        case "lt", "l": return "\(lastCmpLHS) < \(lastCmpRHS)"
        case "le": return "\(lastCmpLHS) <= \(lastCmpRHS)"
        case "gt", "g": return "\(lastCmpLHS) > \(lastCmpRHS)"
        case "ge": return "\(lastCmpLHS) >= \(lastCmpRHS)"
        case "lo", "cc", "b": return "(uint64_t)\(lastCmpLHS) < (uint64_t)\(lastCmpRHS)"
        case "ls", "be": return "(uint64_t)\(lastCmpLHS) <= (uint64_t)\(lastCmpRHS)"
        case "hi", "a": return "(uint64_t)\(lastCmpLHS) > (uint64_t)\(lastCmpRHS)"
        case "hs", "cs", "ae": return "(uint64_t)\(lastCmpLHS) >= (uint64_t)\(lastCmpRHS)"
        case "mi", "s": return "\(lastCmpLHS) < 0"
        case "pl", "ns": return "\(lastCmpLHS) >= 0"
        default: return "\(lastCmpLHS) != \(lastCmpRHS)"
        }
    }

    private func invertCondition(_ cond: String) -> String {
        for (a, b) in [(" == ", " != "), (" != ", " == "), (" <= ", " > "), (" >= ", " < "), (" < ", " >= "), (" > ", " <= ")] {
            if let r = cond.range(of: a) {
                var copy = cond
                copy.replaceSubrange(r, with: b)
                return copy
            }
        }
        return "!(\(cond))"
    }

    private func isLocalTarget(_ target: DecompilerAddress?) -> Bool {
        guard let t = target?.value else { return false }
        let start = context.function.address.value
        let end = context.function.endAddress?.value ?? (start + max(context.function.size, 256))
        return t >= start && t < end
    }

    private func resolveCallee(ins: Instruction, ops: [String]) -> String {
        if let comment = ins.comment {
            let trimmed = comment.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("symbol stub for:") {
                let sym = trimmed.replacingOccurrences(of: "symbol stub for:", with: "").trimmingCharacters(in: .whitespaces)
                return SymbolDemangler.demangle(sym)
            }
        }
        if let label = ins.label, !label.isEmpty {
            return SymbolDemangler.demangle(label)
        }
        if let target = ins.branchTarget?.value, let ref = context.resolveAddress(target) {
            if case .symbol(let s) = ref { return s }
        }
        if let first = ops.first {
            if let addr = parseHexOrInt(first), let ref = context.resolveAddress(addr), case .symbol(let s) = ref {
                return s
            }
            let reg = canonicalReg(first)
            if let val = regValues[reg] { return val }
            return SymbolDemangler.demangle(first)
        }
        return "sub_unknown"
    }

    private func collectARM64CallArgs(callee: String) -> [String] {
        var args: [String] = []
        for i in 0..<6 {
            if let v = regValues["x\(i)"] {
                args.append(v)
            } else {
                break
            }
        }
        if callee.contains("objc_msgSend$"), args.isEmpty {
            return ["arg0"]
        }
        return args
    }

    private func collectX86CallArgs() -> [String] {
        var args: [String] = []
        for r in ["rdi", "rsi", "rdx", "rcx", "r8", "r9"] {
            if let v = regValues[r] { args.append(v) } else { break }
        }
        return args
    }

    private func formatCall(callee: String, args: [String]) -> String {
        if let dollar = callee.range(of: "objc_msgSend$") {
            let sel = String(callee[dollar.upperBound...])
            let recv = args.first ?? "self"
            let rest = args.dropFirst()
            if rest.isEmpty {
                return "objc_msgSend(\(recv), \"\(sel)\")"
            }
            return "objc_msgSend(\(recv), \"\(sel)\", \(rest.joined(separator: ", ")))"
        }
        let safe = callee.contains(" ") || callee.contains("(")
            ? "/* \(callee) */ " + ReconstructionUtilities.cFunctionName(for: callee)
            : ReconstructionUtilities.cFunctionName(for: callee)
        return "\(safe)(\(args.joined(separator: ", ")))"
    }

    private func formatResolved(_ ref: ResolvedReference) -> String {
        switch ref {
        case .stringLiteral(let s):
            let escaped = s
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            return "\"\(escaped)\""
        case .symbol(let sym):
            return "&\(ReconstructionUtilities.cFunctionName(for: sym))"
        }
    }

    private func parseShift(_ op: String) -> UInt64 {
        let nums = op.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(UInt64.init)
        return nums.first ?? 0
    }

    private func parseHexOrInt(_ raw: String) -> UInt64? {
        var s = raw.trimmingCharacters(in: CharacterSet(charactersIn: " #$\t"))
        if s.hasPrefix("0x") || s.hasPrefix("0X") {
            return UInt64(s.dropFirst(2), radix: 16)
        }
        if s.allSatisfy({ $0.isHexDigit }) && s.count >= 6 {
            return UInt64(s, radix: 16)
        }
        return UInt64(s)
    }

    private func parseSigned(_ raw: String) -> Int64? {
        let s = raw.trimmingCharacters(in: CharacterSet(charactersIn: " #$\t"))
        if s.hasPrefix("-0x") || s.hasPrefix("-0X") {
            return UInt64(s.dropFirst(3), radix: 16).map { -Int64(bitPattern: $0) }
        }
        if s.hasPrefix("0x") || s.hasPrefix("0X") {
            return UInt64(s.dropFirst(2), radix: 16).map { Int64(bitPattern: $0) }
        }
        return Int64(s)
    }

    private func formatImmediate(_ v: Int64) -> String {
        if abs(v) < 4096 { return "\(v)" }
        return v < 0 ? String(format: "-0x%llx", -v) : String(format: "0x%llx", v)
    }

    private func findMergeBlock(_ a: UInt64, _ b: UInt64?, blocks: [BasicBlock]) -> UInt64? {
        guard let b else { return nil }
        let byAddr = Dictionary(uniqueKeysWithValues: blocks.map { ($0.startAddress.value, $0) })
        let aSuccs = Set((byAddr[a]?.successors ?? []).map(\.value))
        if aSuccs.contains(b) { return b }
        let bSuccs = Set((byAddr[b]?.successors ?? []).map(\.value))
        return aSuccs.intersection(bSuccs).min()
    }

    private func swiftify(_ line: String) -> String {
        var s = line
        if s.hasSuffix(";") { s.removeLast() }
        if s.hasPrefix("int64_t ") {
            s = "let " + s.dropFirst("int64_t ".count)
        }
        return s
    }
}
