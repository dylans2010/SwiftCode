import XCTest
@testable import YcodeDecompiler









final class PEParserTests: XCTestCase {

    private static func u16(_ v: UInt16) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private static func u32(_ v: UInt32) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private static func u64(_ v: UInt64) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }

    private static func build() -> Data {
        var b = [UInt8]()
        b.reserveCapacity(0x400)

        
        b += [0x4D, 0x5A]
        b += [UInt8](repeating: 0, count: 0x3C - 2)
        b += u32(0x80)
        b += [UInt8](repeating: 0, count: 0x80 - b.count)

        
        b += [0x50, 0x45, 0x00, 0x00]
        b += u16(0x8664); b += u16(1)
        b += u32(0); b += u32(0); b += u32(0)
        b += u16(0xF0); b += u16(0x0022)

        
        b += u16(0x20B)                   
        b += [0x0E, 0x00]                 
        b += u32(0x200)                   
        b += u32(0)                       
        b += u32(0)                       
        b += u32(0x1000)                  
        b += u32(0x1000)                  
        b += u64(0x140000000)             
        b += u32(0x1000)                  
        b += u32(0x200)                   
        b += [UInt8](repeating: 0, count: 12) 
        b += u32(0)                       
        b += u32(0x2000)                  
        b += u32(0x200)                   
        b += u32(0)                       
        b += u16(3)                       
        b += u16(0x8160)                  
        b += u64(0x100000)                
        b += u64(0x1000)                  
        b += u64(0x100000)                
        b += u64(0x1000)                  
        b += u32(0)                       
        b += u32(16)                      
        b += [UInt8](repeating: 0, count: 16 * 8)  

        
        b += [0x2E, 0x74, 0x65, 0x78, 0x74, 0x00, 0x00, 0x00]  
        b += u32(0x200)                   
        b += u32(0x1000)                  
        b += u32(0x200)                   
        b += u32(0x200)                   
        b += u32(0)                       
        b += u32(0)                       
        b += u16(0)                       
        b += u16(0)                       
        b += u32(0x60000020)              

        b += [UInt8](repeating: 0, count: 0x200 - b.count)
        
        b += [0x55, 0x48, 0x89, 0xE5, 0x48, 0x83, 0xEC, 0x20,
              0xB8, 0x2A, 0x00, 0x00, 0x00, 0x48, 0x83, 0xC4,
              0x20, 0x5D, 0xC3]
        b += [UInt8](repeating: 0, count: 0x400 - b.count)
        return Data(b)
    }

    

    private func writeTemp(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pe-test-\(UUID().uuidString).exe")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func parser() throws -> any BinaryParser {
        guard let p = BinaryLoader.parsers.first(where: { $0.format == .pe }) else {
            throw XCTSkip("PE binary parser not registered in BinaryLoader.parsers")
        }
        return p
    }

    private func parse(_ url: URL) throws -> BinaryImage {
        let p = try parser()
        let size = Int64(Self.build().count)
        let identity = BinaryIdentity(
            sha256: "test", originalFileName: url.lastPathComponent,
            originalLocation: url.path, fileSize: size,
            format: .pe, architecture: .x86_64)
        let provider: @Sendable (UInt64, UInt64) throws -> Data = { offset, length in
            let h = try FileHandle(forReadingFrom: url)
            defer { try? h.close() }
            try h.seek(toOffset: offset)
            guard let d = try h.read(upToCount: Int(length)), d.count == Int(length) else {
                throw DecompilerError.truncatedFile("short read at \(offset)")
            }
            return d
        }
        return try p.parse(url: url, sliceIndex: 0, identity: identity, byteProvider: provider)
    }

    

    func testDetectPESignature() throws {
        let url = try writeTemp(Self.build())
        let detection = try BinaryDetector.detect(url: url)
        XCTAssertEqual(detection.format, .pe)
        XCTAssertFalse(detection.isUniversal)
    }

    func testDetectSlicesFindsOneSlice() async throws {
        let url = try writeTemp(Self.build())
        let slices = try await BinaryLoader().detectSlices(at: url)
        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices.first?.architecture, .x86_64)
    }

    func testParseHeaderFields() throws {
        let url = try writeTemp(Self.build())
        let image = try parse(url)
        XCTAssertEqual(image.format, .pe)
        XCTAssertEqual(image.architecture, .x86_64)
        
        XCTAssertNotNil(image.entryPoint)
        XCTAssertFalse(image.isEncrypted)
    }

    func testParseSections() throws {
        let url = try writeTemp(Self.build())
        let image = try parse(url)
        let names = image.segments.flatMap { $0.sections.map(\.name) }
        XCTAssertTrue(names.contains(".text"), "expected .text section, got \(names)")
    }
}
