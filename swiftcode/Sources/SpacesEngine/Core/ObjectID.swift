import Crypto
import Foundation



public struct ObjectID: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let hex: String

    public init(hex: String) {
        self.hex = hex.lowercased()
    }

    
    
    
    public static func compute(type: ObjectType, payload: Data) -> ObjectID {
        var hasher = SHA256()
        hasher.update(data: Data("spaces-object-v1\n".utf8))
        hasher.update(data: Data(type.rawValue.utf8))
        hasher.update(data: Data("\n\(payload.count)\n".utf8))
        hasher.update(data: payload)
        return ObjectID(hex: hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }

    
    public static func blob(_ data: Data) -> ObjectID {
        compute(type: .blob, payload: data)
    }

    
    public var objectPathComponents: (String, String) {
        let prefix = String(hex.prefix(2))
        let rest = String(hex.dropFirst(2))
        return (prefix, rest)
    }

    public var description: String { hex }

    public static func < (lhs: ObjectID, rhs: ObjectID) -> Bool { lhs.hex < rhs.hex }

    
    
    public static func resolve(_ text: String, in store: ObjectStore) throws -> ObjectID {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 64, let id = try? ObjectID(validating: trimmed) { return id }
        let matches = try store.existingIDs(matchingPrefix: trimmed)
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty { throw SpacesError.objectNotFound(trimmed) }
        throw SpacesError.ambiguousRevision(trimmed)
    }

    public init(validating hex: String) throws {
        let lower = hex.lowercased()
        guard lower.count == 64, lower.allSatisfy({ $0.isHexDigit }) else {
            throw SpacesError.invalidObject("malformed object id '\(hex)'")
        }
        self.hex = lower
    }
}
