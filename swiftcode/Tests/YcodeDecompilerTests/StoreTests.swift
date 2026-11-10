import XCTest
@testable import YcodeDecompiler

/// Exercises `AnalysisStore`: function/symbol upserts, address-containment
/// lookup, and reversible renames.
final class StoreTests: XCTestCase {

    private func source(_ p: AnalysisProvenance = .heuristic) -> AnalysisSource {
        AnalysisSource(provenance: p)
    }

    private func function(_ addr: UInt64, name: String,
                          end: UInt64? = nil, size: UInt64 = 0) -> DecompilerFunction {
        DecompilerFunction(
            address: DecompilerAddress(virtual: addr),
            endAddress: end.map { DecompilerAddress(virtual: $0) },
            size: size, name: name, originalName: name,
            kind: .discovered, source: source())
    }

    private func symbol(_ name: String, addr: UInt64? = nil) -> BinarySymbol {
        BinarySymbol(name: name,
                     address: addr.map { DecompilerAddress(virtual: $0) },
                     kind: .global, source: source(.symbolTable))
    }

    func testUpsertFunctionsSortsByAddress() async {
        let store = AnalysisStore()
        await store.upsertFunctions([
            function(0x2000, name: "b"),
            function(0x1000, name: "a"),
        ])
        let fns = await store.functions
        XCTAssertEqual(fns.map(\.name), ["a", "b"])
    }

    func testUpsertFunctionsReplacesSameAddress() async {
        let store = AnalysisStore()
        await store.upsertFunctions([function(0x1000, name: "old")])
        await store.upsertFunctions([function(0x1000, name: "new")])
        let fns = await store.functions
        XCTAssertEqual(fns.count, 1)
        XCTAssertEqual(fns.first?.name, "new")
    }

    func testFunctionAtExactAddress() async {
        let store = AnalysisStore()
        await store.upsertFunctions([function(0x1000, name: "a")])
        let f = await store.function(at: 0x1000)
        XCTAssertEqual(f?.name, "a")
        let miss = await store.function(at: 0x1001)
        XCTAssertNil(miss)
    }

    func testFunctionContainingUsesEndAddress() async {
        let store = AnalysisStore()
        await store.upsertFunctions([
            function(0x1000, name: "a", end: 0x1100),
            function(0x2000, name: "b"),
        ])
        let inside = await store.function(containing: 0x1050)
        XCTAssertEqual(inside?.name, "a")
        // Past a's end but before b's start: falls back to nearest preceding
        // function bounded by the next function's entry.
        let gap = await store.function(containing: 0x1500)
        XCTAssertEqual(gap?.name, "a")
        // Beyond the last known function: no container.
        let beyond = await store.function(containing: 0x2500)
        XCTAssertNil(beyond)
    }

    func testUpsertSymbolsSortsAndDeduplicates() async {
        let store = AnalysisStore()
        await store.upsertSymbols([symbol("zeta", addr: 0x3000),
                                   symbol("alpha", addr: 0x1000)])
        await store.upsertSymbols([symbol("alpha", addr: 0x1000)])  // dup key
        let syms = await store.symbols
        XCTAssertEqual(syms.count, 2)
        XCTAssertEqual(syms.first?.name, "alpha")
    }

    func testRenameFunctionIsReversible() async {
        let store = AnalysisStore()
        await store.upsertFunctions([
            function(0x1000, name: "_original", end: 0x1010)
        ])
        let ok = await store.renameFunction(at: 0x1000, to: "myRenamed")
        XCTAssertTrue(ok)

        let renamed = await store.function(at: 0x1000)
        XCTAssertEqual(renamed?.name, "myRenamed")
        // The binary's original name is preserved for reversibility.
        XCTAssertEqual(renamed?.originalName, "_original")

        // Rename back restores the effective name.
        _ = await store.renameFunction(at: 0x1000, to: "_original")
        let restored = await store.function(at: 0x1000)
        XCTAssertEqual(restored?.name, "_original")
    }

    func testRenameFunctionUnknownAddressReturnsFalse() async {
        let store = AnalysisStore()
        let ok = await store.renameFunction(at: 0xDEAD, to: "nope")
        XCTAssertFalse(ok)
    }

    func testRenameFunctionAlsoUpdatesSymbolUserName() async {
        let store = AnalysisStore()
        await store.upsertFunctions([function(0x1000, name: "f")])
        await store.upsertSymbols([symbol("_f", addr: 0x1000)])
        _ = await store.renameFunction(at: 0x1000, to: "renamed")
        let syms = await store.symbols
        XCTAssertEqual(syms.first?.userName, "renamed")
        XCTAssertEqual(syms.first?.name, "_f")   // original preserved
        XCTAssertEqual(syms.first?.effectiveName, "renamed")
    }

    func testRenameSymbolByName() async {
        let store = AnalysisStore()
        await store.upsertSymbols([symbol("_printf")])
        let ok = await store.renameSymbol(name: "_printf", to: "printf")
        XCTAssertTrue(ok)
        let syms = await store.symbols
        let s = syms.first
        XCTAssertEqual(s?.userName, "printf")
        XCTAssertEqual(s?.name, "_printf")
        XCTAssertEqual(s?.effectiveName, "printf")
    }

    func testCommentsAndLabelsRoundTripByHexKey() async {
        let store = AnalysisStore()
        let addr = DecompilerAddress(virtual: 0x1234)
        await store.setComment("hello", at: addr)
        await store.setUserLabel("start", at: addr)
        let comment = await store.comment(at: addr)
        let labels = await store.userLabels
        XCTAssertEqual(comment, "hello")
        XCTAssertEqual(labels[addr.hexString], "start")
    }

    func testStorePseudocodeMarksFunction() async {
        let store = AnalysisStore()
        await store.upsertFunctions([function(0x1000, name: "f", end: 0x1010)])
        let result = DecompilationResult(
            functionAddress: DecompilerAddress(virtual: 0x1000),
            functionName: "f", pseudocode: "void f() {}",
            engineID: "test-engine")
        await store.storePseudocode(result)
        let cached = await store.pseudocode(forFunctionAt: 0x1000)
        XCTAssertEqual(cached?.pseudocode, "void f() {}")
        let f = await store.function(at: 0x1000)
        XCTAssertTrue(f?.hasPseudocode ?? false)
    }

    func testTogglePinned() async {
        let store = AnalysisStore()
        await store.upsertFunctions([function(0x1000, name: "f")])
        await store.togglePinned(0x1000)
        var pinned = await store.pinnedFunctions
        XCTAssertTrue(pinned.contains(0x1000))
        var f = await store.function(at: 0x1000)
        XCTAssertTrue(f?.isPinned ?? false)
        await store.togglePinned(0x1000)
        pinned = await store.pinnedFunctions
        XCTAssertFalse(pinned.contains(0x1000))
        f = await store.function(at: 0x1000)
        XCTAssertFalse(f?.isPinned ?? false)
    }
}
