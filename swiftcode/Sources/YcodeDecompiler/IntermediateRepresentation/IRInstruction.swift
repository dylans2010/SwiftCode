import Foundation





public struct IRInstruction: Hashable, Sendable, Codable {
    
    public var address: UInt64
    
    public var mnemonic: String
    
    public var operandText: String
    
    public var operands: [String]
    
    public var rawBytesHex: String
    
    public var size: Int
    
    public var classification: String
    
    public var branchTarget: UInt64?
    
    public var comment: String?

    public init(address: UInt64, mnemonic: String, operandText: String = "",
                operands: [String] = [], rawBytesHex: String = "",
                size: Int = 0, classification: String = "normal",
                branchTarget: UInt64? = nil, comment: String? = nil) {
        self.address = address
        self.mnemonic = mnemonic
        self.operandText = operandText
        self.operands = operands
        self.rawBytesHex = rawBytesHex
        self.size = size
        self.classification = classification
        self.branchTarget = branchTarget
        self.comment = comment
    }

    
    public var text: String {
        operandText.isEmpty ? mnemonic : "\(mnemonic) \(operandText)"
    }

    
    public init(_ instruction: Instruction) {
        self.init(
            address: instruction.address.value,
            mnemonic: instruction.mnemonic,
            operandText: instruction.operandText,
            operands: instruction.operands.map(\.text),
            rawBytesHex: instruction.rawBytes.map { String(format: "%02x", $0) }.joined(),
            size: instruction.size,
            classification: instruction.classification.rawValue,
            branchTarget: instruction.branchTarget?.value,
            comment: instruction.comment)
    }
}
