import Foundation

/// A decoded machine-code instruction.
public struct Instruction: Identifiable, Hashable, Sendable, Codable {
    public enum Classification: String, Sendable, Codable {
        case normal, branch, call, returnInstruction, invalid, unknown, data
    }

    public var id: String { "ins-\(address.hexString)" }
    public var address: DecompilerAddress
    public var rawBytes: Data
    public var size: Int
    public var mnemonic: String
    public var operands: [InstructionOperand]
    public var operandText: String
    public var comment: String?
    public var classification: Classification
    public var branchTarget: DecompilerAddress?
    /// Symbol/label name at this address, if any.
    public var label: String?
    /// Number of incoming references (for xref gutters).
    public var referenceCount: Int
    public var source: AnalysisSource

    public init(address: DecompilerAddress, rawBytes: Data, size: Int, mnemonic: String,
                operands: [InstructionOperand] = [], operandText: String = "",
                comment: String? = nil, classification: Classification = .normal,
                branchTarget: DecompilerAddress? = nil, label: String? = nil,
                referenceCount: Int = 0, source: AnalysisSource) {
        self.address = address
        self.rawBytes = rawBytes
        self.size = size
        self.mnemonic = mnemonic
        self.operands = operands
        self.operandText = operandText
        self.comment = comment
        self.classification = classification
        self.branchTarget = branchTarget
        self.label = label
        self.referenceCount = referenceCount
        self.source = source
    }

    /// "mnemonic operands" display form.
    public var text: String {
        operandText.isEmpty ? mnemonic : "\(mnemonic) \(operandText)"
    }
}

public enum InstructionOperand: Hashable, Sendable, Codable {
    case register(String)
    case immediate(Int64)
    case memory(base: String?, displacement: Int64, index: String?, scale: Int)
    case address(DecompilerAddress)
    case label(String)
    case other(String)

    public var text: String {
        switch self {
        case .register(let r): return r
        case .immediate(let v): return String(v)
        case .memory(let base, let disp, let index, let scale):
            var s = "["
            if let b = base { s += b }
            if let i = index { s += " + \(i)" + (scale > 1 ? " * \(scale)" : "") }
            if disp != 0 || (base == nil && index == nil) { s += " \(disp >= 0 ? "+" : "")\(disp)" }
            return s + "]"
        case .address(let a): return a.description
        case .label(let l): return l
        case .other(let t): return t
        }
    }
}

/// One basic block of a function's control-flow graph.
public struct BasicBlock: Identifiable, Hashable, Sendable, Codable {
    public var id: String { "bb-\(startAddress.hexString)" }
    public var startAddress: DecompilerAddress
    public var endAddress: DecompilerAddress
    public var instructions: [DecompilerAddress]
    /// Successor block start addresses; empty for exit blocks.
    public var successors: [DecompilerAddress]
    /// Predecessor block start addresses.
    public var predecessors: [DecompilerAddress]
    public var isEntry: Bool
    public var isExit: Bool
    /// Conditional branch kind when the block ends in a conditional branch.
    public var branchKind: BranchKind?

    public enum BranchKind: String, Sendable, Codable { case conditional, unconditional, return_, indirect }
}
