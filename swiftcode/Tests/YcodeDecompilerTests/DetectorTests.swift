import XCTest
@testable import YcodeDecompiler



final class DetectorTests: XCTestCase {

    private func writeTemp(_ name: String, _ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("detect-\(UUID().uuidString)-\(name)")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func padded(_ prefix: [UInt8], to count: Int = 128) -> Data {
        var b = prefix
        b += [UInt8](repeating: 0, count: max(0, count - b.count))
        return Data(b)
    }

    func testDetectThinMachO() throws {
        
        let url = try writeTemp("fake.txt", padded([0xCF, 0xFA, 0xED, 0xFE]))
        let d = try BinaryDetector.detect(url: url)
        XCTAssertEqual(d.format, .machO)
        XCTAssertFalse(d.isUniversal)
        XCTAssertEqual(d.firstSliceOffset, 0)
    }

    func testDetectMachO32() throws {
        
        let url = try writeTemp("fake.bin", padded([0xCE, 0xFA, 0xED, 0xFE]))
        let d = try BinaryDetector.detect(url: url)
        XCTAssertEqual(d.format, .machO)
    }

    func testDetectFatMachO() throws {
        
        let magics: [[UInt8]] = [[0xCA, 0xFE, 0xBA, 0xBE], [0xCA, 0xFE, 0xBA, 0xBF]]
        for magic in magics {
            let url = try writeTemp("fat.bin", padded(magic))
            let d = try BinaryDetector.detect(url: url)
            XCTAssertEqual(d.format, .machO)
            XCTAssertTrue(d.isUniversal)
        }
    }

    func testDetectELF() throws {
        let url = try writeTemp("not-a-binary.dat", padded([0x7F, 0x45, 0x4C, 0x46]))
        let d = try BinaryDetector.detect(url: url)
        XCTAssertEqual(d.format, .elf)
        XCTAssertFalse(d.isUniversal)
    }

    func testDetectPEViaMZAndPEHeader() throws {
        var bytes = [UInt8](repeating: 0, count: 0x100)
        bytes[0] = 0x4D; bytes[1] = 0x5A                 
        
        bytes[0x3C] = 0x80
        bytes[0x80] = 0x50; bytes[0x81] = 0x45
        bytes[0x82] = 0x00; bytes[0x83] = 0x00          
        let url = try writeTemp("payload.bin", Data(bytes))
        let d = try BinaryDetector.detect(url: url)
        XCTAssertEqual(d.format, .pe)
    }

    func testDetectPEViaMZOnly() throws {
        
        
        var bytes = [UInt8](repeating: 0, count: 0x100)
        bytes[0] = 0x4D; bytes[1] = 0x5A
        let url = try writeTemp("mz-only.bin", Data(bytes))
        let d = try BinaryDetector.detect(url: url)
        XCTAssertEqual(d.format, .pe)
    }

    func testRejectsUnknownSignature() throws {
        let url = try writeTemp("random.bin", padded([0x01, 0x02, 0x03, 0x04]))
        XCTAssertThrowsError(try BinaryDetector.detect(url: url)) { error in
            guard case DecompilerError.unsupportedFormat = error else {
                return XCTFail("expected unsupportedFormat, got \(error)")
            }
        }
    }

    func testRejectsTinyFile() throws {
        let url = try writeTemp("tiny.bin", Data([0x7F]))
        XCTAssertThrowsError(try BinaryDetector.detect(url: url)) { error in
            guard case DecompilerError.malformedBinary = error else {
                return XCTFail("expected malformedBinary, got \(error)")
            }
        }
    }

    func testSHA256IsStableAndHex() throws {
        let url = try writeTemp("hash.bin", Data("hello".utf8))
        let h1 = try BinaryDetector.sha256(url: url)
        let h2 = try BinaryDetector.sha256(url: url)
        XCTAssertEqual(h1, h2)
        XCTAssertEqual(h1.count, 64)
        XCTAssertTrue(h1.allSatisfy { $0.isHexDigit })
    }
}
