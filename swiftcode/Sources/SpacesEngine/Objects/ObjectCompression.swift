import Foundation
#if canImport(Compression)
import Compression
#endif

public enum ObjectCompression {
    public static let algorithmName = "zlib"

    public static var isAvailable: Bool {
#if canImport(Compression)
        return true
#else
        return false
#endif
    }

    public static func compress(_ data: Data) -> Data? {
#if canImport(Compression)
        guard !data.isEmpty else { return Data() }
        var capacity = data.count + 1024
        for _ in 0..<5 {
            var output = Data(count: capacity)
            let written = output.withUnsafeMutableBytes { dst in
                data.withUnsafeBytes { src in
                    compression_encode_buffer(
                        dst.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        capacity,
                        src.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        data.count,
                        nil,
                        COMPRESSION_ZLIB)
                }
            }
            if written > 0 {
                output.removeLast(capacity - written)
                return output
            }
            capacity *= 2
        }
        return nil
#else
        return nil
#endif
    }

    public static func decompress(_ data: Data, expectedLength: Int) throws -> Data {
#if canImport(Compression)
        guard expectedLength > 0 else {
            throw SpacesError.objectCorrupt("compressed object declares no uncompressed content")
        }
        guard !data.isEmpty else {
            throw SpacesError.objectCorrupt("compressed object payload is empty")
        }
        var output = Data(count: expectedLength)
        let decoded = output.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_decode_buffer(
                    dst.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    expectedLength,
                    src.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB)
            }
        }
        guard decoded == expectedLength else {
            throw SpacesError.objectCorrupt("compressed object failed integrity check: decoded \(decoded) bytes, expected \(expectedLength)")
        }
        return output
#else
        _ = data
        _ = expectedLength
        throw SpacesError.unsupportedOperation("compressed object requires the Compression framework, which is unavailable on this platform")
#endif
    }

    public static func encodeForStorage(_ data: Data) -> (stored: Data, compressed: Bool) {
        guard let compressed = compress(data), compressed.count < data.count else {
            return (data, false)
        }
        return (compressed, true)
    }
}
