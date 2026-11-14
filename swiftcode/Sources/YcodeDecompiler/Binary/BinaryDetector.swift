import Foundation
import CryptoKit


public enum BinaryDetector {
    public struct Detection: Sendable {
        public var format: BinaryFormat
        public var isUniversal: Bool
        
        public var firstSliceOffset: UInt64
    }

    
    public static func detect(url: URL) throws -> Detection {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let head = try handle.read(upToCount: 4096) ?? Data()
        guard head.count >= 4 else {
            throw DecompilerError.malformedBinary("file too small to contain a header")
        }

        
        let magic32 = head.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        let magic32BE = head.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self).bigEndian }
        _ = magic32BE
        
        let be = head.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        if be == 0xCAFEBABE || be == 0xCAFEBABF {
            return Detection(format: .machO, isUniversal: true, firstSliceOffset: 0)
        }
        let le = head.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
        switch le {
        case 0xFEEDFACE, 0xFEEDFACF, 0xCEFAEDFE, 0xCFFAEDFE:
            return Detection(format: .machO, isUniversal: false, firstSliceOffset: 0)
        default: break
        }
        
        if head.prefix(4) == Data([0x7F, 0x45, 0x4C, 0x46]) {
            return Detection(format: .elf, isUniversal: false, firstSliceOffset: 0)
        }
        
        if head.count >= 0x40 {
            let peOff = head.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x3C, as: UInt32.self) }
            let off = Int(peOff)
            if off + 4 <= head.count, head[off..<off+4] == Data([0x50, 0x45, 0x00, 0x00]) {
                return Detection(format: .pe, isUniversal: false, firstSliceOffset: 0)
            }
        }
        if head.prefix(2) == Data([0x4D, 0x5A]) {
            
            return Detection(format: .pe, isUniversal: false, firstSliceOffset: 0)
        }
        throw DecompilerError.unsupportedFormat("unrecognized file signature")
    }

    
    public static func sha256(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
