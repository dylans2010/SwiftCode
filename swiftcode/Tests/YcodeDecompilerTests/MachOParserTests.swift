import XCTest
@testable import YcodeDecompiler

/// Parses a hand-built, minimal 64-bit Mach-O executable (thin, arm64).
///
/// Layout:
///   0x000  mach_header_64 (32 bytes), ncmds = 2
///   0x020  LC_SEGMENT_64 "__TEXT" with one section "__text" (72 + 80 = 152)
///   0x0B8  LC_SYMTAB (24 bytes)
///   0x100  section raw data + padding
///   0x120  symbol table (1 × nlist_64 = 16 bytes)
///   0x130  string table "\0_main\0"
final class MachOParserTests: XCTestCase {

    private static let textAddr: UInt64 = 0x100000100
    private static let textSize: UInt64 = 16
    private static let symoff: UInt64 = 0x120
    private static let nsyms: UInt32 = 1
    private static let stroff: UInt64 = 0x130
    private static let strsize: UInt32 = 7          // "\0_main\0"
    private static let sizeofcmds = 72 + 80 + 24   // 176
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

        // --- mach_header_64 ---
        b += u32(0xFEEDFACF)               // MH_MAGIC_64 (LE on disk)
        b += u32(0x0100000C)               // CPU_TYPE_ARM64
        b += u32(0)                        // CPU_SUBTYPE_ARM64_ALL
        b += u32(2)                        // MH_EXECUTE
        b += u32(2)                        // ncmds
        b += u32(UInt32(sizeofcmds))       // sizeofcmds
        b += u32(0)                        // flags
        b += u32(0)                        // reserved

        // --- LC_SEGMENT_64 (cmd 0x19) ---
        b += u32(0x19)
        b += u32(72 + 80)                  // cmdsize
        b += name16("__TEXT")
        b += u64(0x100000000)              // vmaddr
        b += u64(0x1000)                   // vmsize
        b += u64(0)                        // fileoff
        b += u64(0x200)                    // filesize
        b += u32(5)                        // maxprot R+X
        b += u32(5)                        // initprot R+X
        b += u32(1)                        // nsects
        b += u32(0)                        // flags

        // --- section_64 "__text" ---
        b += name16("__text")
        b += name16("__TEXT")
        b += u64(textAddr)                 // addr
        b += u64(textSize)                 // size
        b += u32(0x100)                    // offset
        b += u32(4)                        // align = 2^4
        b += u32(0); b += u32(0)           // reloff, nreloc
        b += u32(0x80000400)               // flags: PURE_INSTRUCTIONS|SOME_INSTRUCTIONS
        b += u32(0); b += u32(0); b += u32(0)  // reserved1..3

        // --- LC_SYMTAB (cmd 0x2) ---
        b += u32(0x2)
        b += u32(24)                       // cmdsize
        b += u32(UInt32(symoff))           // symoff
        b += nsyms                         // nsyms
        b += u32(UInt32(stroff))           // stroff
        b += strsize                       // strsize

        // pad to 0x100
        b += [UInt8](repeating: 0, count: 0x100 - b.count)

        // --- __text bytes: a tiny arm64-ish stub (values are opaque to the parser) ---
        b += [0xFD, 0x7B, 0xBF, 0xA9,      // stp x29, x30, [sp, #-16]!
              0xFD, 0x03, 0x00, 0x91,      // mov x29, sp
              0xC0, 0x03, 0x5F, 0xD6]      // ret
        b += [UInt8](repeating: 0, count: 0x120 - b.count)

        // --- nlist_64: n_strx=1, N_SECT|N_EXT, n_sect=1, n_value=textAddr ---
        b += u32(1)
        b += [0x0F]                        // n_type = N_SECT(0x0E) | N_EXT(0x01)
        b += [0x01]                        // n_sect = section 1 (__text)
        b += [0x00, 0x00]                  // n_desc (u16)
        b += u64(textAddr)                 // n_value

        b += [UInt8](repeating: 0, count: 0x130 - b.count)
        b += [0x00] + Array("_main".utf8) + [0x00]   // strtab: "\0_main\0"
        b += [UInt8](repeating: 0, count: fileSize - b.count)
        return Data(b)
    }

    // MARK: - Helpers

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

    // MARK: - Tests

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
