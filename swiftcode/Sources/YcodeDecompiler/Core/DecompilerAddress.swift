import Foundation



public struct DecompilerAddress: Hashable, Sendable, Codable, CustomStringConvertible {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        
        case virtual
        
        case fileOffset
        
        case sectionRelative
        
        case imageRelative
    }

    public var kind: Kind
    
    public var value: UInt64

    public init(kind: Kind, value: UInt64) {
        self.kind = kind
        self.value = value
    }

    public init(virtual value: UInt64) { self.init(kind: .virtual, value: value) }
    public init(fileOffset value: UInt64) { self.init(kind: .fileOffset, value: value) }

    public var description: String {
        let digits = kind == .virtual ? 16 : 8
        return "0x" + String(value, radix: 16, uppercase: true)
            .leftPad(toLength: digits, withPad: "0")
    }

    
    public var hexString: String { "0x" + String(value, radix: 16) }

    
    public static func parse(_ text: String, defaultKind: Kind = .virtual) -> DecompilerAddress? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("0x") || t.hasPrefix("0X") { t.removeFirst(2) }
        guard let value = UInt64(t, radix: 16) ?? UInt64(t) else { return nil }
        return DecompilerAddress(kind: defaultKind, value: value)
    }

    public static func < (a: DecompilerAddress, b: DecompilerAddress) -> Bool {
        a.kind == b.kind && a.value < b.value
    }
}

extension String {
    func leftPad(toLength: Int, withPad: Character) -> String {
        count >= toLength ? self : String(repeating: withPad, count: toLength - count) + self
    }
}
