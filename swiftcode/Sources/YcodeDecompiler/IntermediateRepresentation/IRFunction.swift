import Foundation

/// A function in the canonical IR: entry address, extent, linear
/// instruction list and partitioned basic blocks.
public struct IRFunction: Identifiable, Hashable, Sendable, Codable {
    /// Stable id: "fn-<address hex>".
    public var id: String { "fn-\(String(address, radix: 16))" }
    /// Entry virtual address.
    public var address: UInt64
    /// Exclusive end address (0 when unknown).
    public var endAddress: UInt64
    /// Function name (user rename wins upstream).
    public var name: String
    /// All instructions in address order.
    public var instructions: [IRInstruction]
    /// Basic blocks partitioning `instructions`.
    public var basicBlocks: [IRBasicBlock]

    public init(address: UInt64, endAddress: UInt64 = 0, name: String,
                instructions: [IRInstruction] = [], basicBlocks: [IRBasicBlock] = []) {
        self.address = address
        self.endAddress = endAddress
        self.name = name
        self.instructions = instructions
        self.basicBlocks = basicBlocks
    }
}
