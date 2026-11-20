import AppKit
import Darwin
import Foundation
import SwiftUI

public struct SectionEntropyResult: Identifiable, Sendable {
    public var id: String { "\(segment).\(section)@\(address.hexString)" }
    public let segment: String
    public let section: String
    public let address: DecompilerAddress
    public let size: UInt64
    public let entropy: Double
    public let classification: String
}

public struct SecurityCheckItem: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let passed: Bool
    public let detail: String
}

public struct PatternMatchHit: Identifiable, Sendable {
    public var id: String { "\(sectionName)-\(address.hexString)" }
    public let address: DecompilerAddress
    public let sectionName: String
    public let previewHex: String
    public let asciiPreview: String
    public let containingFunction: String?
}

public enum BinaryAdvancedAnalyzer {
    public static func shannonEntropy(_ data: Data) -> Double {
        guard !data.isEmpty else { return 0 }
        var counts = [Int](repeating: 0, count: 256)
        for b in data { counts[Int(b)] += 1 }
        let total = Double(data.count)
        var h = 0.0
        for c in counts where c > 0 {
            let p = Double(c) / total
            h -= p * log2(p)
        }
        return h
    }

    public static func analyzeSectionEntropy(image: BinaryImage) -> [SectionEntropyResult] {
        var results: [SectionEntropyResult] = []
        for seg in image.segments {
            for sec in seg.sections where sec.size > 0 {
                let sampleLen = min(sec.size, 262_144)
                let data = (try? image.byteProvider(sec.fileOffset, sampleLen)) ?? Data()
                let e = shannonEntropy(data)
                let label: String = if e >= 7.2 {
                    "Encrypted / Compressed"
                } else if e >= 6.0 {
                    "Dense Code / Data"
                } else if e >= 3.5 {
                    "Structured Text / Tables"
                } else {
                    "Sparse / Zero-Padded"
                }
                results.append(SectionEntropyResult(
                    segment: seg.name, section: sec.name,
                    address: sec.address, size: sec.size,
                    entropy: e, classification: label
                ))
            }
        }
        return results
    }

    public static func hardeningChecks(image: BinaryImage) -> [SecurityCheckItem] {
        let importNames = Set(image.imports.map { $0.name.trimmingCharacters(in: CharacterSet(charactersIn: "_")) })
        let symNames = Set(image.symbols.map { $0.name.trimmingCharacters(in: CharacterSet(charactersIn: "_")) })
        let all = importNames.union(symNames)

        let hasCanary = all.contains("stack_chk_fail") || all.contains("__stack_chk_fail") || all.contains("__stack_chk_guard")
        let hasARC = all.contains("objc_release") || all.contains("objc_retain") || all.contains("swift_release")
        let hasFortify = all.contains { $0.contains("_chk") }

        let unsafeC = ["strcpy", "strcat", "sprintf", "vsprintf", "gets", "mktemp", "system", "popen"]
            .filter { all.contains($0) }

        return [
            SecurityCheckItem(name: "Code Signature", passed: image.isSigned,
                              detail: image.codeSignatureInfo ?? (image.isSigned ? "Signed binary" : "Unsigned binary")),
            SecurityCheckItem(name: "Unencrypted Segments", passed: !image.isEncrypted,
                              detail: image.isEncrypted ? "FairPlay / segment encryption flag is set" : "Cleartext segments ready for static lifting"),
            SecurityCheckItem(name: "Stack Smashing Protection", passed: hasCanary,
                              detail: hasCanary ? "Stack canary symbols (__stack_chk_fail) linked" : "No stack canary symbols referenced"),
            SecurityCheckItem(name: "Automatic Reference Counting", passed: hasARC,
                              detail: hasARC ? "Swift / Objective-C ARC runtime calls present" : "Manual memory management or pure C/ASM"),
            SecurityCheckItem(name: "Fortified Libc (_chk)", passed: hasFortify || unsafeC.isEmpty,
                              detail: hasFortify ? "Bounds-checked *_chk symbols detected" : "Standard C library symbols"),
            SecurityCheckItem(name: "Unsafe C API Audit", passed: unsafeC.isEmpty,
                              detail: unsafeC.isEmpty ? "No classic unsafe buffer/shell APIs imported" : "Imports: \(unsafeC.joined(separator: ", "))"),
        ]
    }

    public static func scanHexPattern(
        pattern: String,
        image: BinaryImage,
        functions: [DecompilerFunction],
        limit: Int = 250
    ) -> [PatternMatchHit] {
        let tokens = pattern
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !tokens.isEmpty else { return [] }
        var needle: [UInt8?] = []
        for tok in tokens {
            if tok == "?" || tok == "??" || tok == "**" {
                needle.append(nil)
            } else {
                let clean = tok.hasPrefix("0x") ? String(tok.dropFirst(2)) : tok
                guard clean.count == 2, let b = UInt8(clean, radix: 16) else { return [] }
                needle.append(b)
            }
        }
        guard !needle.isEmpty else { return [] }

        var hits: [PatternMatchHit] = []
        let plen = needle.count
        for seg in image.segments {
            for sec in seg.sections where sec.size >= UInt64(plen) {
                let cap = min(sec.size, 2_097_152)
                guard let data = try? image.byteProvider(sec.fileOffset, cap), data.count >= plen else { continue }
                data.withUnsafeBytes { raw in
                    guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
                    let end = raw.count - plen
                    var i = 0
                    while i <= end {
                        var matched = true
                        for j in 0..<plen {
                            if let expected = needle[j], base[i + j] != expected {
                                matched = false
                                break
                            }
                        }
                        if matched {
                            let va = DecompilerAddress(virtual: sec.address.value + UInt64(i))
                            let sliceCount = min(16, raw.count - i)
                            var hexParts: [String] = []
                            var ascii = ""
                            for k in 0..<sliceCount {
                                let b = base[i + k]
                                hexParts.append(String(format: "%02X", b))
                                ascii.append((0x20...0x7E).contains(b) ? Character(UnicodeScalar(b)) : ".")
                            }
                            let fnName = functions.first { f in
                                let hi = f.endAddress?.value ?? (f.address.value + max(f.size, 4))
                                return f.address.value <= va.value && va.value < hi
                            }?.displayName
                            hits.append(PatternMatchHit(
                                address: va,
                                sectionName: "\(seg.name).\(sec.name)",
                                previewHex: hexParts.joined(separator: " "),
                                asciiPreview: ascii,
                                containingFunction: fnName
                            ))
                            if hits.count >= limit { return }
                            i += max(1, plen)
                        } else {
                            i += 1
                        }
                    }
                }
                if hits.count >= limit { return hits }
            }
        }
        return hits
    }
}

public struct CallGraphExplorerView: View {
    @Bindable var state: DecompilerObservableState
    @State private var filterText = ""
    @State private var copiedStatus = ""

    public init(state: DecompilerObservableState) {
        self.state = state
    }

    private var callersOfSelected: [(fn: DecompilerFunction?, xref: CrossReference)] {
        guard let sel = state.selectedFunction else { return [] }
        return state.crossReferences
            .filter { $0.destination.value == sel.address.value && ($0.kind == .call || $0.kind == .branch) }
            .map { xref in (state.function(containing: xref.source), xref) }
    }

    private var calleesOfSelected: [(target: DecompilerAddress, name: String)] {
        guard let sel = state.selectedFunction else { return [] }
        let start = sel.address.value
        let end = sel.endAddress?.value ?? (start + max(sel.size, 256))
        var seen: Set<UInt64> = []
        var out: [(DecompilerAddress, String)] = []
        for xref in state.crossReferences where xref.source.value >= start && xref.source.value < end && xref.kind == .call {
            if seen.insert(xref.destination.value).inserted {
                let name = state.function(containing: xref.destination)?.displayName
                    ?? state.symbols.first { $0.address?.value == xref.destination.value }?.effectiveName
                    ?? xref.destination.hexString
                out.append((xref.destination, SymbolDemangler.demangle(name)))
            }
        }
        return out
    }

    private var topHotspots: [(fn: DecompilerFunction, inboundCalls: Int)] {
        var counts: [UInt64: Int] = [:]
        for x in state.crossReferences where x.kind == .call {
            counts[x.destination.value, default: 0] += 1
        }
        return state.functions
            .compactMap { f -> (DecompilerFunction, Int)? in
                let c = counts[f.address.value] ?? 0
                guard filterText.isEmpty || f.displayName.localizedCaseInsensitiveContains(filterText) else { return nil }
                return c > 0 ? (f, c) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(50)
            .map { $0 }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("Call Graph & Xref Explorer", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !copiedStatus.isEmpty {
                    Text(copiedStatus).font(.caption).foregroundStyle(.secondary)
                }
                Button("Copy Graphviz DOT") {
                    NSPasteboardCopy(exportDOT())
                    copiedStatus = "Copied DOT"
                }
                .controlSize(.small)
                Button("Copy Mermaid") {
                    NSPasteboardCopy(exportMermaid())
                    copiedStatus = "Copied Mermaid"
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            HSplitView {
                VStack(alignment: .leading, spacing: 12) {
                    if let sel = state.selectedFunction {
                        Text("Neighborhood of \(SymbolDemangler.demangle(sel.displayName))")
                            .font(.headline)
                            .lineLimit(1)

                        HStack(alignment: .top, spacing: 14) {
                            GroupBox("Callers (\(callersOfSelected.count))") {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 6) {
                                        if callersOfSelected.isEmpty {
                                            Text("No direct call sites recorded (entry point, exported API, or virtual dispatch).")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        ForEach(Array(callersOfSelected.enumerated()), id: \.offset) { _, item in
                                            Button {
                                                if let caller = item.fn { state.selectFunction(caller) }
                                                else { state.navigate(to: item.xref.source) }
                                            } label: {
                                                HStack {
                                                    Image(systemName: "arrow.up.left")
                                                        .foregroundStyle(.orange)
                                                    Text(item.fn.map { SymbolDemangler.demangle($0.displayName) } ?? item.xref.source.hexString)
                                                        .font(.system(.caption, design: .monospaced))
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text(item.xref.source.hexString)
                                                        .font(.system(.caption2, design: .monospaced))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(4)
                                }
                            }

                            GroupBox("Callees (\(calleesOfSelected.count))") {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 6) {
                                        if calleesOfSelected.isEmpty {
                                            Text("Leaf function — makes no direct calls.")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        ForEach(Array(calleesOfSelected.enumerated()), id: \.offset) { _, callee in
                                            Button {
                                                if let fn = state.function(containing: callee.target) {
                                                    state.selectFunction(fn)
                                                } else {
                                                    state.navigate(to: callee.target)
                                                }
                                            } label: {
                                                HStack {
                                                    Image(systemName: "arrow.down.right")
                                                        .foregroundStyle(.purple)
                                                    Text(callee.name)
                                                        .font(.system(.caption, design: .monospaced))
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text(callee.target.hexString)
                                                        .font(.system(.caption2, design: .monospaced))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(4)
                                }
                            }
                        }
                    } else {
                        EmptyStateView(
                            systemImage: "point.3.connected.trianglepath.dotted",
                            title: "Select a Function",
                            message: "Pick a function in the sidebar or hotspot list to inspect its callers and callees."
                        )
                    }
                }
                .padding(12)
                .frame(minWidth: 360)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Most-Called Hotspots")
                        .font(.subheadline.weight(.semibold))
                    TextField("Filter hotspots…", text: $filterText)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    List(topHotspots, id: \.fn.id) { item in
                        Button {
                            state.selectFunction(item.fn)
                        } label: {
                            HStack {
                                Text(SymbolDemangler.demangle(item.fn.displayName))
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.inboundCalls) calls")
                                    .font(.caption2.monospacedDigit())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.inset)
                }
                .padding(10)
                .frame(minWidth: 230, idealWidth: 270, maxWidth: 340)
            }
        }
    }

    private func exportDOT() -> String {
        var lines = ["digraph CallGraph {", "  rankdir=LR;"]
        for x in state.crossReferences.prefix(400) where x.kind == .call {
            let src = state.function(containing: x.source)?.displayName ?? x.source.hexString
            let dst = state.function(containing: x.destination)?.displayName ?? x.destination.hexString
            lines.append("  \"\(src)\" -> \"\(dst)\";")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private func exportMermaid() -> String {
        var lines = ["flowchart LR"]
        for (i, x) in state.crossReferences.filter({ $0.kind == .call }).prefix(120).enumerated() {
            let src = ReconstructionUtilities.cFunctionName(for: state.function(containing: x.source)?.displayName ?? x.source.hexString)
            let dst = ReconstructionUtilities.cFunctionName(for: state.function(containing: x.destination)?.displayName ?? x.destination.hexString)
            lines.append("  \(src)_\(i)[\(src)] --> \(dst)")
        }
        return lines.joined(separator: "\n")
    }
}

public struct MetadataTypeBrowserView: View {
    @Bindable var state: DecompilerObservableState
    @State private var mode = 0
    @State private var query = ""

    public init(state: DecompilerObservableState) {
        self.state = state
    }

    private var objcItems: [(cls: String, methods: [(name: String, addr: DecompilerAddress?)])] {
        var map: [String: [(String, DecompilerAddress?)]] = [:]
        for sym in state.symbols {
            let n = sym.effectiveName
            if (n.hasPrefix("-[") || n.hasPrefix("+[")), let sp = n.firstIndex(of: " ") {
                let cls = String(n[n.index(n.startIndex, offsetBy: 2)..<sp])
                if query.isEmpty || n.localizedCaseInsensitiveContains(query) {
                    map[cls, default: []].append((n, sym.address))
                }
            } else if n.hasPrefix("_OBJC_CLASS_$_") {
                let cls = String(n.dropFirst("_OBJC_CLASS_$_".count))
                if query.isEmpty || cls.localizedCaseInsensitiveContains(query) {
                    _ = map[cls, default: []]
                }
            }
        }
        return map.keys.sorted().map { ($0, map[$0] ?? []) }
    }

    private var swiftItems: [(demangled: String, raw: String, addr: DecompilerAddress?)] {
        state.symbols.compactMap { sym in
            let raw = sym.name
            guard raw.hasPrefix("_$s") || raw.hasPrefix("$s") || raw.hasPrefix("_$e") else { return nil }
            let dem = SymbolDemangler.demangle(raw)
            if !query.isEmpty && !dem.localizedCaseInsensitiveContains(query) && !raw.localizedCaseInsensitiveContains(query) {
                return nil
            }
            return (dem, raw, sym.address)
        }
    }

    private var synthesizedHeader: String {
        guard let image = state.binary else { return "// No binary loaded.\n" }
        var lines: [String] = [
            "/* Synthesized Interface Header for \(image.identity.originalFileName) */",
            "#pragma once",
            "#include <stdint.h>",
            "",
        ]
        for (cls, methods) in objcItems {
            lines.append("@interface \(cls) : NSObject")
            for (m, _) in methods {
                lines.append("\(m);")
            }
            lines.append("@end\n")
        }
        let exported = state.functions.filter { $0.kind == .exportedSymbol }
        if !exported.isEmpty {
            lines.append("/* Exported C / Native Entry Points */")
            for fn in exported {
                let sig = state.pseudocode[fn.address.value]?.signature
                    ?? "int64_t \(ReconstructionUtilities.cFunctionName(for: fn.name))(void)"
                lines.append("\(sig);")
            }
        }
        return lines.joined(separator: "\n")
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Picker("", selection: $mode) {
                    Text("Swift (\(swiftItems.count))").tag(0)
                    Text("Objective-C (\(objcItems.count))").tag(1)
                    Text("Types (\(state.types.count))").tag(2)
                    Text("Synthesized Header").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 460)

                Spacer()
                TextField("Filter types or methods…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 220)
            }
            .padding(8)
            .background(.bar)

            Divider()

            switch mode {
            case 0:
                if swiftItems.isEmpty {
                    EmptyStateView(systemImage: "swift", title: "No Swift Mangled Symbols",
                                   message: "This binary contains no $s / _$s Swift symbols or is stripped.")
                } else {
                    List(Array(swiftItems.prefix(500).enumerated()), id: \.offset) { _, item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.demangled)
                                    .font(.system(.callout, design: .monospaced))
                                Text(item.raw)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let a = item.addr {
                                Button(a.hexString) {
                                    if let fn = state.function(containing: a) { state.selectFunction(fn) }
                                    else { state.navigate(to: a) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            case 1:
                if objcItems.isEmpty {
                    EmptyStateView(systemImage: "curlybraces", title: "No Objective-C Classes",
                                   message: "No Objective-C class or method symbols were found in this slice.")
                } else {
                    List(objcItems, id: \.cls) { entry in
                        DisclosureGroup("@interface \(entry.cls) (\(entry.methods.count) methods)") {
                            ForEach(Array(entry.methods.enumerated()), id: \.offset) { _, m in
                                HStack {
                                    Text(m.name).font(.system(.caption, design: .monospaced))
                                    Spacer()
                                    if let a = m.addr {
                                        Button(a.hexString) {
                                            if let fn = state.function(containing: a) { state.selectFunction(fn) }
                                            else { state.navigate(to: a) }
                                        }
                                        .controlSize(.mini)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            case 2:
                if state.types.isEmpty {
                    EmptyStateView(systemImage: "square.stack.3d.up", title: "No Recovered Types",
                                   message: "Run analysis to recover types from symbols and metadata.")
                } else {
                    List(state.types) { t in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(t.kind.rawValue) \(t.name)")
                                .font(.system(.callout, design: .monospaced).weight(.medium))
                            if let sz = t.size {
                                Text("\(sz) bytes · \(t.fields.count) fields")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            default:
                VStack(spacing: 0) {
                    HStack {
                        Text("Generated C / Objective-C Interface Header")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        CopyButton(synthesizedHeader, label: "Copy .h")
                    }
                    .padding(8)
                    Divider()
                    ScrollView {
                        Text(synthesizedHeader)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }
            }
        }
    }
}

public struct BinarySecurityScannerView: View {
    @Bindable var state: DecompilerObservableState

    public init(state: DecompilerObservableState) {
        self.state = state
    }

    public var body: some View {
        if let image = state.binary {
            let checks = BinaryAdvancedAnalyzer.hardeningChecks(image: image)
            let entropies = BinaryAdvancedAnalyzer.analyzeSectionEntropy(image: image)
            let urlStrings = state.strings.filter {
                $0.text.contains("http://") || $0.text.contains("https://") || $0.text.contains("ws://")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox("Binary Hardening & Exploit Mitigations") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(checks) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Image(systemName: item.passed ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(item.passed ? .green : .orange)
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                        .frame(width: 230, alignment: .leading)
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                        }
                        .padding(6)
                    }

                    GroupBox("Section Shannon Entropy (0.00 – 8.00 bits/byte)") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(entropies) { sec in
                                HStack(spacing: 10) {
                                    Text("\(sec.segment).\(sec.section)")
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(width: 190, alignment: .leading)
                                    ProgressView(value: min(max(sec.entropy, 0), 8.0), total: 8.0)
                                        .tint(sec.entropy >= 7.2 ? .red : (sec.entropy >= 6.0 ? .blue : .green))
                                        .frame(maxWidth: 220)
                                    Text(String(format: "%.2f", sec.entropy))
                                        .font(.system(.caption, design: .monospaced).bold())
                                        .frame(width: 42, alignment: .trailing)
                                    Text(sec.classification)
                                        .font(.caption2)
                                        .foregroundStyle(sec.entropy >= 7.2 ? .red : .secondary)
                                    Spacer()
                                }
                            }
                        }
                        .padding(6)
                    }

                    if !urlStrings.isEmpty {
                        GroupBox("Embedded URLs & Endpoints (\(urlStrings.count))") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(urlStrings.prefix(30).enumerated()), id: \.offset) { _, s in
                                    HStack {
                                        Text(s.address.hexString)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text(s.text)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(6)
                        }
                    }
                }
                .padding(14)
            }
        } else {
            EmptyStateView(systemImage: "lock.shield", title: "No Binary Loaded",
                           message: "Import a binary to audit exploit mitigations and section entropy.")
        }
    }
}

public struct BytePatternScannerView: View {
    @Bindable var state: DecompilerObservableState
    @State private var hexQuery = "FD 7B BF A9"
    @State private var hits: [PatternMatchHit] = []
    @State private var didSearch = false

    private let presets: [(String, String)] = [
        ("ARM64 Frame Prologue (stp x29, x30)", "FD 7B BF A9"),
        ("ARM64 PAC Prologue (pacibsp)", "7F 23 03 D5"),
        ("ARM64 Return (ret)", "C0 03 5F D6"),
        ("x86_64 Frame Prologue (push rbp; mov rbp, rsp)", "55 48 89 E5"),
        ("Mach-O 64 Magic", "CF FA ED FE"),
    ]

    public init(state: DecompilerObservableState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle")
                    .foregroundStyle(.secondary)
                TextField("Hex bytes with ?? wildcards (e.g. FD 7B ?? A9)…", text: $hexQuery)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.callout, design: .monospaced))
                    .onSubmit { runScan() }

                Menu("Presets") {
                    ForEach(presets, id: \.0) { p in
                        Button(p.0) {
                            hexQuery = p.1
                            runScan()
                        }
                    }
                }
                .controlSize(.small)
                .fixedSize()

                Button("Scan Binary") { runScan() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(state.binary == nil)
            }
            .padding(10)
            .background(.bar)

            Divider()

            if state.binary == nil {
                EmptyStateView(systemImage: "magnifyingglass", title: "No Binary Loaded",
                               message: "Import a Mach-O, ELF or PE binary to scan byte signatures.")
            } else if hits.isEmpty {
                EmptyStateView(
                    systemImage: "number.square",
                    title: didSearch ? "No Signature Matches" : "Byte Signature & Wildcard Scanner",
                    message: didSearch ? "No occurrences matched '\(hexQuery)'." : "Enter hex bytes (use ?? for single-byte wildcards) and click Scan Binary."
                )
            } else {
                List(hits) { hit in
                    Button {
                        state.navigate(to: hit.address)
                        if let fn = state.function(containing: hit.address) {
                            state.selectFunction(fn)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(hit.address.hexString)
                                .font(.system(.callout, design: .monospaced).weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 110, alignment: .leading)
                            Text(hit.sectionName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 140, alignment: .leading)
                            Text(hit.previewHex)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            if let fn = hit.containingFunction {
                                Text(SymbolDemangler.demangle(fn))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 200, alignment: .trailing)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
    }

    private func runScan() {
        guard let image = state.binary else { return }
        didSearch = true
        hits = BinaryAdvancedAnalyzer.scanHexPattern(pattern: hexQuery, image: image, functions: state.functions)
    }
}
