import Foundation



public struct IRFunction: Identifiable, Hashable, Sendable, Codable {
    
    public var id: String { "fn-\(String(address, radix: 16))" }
    
    public var address: UInt64
    
    public var endAddress: UInt64
    
    public var name: String
    
    public var instructions: [IRInstruction]
    
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
