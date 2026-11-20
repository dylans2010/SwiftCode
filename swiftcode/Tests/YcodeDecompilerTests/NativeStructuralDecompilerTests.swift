import XCTest
@testable import YcodeDecompiler

final class NativeStructuralDecompilerTests: XCTestCase {
    func testARM64FunctionLiftingProducesReadableCAndSwift() {
        let src = AnalysisSource(provenance: .engine, engineID: "otool")
        let fn = DecompilerFunction(
            address: DecompilerAddress(virtual: 0x1000),
            endAddress: DecompilerAddress(virtual: 0x1028),
            size: 0x28,
            name: "_sc_compute",
            originalName: "_sc_compute",
            kind: .exportedSymbol,
            source: src
        )
        let instructions: [Instruction] = [
            Instruction(address: .init(virtual: 0x1000), rawBytes: Data([0xFD, 0x7B, 0xBF, 0xA9]), size: 4, mnemonic: "stp", operandText: "x29, x30, [sp, #-0x10]!", source: src),
            Instruction(address: .init(virtual: 0x1004), rawBytes: Data([0xFD, 0x03, 0x00, 0x91]), size: 4, mnemonic: "mov", operandText: "x29, sp", source: src),
            Instruction(address: .init(virtual: 0x1008), rawBytes: Data([0x1F, 0x00, 0x00, 0xF1]), size: 4, mnemonic: "cmp", operandText: "x0, #0", classification: .normal, source: src),
            Instruction(address: .init(virtual: 0x100C), rawBytes: Data([0x6D, 0x00, 0x00, 0x54]), size: 4, mnemonic: "b.le", operandText: "0x1018", classification: .branch, branchTarget: .init(virtual: 0x1018), source: src),
            Instruction(address: .init(virtual: 0x1010), rawBytes: Data([0x00, 0x00, 0x01, 0x8B]), size: 4, mnemonic: "add", operandText: "x0, x0, x1", source: src),
            Instruction(address: .init(virtual: 0x1014), rawBytes: Data([0xC0, 0x03, 0x5F, 0xD6]), size: 4, mnemonic: "ret", operandText: "", classification: .returnInstruction, source: src),
            Instruction(address: .init(virtual: 0x1018), rawBytes: Data([0xE0, 0x03, 0x01, 0xAA]), size: 4, mnemonic: "mov", operandText: "x0, x1", source: src),
            Instruction(address: .init(virtual: 0x101C), rawBytes: Data([0xC0, 0x03, 0x5F, 0xD6]), size: 4, mnemonic: "ret", operandText: "", classification: .returnInstruction, source: src),
        ]

        let cResult = NativeStructuralDecompiler.decompileFunction(fn, instructions: instructions, image: nil, dialect: .c)
        XCTAssertEqual(cResult.engineID, NativeStructuralDecompiler.engineID)
        XCTAssertTrue(cResult.pseudocode.contains("int64_t sc_compute(int64_t arg0, int64_t arg1)"), cResult.pseudocode)
        XCTAssertTrue(cResult.pseudocode.contains("if (arg0 <= 0)"), cResult.pseudocode)
        XCTAssertTrue(cResult.pseudocode.contains("return (arg0 + arg1);"), cResult.pseudocode)
        XCTAssertFalse(cResult.addressLineMap.isEmpty)

        let swiftResult = NativeStructuralDecompiler.decompileFunction(fn, instructions: instructions, image: nil, dialect: .swift)
        XCTAssertTrue(swiftResult.pseudocode.contains("func sc_compute(_ arg0: Int, _ arg1: Int) -> Int"), swiftResult.pseudocode)
    }

    func testEntropyAndWildcardPatternScanner() {
        let payload = Data([0xFD, 0x7B, 0xBF, 0xA9, 0xFD, 0x03, 0x00, 0x91, 0xC0, 0x03, 0x5F, 0xD6])
        let sec = BinarySectionInfo(
            name: "__text", segment: "__TEXT",
            address: .init(virtual: 0x4000), size: UInt64(payload.count),
            fileOffset: 0, flags: 0, isExecutable: true, isWritable: false, containsStrings: false
        )
        let seg = BinarySegmentInfo(
            name: "__TEXT", vmAddress: 0x4000, vmSize: UInt64(payload.count),
            fileOffset: 0, fileSize: UInt64(payload.count),
            maxProtection: 5, initialProtection: 5, sections: [sec]
        )
        let id = BinaryIdentity(sha256: "00", originalFileName: "demo", originalLocation: "/tmp/demo",
                                fileSize: Int64(payload.count), format: .machO, architecture: .arm64)
        let image = BinaryImage(
            identity: id, format: .machO, architecture: .arm64, cpuIdentifier: "arm64", fileType: "dylib",
            entryPoint: nil, segments: [seg], imports: [], exports: [], dependencies: [],
            symbols: [], strings: [], functionStarts: [], isEncrypted: false, isSigned: true,
            entitlements: nil, codeSignatureInfo: "Ad-hoc signed", buildVersion: nil, minOSVersion: nil,
            hasDebugInfo: false, byteCount: Int64(payload.count),
            byteProvider: { off, len in payload.subdata(in: Int(off)..<min(payload.count, Int(off + len))) }
        )

        let entropies = BinaryAdvancedAnalyzer.analyzeSectionEntropy(image: image)
        XCTAssertEqual(entropies.count, 1)
        XCTAssertGreaterThan(entropies[0].entropy, 1.0)

        let hits = BinaryAdvancedAnalyzer.scanHexPattern(pattern: "FD 7B ?? A9", image: image, functions: [])
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].address.value, 0x4000)
    }
}
