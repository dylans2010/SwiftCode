import XCTest
@testable import YcodeDecompiler



final class AddressTests: XCTestCase {

    

    func testParseHexWithPrefix() {
        let a = DecompilerAddress.parse("0x1A2B")
        XCTAssertEqual(a?.kind, .virtual)
        XCTAssertEqual(a?.value, 0x1A2B)
    }

    func testParseUppercasePrefix() {
        let a = DecompilerAddress.parse("0XFF")
        XCTAssertEqual(a?.value, 0xFF)
    }

    func testParseDefaultsToVirtualKind() {
        let a = DecompilerAddress.parse("dead", defaultKind: .fileOffset)
        XCTAssertEqual(a?.kind, .fileOffset)
        XCTAssertEqual(a?.value, 0xDEAD)
    }

    func testParseRejectsGarbage() {
        XCTAssertNil(DecompilerAddress.parse("not-an-address"))
        XCTAssertNil(DecompilerAddress.parse(""))
    }

    func testHexStringIsLowercaseCanonical() {
        let a = DecompilerAddress(virtual: 0xABCD)
        XCTAssertEqual(a.hexString, "0xabcd")
    }

    func testDescriptionIsZeroPadded() {
        XCTAssertEqual(DecompilerAddress(virtual: 0x1).description, "0x0000000000000001")
        XCTAssertEqual(DecompilerAddress(fileOffset: 0x1).description, "0x00000001")
    }

    func testOrderingOnlyWithinSameKind() {
        let v1 = DecompilerAddress(virtual: 1)
        let v2 = DecompilerAddress(virtual: 2)
        let f1 = DecompilerAddress(fileOffset: 1)
        XCTAssertTrue(v1 < v2)
        XCTAssertFalse(v1 < f1) 
        XCTAssertFalse(f1 < v1)
    }

    

    private func makeImage() -> BinaryImage {
        let identity = BinaryIdentity(
            sha256: "test", originalFileName: "t.bin", originalLocation: "/tmp/t.bin",
            fileSize: 0x400, format: .elf, architecture: .x86_64)
        let segment = BinarySegmentInfo(
            name: "LOAD", vmAddress: 0x400000, vmSize: 0x1000,
            fileOffset: 0x200, fileSize: 0x800,
            maxProtection: 5, initialProtection: 5, sections: [])
        return BinaryImage(
            identity: identity, format: .elf, architecture: .x86_64,
            cpuIdentifier: "x86_64", fileType: "exec",
            entryPoint: nil, segments: [segment],
            imports: [], exports: [], dependencies: [],
            symbols: [], strings: [], functionStarts: [],
            isEncrypted: false, isSigned: false, entitlements: nil,
            codeSignatureInfo: nil, buildVersion: nil, minOSVersion: nil,
            hasDebugInfo: false, byteCount: 0x400,
            byteProvider: { _, _ in Data() })
    }

    func testVirtualAddressInsideSegmentMapsToFileOffset() {
        let image = makeImage()
        
        XCTAssertEqual(image.fileOffset(forVirtualAddress: 0x400010), 0x210)
        XCTAssertEqual(image.fileOffset(forVirtualAddress: 0x400000), 0x200)
    }

    func testVirtualAddressOutsideSegmentIsNil() {
        let image = makeImage()
        XCTAssertNil(image.fileOffset(forVirtualAddress: 0x500000))
    }

    func testVirtualAddressBeyondFileSizeIsNil() {
        let image = makeImage()
        
        
        XCTAssertNil(image.fileOffset(forVirtualAddress: 0x400900))
    }

    func testBytesVirtualAddressThrowsWhenUnmapped() {
        let image = makeImage()
        XCTAssertThrowsError(try image.bytes(virtualAddress: 0x999999, length: 4)) { error in
            guard case DecompilerError.unmappedAddress = error else {
                return XCTFail("expected unmappedAddress, got \(error)")
            }
        }
    }
}
