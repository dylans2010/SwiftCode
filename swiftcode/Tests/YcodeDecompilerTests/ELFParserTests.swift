import XCTest
@testable import YcodeDecompiler






final class ELFParserTests: XCTestCase {

    private static func u16(_ v: UInt16) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private static func u32(_ v: UInt32) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private static func u64(_ v: UInt64) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }

    private static func cstr(_ s: String, into table: inout [UInt8]) -> UInt32 {
        let base = UInt32(table.count)
        table += Array(s.utf8) + [0]
        return base
    }

    
    
    
    
    
    
    
    
    private static func fixture() -> Data {
        var strtab: [UInt8] = [0]        
        let mainName = cstr("_main", into: &strtab)   
        var shstr = [UInt8]()
        _ = cstr("", into: &shstr)
        let nText = cstr(".text", into: &shstr)
        let nSymtab = cstr(".symtab", into: &shstr)
        let nStrtab = cstr(".strtab", into: &shstr)
        let nShstr = cstr(".shstrtab", into: &shstr)

        
        var symtab = [UInt8](repeating: 0, count: 24)
        symtab += u32(mainName)
        symtab += [0x12]                 
        symtab += [0x00]                 
        symtab += u16(1)                 
        symtab += u64(0x400100)          
        symtab += u64(16)                

        var b = [UInt8]()
        b.reserveCapacity(0x300)

        
        b += [0x7F, 0x45, 0x4C, 0x46,    
              0x02,                     
              0x01,                     
              0x01,                     
              0x00]                     
        b += [UInt8](repeating: 0, count: 8)   
        b += u16(2)                     
        b += u16(62)                    
        b += u32(1)                     
        b += u64(0x400100)              
        b += u64(64)                    
        b += u64(0x1C0)                 
        b += u32(0)                     
        b += u16(64)                    
        b += u16(56)                    
        b += u16(1)                     
        b += u16(64)                    
        b += u16(5)                     
        b += u16(4)                     

        
        b += u32(1)                     
        b += u32(5)                     
        b += u64(0)                     
        b += u64(0x400000)              
        b += u64(0x400000)              
        b += u64(0x300)                 
        b += u64(0x300)                 
        b += u64(0x1000)                

        b += [UInt8](repeating: 0, count: 0x100 - b.count)

        
        b += [0x55, 0x48, 0x89, 0xE5, 0x48, 0x83, 0xEC, 0x10,
              0x48, 0x89, 0x7D, 0xF8, 0xC9, 0xC3, 0x90, 0x90]

        b += [UInt8](repeating: 0, count: 0x120 - b.count)
        b += symtab                                     
        b += [UInt8](repeating: 0, count: 0x160 - b.count)
        b += strtab                                     
        b += [UInt8](repeating: 0, count: 0x170 - b.count)
        b += shstr                                       
        b += [UInt8](repeating: 0, count: 0x1C0 - b.count)

        
        func shdr(_ name: UInt32, _ type: UInt32, _ flags: UInt64, _ addr: UInt64,
                  _ offset: UInt64, _ size: UInt64, _ link: UInt32, _ info: UInt32,
                  _ align: UInt64, _ entsize: UInt64) {
            b += u32(name); b += u32(type); b += u64(flags); b += u64(addr)
            b += u64(offset); b += u64(size)
            b += u32(link); b += u32(info)
            b += u64(align); b += u64(entsize)
        }
        shdr(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)                             
        shdr(nText, 1, 0x6, 0x400100, 0x100, 16, 0, 0, 16, 0)          
        shdr(nSymtab, 2, 0, 0, 0x120, 48, 3, 1, 8, 24)                 
        shdr(nStrtab, 3, 0, 0, 0x160, UInt64(strtab.count), 0, 0, 1, 0) 
        shdr(nShstr, 3, 0, 0, 0x170, UInt64(shstr.count), 0, 0, 1, 0)   

        return Data(b)
    }

    

    private func writeTemp(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("elf-test-\(UUID().uuidString).bin")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    
    
    private func parser() throws -> any BinaryParser {
        guard let p = BinaryLoader.parsers.first(where: { $0.format == .elf }) else {
            throw XCTSkip("ELF binary parser not registered in BinaryLoader.parsers")
        }
        return p
    }

    private func parse(_ url: URL) throws -> BinaryImage {
        let p = try parser()
        let identity = BinaryIdentity(
            sha256: "test", originalFileName: url.lastPathComponent,
            originalLocation: url.path, fileSize: 0x300,
            format: .elf, architecture: .x86_64)
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

    

    func testDetectELFSignature() throws {
        let url = try writeTemp(Self.fixture())
        let detection = try BinaryDetector.detect(url: url)
        XCTAssertEqual(detection.format, .elf)
        XCTAssertFalse(detection.isUniversal)
    }

    func testDetectSlicesFindsOneSlice() async throws {
        let url = try writeTemp(Self.fixture())
        let slices = try await BinaryLoader().detectSlices(at: url)
        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices.first?.architecture, .x86_64)
    }

    func testParseHeaderFields() throws {
        let url = try writeTemp(Self.fixture())
        let image = try parse(url)
        XCTAssertEqual(image.format, .elf)
        XCTAssertEqual(image.architecture, .x86_64)
        XCTAssertEqual(image.entryPoint?.value, 0x400100)
        XCTAssertFalse(image.isEncrypted)
    }

    func testParseSegments() throws {
        let url = try writeTemp(Self.fixture())
        let image = try parse(url)
        XCTAssertFalse(image.segments.isEmpty)
        let load = image.segments.first { $0.vmAddress == 0x400000 }
        XCTAssertNotNil(load, "expected a LOAD segment at 0x400000, got \(image.segments)")
    }

    func testParseSymbols() throws {
        let url = try writeTemp(Self.fixture())
        let image = try parse(url)
        XCTAssertTrue(image.symbols.contains { $0.name.contains("main") },
                      "expected a symbol named _main, got \(image.symbols.map(\.name))")
    }
}
