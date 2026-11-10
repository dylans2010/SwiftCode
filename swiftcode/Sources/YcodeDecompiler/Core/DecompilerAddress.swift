import Foundation

/// A typed binary address. Virtual addresses and file offsets are never
/// treated as interchangeable: every address carries its `Kind`.
public struct DecompilerAddress: Hashable, Sendable, Codable, CustomStringConvertible {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        /// Address in the loaded image's virtual address space.
        case virtual
        /// Offset within the original file on disk.
        case fileOffset
        /// Offset relative to the start of a section.
        case sectionRelative
        /// Offset relative to the start of an image (slice) inside a container.
        case imageRelative
    }

    public var kind: Kind
    /// Raw numeric value. Width is implied by the owning architecture slice.
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

    /// Canonical hex string used in persistence and tool arguments.
    public var hexString: String { "0x" + String(value, radix: 16) }

    /// Parse "0x1234", "1234h"-free plain hex/decimal input. Returns nil on failure.
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
