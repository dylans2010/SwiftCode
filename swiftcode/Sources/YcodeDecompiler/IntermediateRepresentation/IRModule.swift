import Foundation

/// A canonical IR module: the backend-independent representation of an
/// analyzed slice. Future backends (additional disassemblers,
/// decompilers, analysis passes) convert their output into this form.
public struct IRModule: Sendable {
    /// Architecture of the source slice, when known.
    public var architecture: BinaryArchitecture?
    /// Functions in address order.
    public var functions: [IRFunction]
    /// Every instruction across all functions (sorted by address).
    public var instructions: [IRInstruction]

    public init(architecture: BinaryArchitecture? = nil, functions: [IRFunction] = []) {
        self.architecture = architecture
        self.functions = functions.sorted { $0.address < $1.address }
        self.instructions = functions.flatMap(\.instructions)
            .sorted { $0.address < $1.address }
    }

    /// Convert decoded `Instruction`s plus discovered `DecompilerFunction`s
    /// into canonical IR. Basic blocks are partitioned per function with a
    /// simple linear-sweep algorithm:
    ///   - a block starts at the function entry,
    ///   - at every instruction that is a branch target,
    ///   - immediately after any branch or return instruction.
    /// Successor edges are taken from decoded branch targets; a branch
    /// whose conditionality cannot be determined conservatively keeps
    /// both the target and fall-through successors.
    public static func from(instructions: [Instruction],
                            functions: [DecompilerFunction],
                            architecture: BinaryArchitecture? = nil) -> IRModule {
        let sorted = instructions.sorted { $0.address.value < $1.address.value }
        let sortedFunctions = functions.sorted { $0.address.value < $1.address.value }

        var irFunctions: [IRFunction] = []
        irFunctions.reserveCapacity(sortedFunctions.count)

        for (index, fn) in sortedFunctions.enumerated() {
            let start = fn.address.value
            let fallbackEnd = sortedFunctions
                .dropFirst(index + 1)
                .first?.address.value
                ?? (start + max(fn.size, 1))
            let end = fn.endAddress?.value ?? fallbackEnd

            let body = sorted.filter {
                $0.address.value >= start && $0.address.value < end
            }
            let irInstructions = body.map(IRInstruction.init)
            let blocks = partitionBlocks(irInstructions)
            irFunctions.append(IRFunction(
                address: start,
                endAddress: end,
                name: fn.name,
                instructions: irInstructions,
                basicBlocks: blocks))
        }
        return IRModule(architecture: architecture, functions: irFunctions)
    }

    /// Partition a function's instruction list into basic blocks.
    static func partitionBlocks(_ instructions: [IRInstruction]) -> [IRBasicBlock] {
        guard !instructions.isEmpty else { return [] }

        // Addresses that must begin a new block.
        var leaders = Set<UInt64>([instructions[0].address])
        for ins in instructions {
            if let target = ins.branchTarget { leaders.insert(target) }
            if ins.classification == "branch" || ins.classification == "returnInstruction" {
                // The instruction after a control transfer starts a block.
                if let next = instructions.first(where: { $0.address > ins.address }) {
                    leaders.insert(next.address)
                }
            }
        }
        let leaderList = leaders.sorted()

        // Group instructions into blocks.
        var rawBlocks: [(start: UInt64, end: UInt64, instructions: [IRInstruction])] = []
        var current: [IRInstruction] = []
        var currentStart: UInt64 = instructions[0].address
        for ins in instructions {
            if leaders.contains(ins.address), !current.isEmpty {
                rawBlocks.append((currentStart,
                                  current.last.map { $0.address + UInt64(max($0.size, 1)) } ?? currentStart,
                                  current))
                current = []
                currentStart = ins.address
            }
            current.append(ins)
        }
        if !current.isEmpty {
            rawBlocks.append((currentStart,
                              current.last.map { $0.address + UInt64(max($0.size, 1)) } ?? currentStart,
                              current))
        }

        let blockStartSet = Set(rawBlocks.map(\.start))
        var successors: [UInt64: [UInt64]] = [:]
        var predecessors: [UInt64: [UInt64]] = [:]

        for (i, block) in rawBlocks.enumerated() {
            guard let last = block.instructions.last else { continue }
            var succs: [UInt64] = []
            switch last.classification {
            case "returnInstruction":
                break // exit block: no successors
            case "branch":
                if let target = last.branchTarget, blockStartSet.contains(target) {
                    succs.append(target)
                }
                // Conditional branches also fall through; unconditional
                // ones don't. When we cannot tell, keep both.
                if !isUnconditionalBranch(mnemonic: last.mnemonic),
                   i + 1 < rawBlocks.count {
                    succs.append(rawBlocks[i + 1].start)
                } else if isUnconditionalBranch(mnemonic: last.mnemonic),
                          let target = last.branchTarget, !blockStartSet.contains(target) {
                    // Target outside known blocks: no local edge.
                }
            default:
                if i + 1 < rawBlocks.count { succs.append(rawBlocks[i + 1].start) }
            }
            // De-duplicate while preserving order.
            var seen = Set<UInt64>()
            successors[block.start] = succs.filter { seen.insert($0).inserted }
            for s in successors[block.start] ?? [] {
                predecessors[s, default: []].append(block.start)
            }
        }

        return rawBlocks.enumerated().map { index, block in
            let last = block.instructions.last
            return IRBasicBlock(
                startAddress: block.start,
                endAddress: block.end,
                instructions: block.instructions,
                successors: successors[block.start] ?? [],
                predecessors: predecessors[block.start] ?? [],
                isEntry: index == 0,
                isExit: last?.classification == "returnInstruction",
                terminator: last?.mnemonic)
        }
    }

    /// Heuristic: does this mnemonic denote an unconditional direct
    /// branch (jump) rather than a conditional branch? Conditional
    /// branches commonly carry a condition suffix ("b.eq", "je") or are
    /// drawn from a known conditional mnemonic set.
    static func isUnconditionalBranch(mnemonic: String) -> Bool {
        let m = mnemonic.lowercased()
        if m.contains(".") { return false } // e.g. "b.eq", "je.ne"
        let unconditional: Set<String> = [
            "jmp", "jmpq", "b", "bra", "br", "j",
            "ljmp", "fjmp"
        ]
        if unconditional.contains(m) { return true }
        let conditionalPrefixes = ["j", "b", "cb", "tb"]
        // Single-letter-ish conditional branches on ARM/x86 families.
        if conditionalPrefixes.contains(where: { m.hasPrefix($0) }) && m.count > 1 {
            return false
        }
        return false
    }
}
