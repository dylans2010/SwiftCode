import XCTest
@testable import YcodeDecompiler

/// Parses a hand-built, minimal ELF64 little-endian executable.
///
/// The fixture is assembled byte-by-byte below; it contains one PT_LOAD
/// program header, three real sections (.text, .symtab, .strtab) plus
/// .shstrtab, and one defined function symbol `_main`.
final class ELFParserTests: XCTestCase {

    private static func u16(_ v: UInt16) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private static func u32(_ v: UInt32) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private static func u64(_ v: UInt64) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }

    private static func cstr(_ s: String, into table: inout [UInt8]) -> UInt32 {
        let base = UInt32(table.count)
        table += Array(s.utf8) + [0]
        return base
    }

    /// Deterministic fixture. Absolute file offsets:
    ///   0x000 ELF header (64)
    ///   0x040 program header (56)
    ///   0x100 .text (16 bytes of x86-64)
    ///   0x120 .symtab (2 × Elf64_Sym = 48)
    ///   0x160 .strtab
    ///   0x170 .shstrtab
    ///   0x1C0 section headers (5 × 64 = 320) → file size 0x300
    private static func fixture() -> Data {
        var strtab: [UInt8] = [0]        // leading NUL so name offsets start at 1
        let mainName = cstr("_main", into: &strtab)   // == 1
        var shstr = [UInt8]()
        _ = cstr("", into: &shstr)
        let nText = cstr(".text", into: &shstr)
        let nSymtab = cstr(".symtab", into: &shstr)
        let nStrtab = cstr(".strtab", into: &shstr)
        let nShstr = cstr(".shstrtab", into: &shstr)

        // .symtab: null symbol + _main (STB_GLOBAL|STT_FUNC, shndx=1)
        var symtab = [UInt8](repeating: 0, count: 24)
        symtab += u32(mainName)
        symtab += [0x12]                 // st_info: bind=GLOBAL(1)<<4 | type=FUNC(2)
        symtab += [0x00]                 // st_other
        symtab += u16(1)                 // st_shndx → .text
        symtab += u64(0x400100)          // st_value
        symtab += u64(16)                // st_size

        var b = [UInt8]()
        b.reserveCapacity(0x300)

        // --- ELF header ---
        b += [0x7F, 0x45, 0x4C, 0x46,    // \x7FELF
              0x02,                     // ELFCLASS64
              0x01,                     // ELFDATA2LSB
              0x01,                     // EV_CURRENT
              0x00]                     // ELFOSABI_NONE
        b += [UInt8](repeating: 0, count: 8)   // e_ident padding
        b += u16(2)                     // e_type = ET_EXEC
        b += u16(62)                    // e_machine = EM_X86_64
        b += u32(1)                     // e_version
        b += u64(0x400100)              // e_entry → .text
        b += u64(64)                    // e_phoff
        b += u64(0x1C0)                 // e_shoff
        b += u32(0)                     // e_flags
        b += u16(64)                    // e_ehsize
        b += u16(56)                    // e_phentsize
        b += u16(1)                     // e_phnum
        b += u16(64)                    // e_shentsize
        b += u16(5)                     // e_shnum
        b += u16(4)                     // e_shstrndx → .shstrtab

        // --- Program header: one PT_LOAD covering the whole file ---
        b += u32(1)                     // p_type = PT_LOAD
        b += u32(5)                     // p_flags = PF_R | PF_X
        b += u64(0)                     // p_offset
        b += u64(0x400000)              // p_vaddr
        b += u64(0x400000)              // p_paddr
        b += u64(0x300)                 // p_filesz
        b += u64(0x300)                 // p_memsz
        b += u64(0x1000)                // p_align

        b += [UInt8](repeating: 0, count: 0x100 - b.count)

        // --- .text: push rbp; mov rbp,rsp; sub rsp,0x10; …; leave; ret; nop; nop ---
        b += [0x55, 0x48, 0x89, 0xE5, 0x48, 0x83, 0xEC, 0x10,
              0x48, 0x89, 0x7D, 0xF8, 0xC9, 0xC3, 0x90, 0x90]

        b += [UInt8](repeating: 0, count: 0x120 - b.count)
        b += symtab                                     // 0x120..0x150
        b += [UInt8](repeating: 0, count: 0x160 - b.count)
        b += strtab                                     // 0x160: "\0_main\0"
        b += [UInt8](repeating: 0, count: 0x170 - b.count)
        b += shstr                                       // 0x170: section names
        b += [UInt8](repeating: 0, count: 0x1C0 - b.count)

        // --- Section headers (Elf64_Shdr, 64 bytes each) ---
        func shdr(_ name: UInt32, _ type: UInt32, _ flags: UInt64, _ addr: UInt64,
                  _ offset: UInt64, _ size: UInt64, _ link: UInt32, _ info: UInt32,
                  _ align: UInt64, _ entsize: UInt64) {
            b += u32(name); b += u32(type); b += u64(flags); b += u64(addr)
            b += u64(offset); b += u64(size)
            b += u32(link); b += u32(info)
            b += u64(align); b += u64(entsize)
        }
        shdr(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)                             // [0] null
        shdr(nText, 1, 0x6, 0x400100, 0x100, 16, 0, 0, 16, 0)          // [1] .text PROGBITS AX
        shdr(nSymtab, 2, 0, 0, 0x120, 48, 3, 1, 8, 24)                 // [2] .symtab → strtab
        shdr(nStrtab, 3, 0, 0, 0x160, UInt64(strtab.count), 0, 0, 1, 0) // [3] .strtab
        shdr(nShstr, 3, 0, 0, 0x170, UInt64(shstr.count), 0, 0, 1, 0)   // [4] .shstrtab

        return Data(b)
    }

    // MARK: - Helpers

    private func writeTemp(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("elf-test-\(UUID().uuidString).bin")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// Resolve the ELF parser through `BinaryLoader.parsers` so the test does
    /// not depend on the concrete type name.
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

    // MARK: - Tests

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
