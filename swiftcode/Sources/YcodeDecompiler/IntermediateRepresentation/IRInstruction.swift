import Foundation

/// Canonical intermediate-representation instruction — the backend-
/// independent seam between disassembly/decompiler engines and analysis
/// passes. Deliberately minimal: address, mnemonic, operand text and
/// control-flow classification.
public struct IRInstruction: Hashable, Sendable, Codable {
    /// Virtual address of the instruction.
    public var address: UInt64
    /// Mnemonic as reported by the producing backend.
    public var mnemonic: String
    /// Full operand text (e.g. "x0, [sp, #0x10]").
    public var operandText: String
    /// Operand strings, when the backend structured them.
    public var operands: [String]
    /// Raw encoded bytes, hex-encoded.
    public var rawBytesHex: String
    /// Instruction length in bytes.
    public var size: Int
    /// Backend-reported classification (normal/branch/call/return/...).
    public var classification: String
    /// Branch target virtual address, if any.
    public var branchTarget: UInt64?
    /// User/backend comment attached to this address.
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

    /// "mnemonic operands" display form.
    public var text: String {
        operandText.isEmpty ? mnemonic : "\(mnemonic) \(operandText)"
    }

    /// Convert a decoded `Instruction` into IR form.
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
