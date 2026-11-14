import Foundation


public enum ObjectType: String, Codable, Sendable, CaseIterable {
    case blob
    case tree
    case commit
    case tag
    case snapshot
}




public struct StoredObject: Sendable {
    public let type: ObjectType
    public let payload: Data
}

enum ObjectCoding {
    static let magic: [UInt8] = [0x53, 0x50, 0x43, 0x4f] 

    static func tag(for type: ObjectType) -> UInt8 {
        switch type {
        case .blob: return 1
        case .tree: return 2
        case .commit: return 3
        case .tag: return 4
        case .snapshot: return 5
        }
    }

    static func type(forTag tag: UInt8) -> ObjectType? {
        switch tag {
        case 1: return .blob
        case 2: return .tree
        case 3: return .commit
        case 4: return .tag
        case 5: return .snapshot
        default: return nil
        }
    }

    
    static func encode(_ object: StoredObject) -> Data {
        var data = Data()
        data.append(contentsOf: magic)
        data.append(tag(for: object.type))
        var length = UInt64(object.payload.count).bigEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        data.append(object.payload)
        return data
    }

    
    
    static func decode(_ data: Data) throws -> StoredObject {
        guard data.count >= 13 else { throw SpacesError.invalidObject("object too short") }
        guard Array(data.prefix(4)) == magic else { throw SpacesError.invalidObject("bad object magic") }
        guard let type = type(forTag: data[4]) else { throw SpacesError.invalidObject("unknown object tag") }
        let length = data[5..<13].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard length == UInt64(data.count - 13) else {
            throw SpacesError.invalidObject("object length mismatch")
        }
        return StoredObject(type: type, payload: data.subdata(in: 13..<data.count))
    }
}
