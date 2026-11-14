import XCTest
@testable import YcodeDecompiler










final class MachOParserTests: XCTestCase {

    private static let textAddr: UInt64 = 0x100000100
    private static let textSize: UInt64 = 16
    private static let symoff: UInt64 = 0x120
    private static let nsyms: UInt32 = 1
    private static let stroff: UInt64 = 0x130
    private static let strsize: UInt32 = 7          
    private static let sizeofcmds = 72 + 80 + 24   
    private static let fileSize = 0x140

    private static func u32(_ v: UInt32) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private static func u64(_ v: UInt64) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }

    private static func name16(_ s: String) -> [UInt8] {
        var bytes = Array(s.utf8.prefix(16))
        bytes += [UInt8](repeating: 0, count: 16 - bytes.count)
        return bytes
    }

    private static func fixture() -> Data {
        var b = [UInt8]()
        b.reserveCapacity(fileSize)

        
        b += u32(0xFEEDFACF)               
        b += u32(0x0100000C)               
        b += u32(0)                        
        b += u32(2)                        
        b += u32(2)                        
        b += u32(UInt32(sizeofcmds))       
        b += u32(0)                        
        b += u32(0)                        

        
        b += u32(0x19)
        b += u32(72 + 80)                  
        b += name16("__TEXT")
        b += u64(0x100000000)              
        b += u64(0x1000)                   
        b += u64(0)                        
        b += u64(0x200)                    
        b += u32(5)                        
        b += u32(5)                        
        b += u32(1)                        
        b += u32(0)                        

        
        b += name16("__text")
        b += name16("__TEXT")
        b += u64(textAddr)                 
        b += u64(textSize)                 
        b += u32(0x100)                    
        b += u32(4)                        
        b += u32(0); b += u32(0)           
        b += u32(0x80000400)               
        b += u32(0); b += u32(0); b += u32(0)  

        
        b += u32(0x2)
        b += u32(24)                       
        b += u32(UInt32(symoff))           
        b += u32(nsyms)                     
        b += u32(UInt32(stroff))           
        b += u32(strsize)                  

        
        b += [UInt8](repeating: 0, count: 0x100 - b.count)

        
        b += [0xFD, 0x7B, 0xBF, 0xA9,      
              0xFD, 0x03, 0x00, 0x91,      
              0xC0, 0x03, 0x5F, 0xD6]      
        b += [UInt8](repeating: 0, count: 0x120 - b.count)

        
        b += u32(1)
        b += [0x0F]                        
        b += [0x01]                        
        b += [0x00, 0x00]                  
        b += u64(textAddr)                 

        b += [UInt8](repeating: 0, count: 0x130 - b.count)
        b += [0x00] + Array("_main".utf8) + [0x00]   
        b += [UInt8](repeating: 0, count: fileSize - b.count)
        return Data(b)
    }

    

    private func writeTemp(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("macho-test-\(UUID().uuidString).bin")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func parser() throws -> any BinaryParser {
        guard let p = BinaryLoader.parsers.first(where: { $0.format == .machO }) else {
            throw XCTSkip("Mach-O binary parser not registered in BinaryLoader.parsers")
        }
        return p
    }

    private func parse(_ url: URL) throws -> BinaryImage {
        let p = try parser()
        let identity = BinaryIdentity(
            sha256: "test", originalFileName: url.lastPathComponent,
            originalLocation: url.path, fileSize: Int64(Self.fileSize),
            format: .machO, architecture: .arm64)
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

    

    func testDetectMachOSignature() throws {
        let url = try writeTemp(Self.fixture())
        let detection = try BinaryDetector.detect(url: url)
        XCTAssertEqual(detection.format, .machO)
        XCTAssertFalse(detection.isUniversal)
    }

    func testDetectSlicesFindsOneSlice() async throws {
        let url = try writeTemp(Self.fixture())
        let slices = try await BinaryLoader().detectSlices(at: url)
        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices.first?.architecture, .arm64)
    }

    func testParseHeaderFields() throws {
        let url = try writeTemp(Self.fixture())
        let image = try parse(url)
        XCTAssertEqual(image.format, .machO)
        XCTAssertEqual(image.architecture, .arm64)
        XCTAssertFalse(image.fileType.isEmpty)
    }

    func testParseSegmentsAndSections() throws {
        let url = try writeTemp(Self.fixture())
        let image = try parse(url)
        let names = image.segments.map(\.name)
        XCTAssertTrue(names.contains("__TEXT"), "expected __TEXT, got \(names)")
        let text = image.segments.flatMap(\.sections).first { $0.name == "__text" }
        XCTAssertNotNil(text)
        XCTAssertEqual(text?.address.value, Self.textAddr)
        XCTAssertTrue(text?.isExecutable ?? false)
    }

    func testParseSymbols() throws {
        let url = try writeTemp(Self.fixture())
        let image = try parse(url)
        XCTAssertTrue(image.symbols.contains { $0.name.contains("main") },
                      "expected _main symbol, got \(image.symbols.map(\.name))")
    }
}
