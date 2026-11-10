import Foundation

/// A basic block in the canonical IR: a maximal sequence of instructions
/// with a single entry and a single exit, plus successor/predecessor
/// block-start addresses.
public struct IRBasicBlock: Identifiable, Hashable, Sendable, Codable {
    /// Stable id: "bb-<startAddress hex>".
    public var id: String { "bb-\(String(startAddress, radix: 16))" }
    /// Virtual address of the first instruction.
    public var startAddress: UInt64
    /// Virtual address one past the last instruction.
    public var endAddress: UInt64
    /// Instructions in address order.
    public var instructions: [IRInstruction]
    /// Start addresses of successor blocks; empty for exit blocks.
    public var successors: [UInt64]
    /// Start addresses of predecessor blocks.
    public var predecessors: [UInt64]
    /// Whether this is the function's entry block.
    public var isEntry: Bool
    /// Whether control cannot fall through (return/throw tail).
    public var isExit: Bool
    /// Mnemonic of the terminating instruction, if any.
    public var terminator: String?

    public init(startAddress: UInt64, endAddress: UInt64,
                instructions: [IRInstruction], successors: [UInt64] = [],
                predecessors: [UInt64] = [], isEntry: Bool = false,
                isExit: Bool = false, terminator: String? = nil) {
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.instructions = instructions
        self.successors = successors
        self.predecessors = predecessors
        self.isEntry = isEntry
        self.isExit = isExit
        self.terminator = terminator
    }
}
