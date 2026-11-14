import Foundation




public struct IRBasicBlock: Identifiable, Hashable, Sendable, Codable {
    
    public var id: String { "bb-\(String(startAddress, radix: 16))" }
    
    public var startAddress: UInt64
    
    public var endAddress: UInt64
    
    public var instructions: [IRInstruction]
    
    public var successors: [UInt64]
    
    public var predecessors: [UInt64]
    
    public var isEntry: Bool
    
    public var isExit: Bool
    
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
