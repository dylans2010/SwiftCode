import XCTest
@testable import YcodeDecompiler

/// Parses a hand-built, minimal PE32+ (x86-64) executable.
///
/// Layout:
///   0x000  DOS header ("MZ", e_lfanew = 0x80)
///   0x080  PE signature + COFF header (20 bytes)
///   0x098  Optional header PE32+ (0xF0 bytes)
///   0x188  Section header ".text" (40 bytes)
///   0x200  Section raw data (0x200 bytes)
final class PEParserTests: XCTestCase {

    private static func u16(_ v: UInt16) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private static func u32(_ v: UInt32) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private static func u64(_ v: UInt64) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }

    private static func build() -> Data {
        var b = [UInt8]()
        b.reserveCapacity(0x400)

        // DOS header
        b += [0x4D, 0x5A]
        b += [UInt8](repeating: 0, count: 0x3C - 2)
        b += u32(0x80)
        b += [UInt8](repeating: 0, count: 0x80 - b.count)

        // PE signature + COFF
        b += [0x50, 0x45, 0x00, 0x00]
        b += u16(0x8664); b += u16(1)
        b += u32(0); b += u32(0); b += u32(0)
        b += u16(0xF0); b += u16(0x0022)

        // Optional header PE32+ (240 bytes)
        b += u16(0x20B)                   // Magic
        b += [0x0E, 0x00]                 // linker versions
        b += u32(0x200)                   // SizeOfCode
        b += u32(0)                       // SizeOfInitializedData
        b += u32(0)                       // SizeOfUninitializedData
        b += u32(0x1000)                  // AddressOfEntryPoint
        b += u32(0x1000)                  // BaseOfCode
        b += u64(0x140000000)             // ImageBase
        b += u32(0x1000)                  // SectionAlignment
        b += u32(0x200)                   // FileAlignment
        b += [UInt8](repeating: 0, count: 12) // OS/Image/Subsys version u16 × 6
        b += u32(0)                       // Win32VersionValue
        b += u32(0x2000)                  // SizeOfImage
        b += u32(0x200)                   // SizeOfHeaders
        b += u32(0)                       // CheckSum
        b += u16(3)                       // Subsystem = IMAGE_SUBSYSTEM_WINDOWS_CUI
        b += u16(0x8160)                  // DllCharacteristics
        b += u64(0x100000)                // SizeOfStackReserve
        b += u64(0x1000)                  // SizeOfStackCommit
        b += u64(0x100000)                // SizeOfHeapReserve
        b += u64(0x1000)                  // SizeOfHeapCommit
        b += u32(0)                       // LoaderFlags
        b += u32(16)                      // NumberOfRvaAndSizes
        b += [UInt8](repeating: 0, count: 16 * 8)  // data directories

        // Section header ".text" (40 bytes) at 0x188
        b += [0x2E, 0x74, 0x65, 0x78, 0x74, 0x00, 0x00, 0x00]  // ".text"
        b += u32(0x200)                   // VirtualSize
        b += u32(0x1000)                  // VirtualAddress (RVA)
        b += u32(0x200)                   // SizeOfRawData
        b += u32(0x200)                   // PointerToRawData
        b += u32(0)                       // PointerToRelocations
        b += u32(0)                       // PointerToLinenumbers
        b += u16(0)                       // NumberOfRelocations
        b += u16(0)                       // NumberOfLinenumbers
        b += u32(0x60000020)              // Characteristics: CODE | EXECUTE | READ

        b += [UInt8](repeating: 0, count: 0x200 - b.count)
        // .text raw data: plausible x86-64 prologue … ret
        b += [0x55, 0x48, 0x89, 0xE5, 0x48, 0x83, 0xEC, 0x20,
              0xB8, 0x2A, 0x00, 0x00, 0x00, 0x48, 0x83, 0xC4,
              0x20, 0x5D, 0xC3]
        b += [UInt8](repeating: 0, count: 0x400 - b.count)
        return Data(b)
    }

    // MARK: - Helpers

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

    // MARK: - Tests

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
        // Entry point should be ImageBase + AddressOfEntryPoint = 0x140001000.
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
