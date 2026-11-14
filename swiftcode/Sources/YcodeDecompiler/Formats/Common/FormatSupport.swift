import Foundation




enum FormatByteOrder {
    case little
    case big
}




struct ByteCursor {
    var data: Data
    var offset: Int
    var order: FormatByteOrder

    init(_ data: Data, order: FormatByteOrder = .little, offset: Int = 0) {
        self.data = data
        self.offset = offset
        self.order = order
    }

    var remaining: Int { data.count - offset }
    var atEnd: Bool { offset >= data.count }

    mutating func skip(_ count: Int) throws {
        guard count >= 0, offset + count <= data.count else {
            throw DecompilerError.truncatedFile("cursor skip past end at \(offset)")
        }
        offset += count
    }

    mutating func u8() throws -> UInt8 {
        guard offset + 1 <= data.count else {
            throw DecompilerError.truncatedFile("u8 read past end at \(offset)")
        }
        defer { offset += 1 }
        return data[offset]
    }

    private mutating func rawBytes(_ count: Int) throws -> [UInt8] {
        guard count >= 0, offset + count <= data.count else {
            throw DecompilerError.truncatedFile("read of \(count) bytes past end at \(offset)")
        }
        defer { offset += count }
        return Array(data[offset..<(offset + count)])
    }

    mutating func u16() throws -> UInt16 {
        let b = try rawBytes(2)
        let v = UInt16(b[0]) | (UInt16(b[1]) << 8)
        return order == .big ? v.byteSwapped : v
    }

    mutating func u32() throws -> UInt32 {
        let b = try rawBytes(4)
        let v = UInt32(b[0]) | (UInt32(b[1]) << 8) | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 24)
        return order == .big ? v.byteSwapped : v
    }

    mutating func u64() throws -> UInt64 {
        let b = try rawBytes(8)
        var v: UInt64 = 0
        for i in 0..<8 { v |= UInt64(b[i]) << UInt64(8 * i) }
        return order == .big ? v.byteSwapped : v
    }

    
    mutating func i32() throws -> Int32 { Int32(bitPattern: try u32()) }
    mutating func i64() throws -> Int64 { Int64(bitPattern: try u64()) }

    mutating func bytes(_ count: Int) throws -> Data {
        Data(try rawBytes(count))
    }

    
    mutating func cstring() throws -> String {
        var out = [UInt8]()
        while true {
            let b = try u8()
            if b == 0 { break }
            out.append(b)
        }
        return String(decoding: out, as: UTF8.self)
    }

    
    mutating func uleb128() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            let b = try u8()
            result |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 { break }
            shift += 7
            guard shift < 64 else {
                throw DecompilerError.malformedBinary("ULEB128 overflow")
            }
        }
        return result
    }

    
    static func fixedString(_ bytes: Data) -> String {
        var out = [UInt8]()
        for b in bytes {
            if b == 0 { break }
            out.append(b)
        }
        return String(decoding: out, as: UTF8.self)
    }
}




func readFileRegion(url: URL, offset: UInt64, length: UInt64) throws -> Data {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    try handle.seek(toOffset: offset)
    return try handle.read(upToCount: Int(length)) ?? Data()
}

func fileSize(url: URL) throws -> UInt64 {
    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attrs[.size] as? NSNumber)?.uint64Value ?? 0
}


func unpackVersion(_ v: UInt32) -> String {
    "\(v >> 16).\((v >> 8) & 0xFF).\(v & 0xFF)"
}

extension Data {
    
    func hexDashedUUID() -> String {
        let hex = map { String(format: "%02X", $0) }.joined()
        let idx = [8, 12, 16, 20]
        var out = ""
        var last = 0
        for i in idx {
            out += String(hex[hex.index(hex.startIndex, offsetBy: last)..<hex.index(hex.startIndex, offsetBy: i)])
            out += "-"
            last = i
        }
        out += String(hex[hex.index(hex.startIndex, offsetBy: last)...])
        return out
    }
}
