import SwiftUI
import AppKit

/// Spec-named aliases for the Master-mode browsers.
public typealias FunctionBrowser = MasterFunctionBrowser
public typealias SymbolBrowser = MasterSymbolBrowser
public typealias MemoryMapView = SectionsBrowser

// MARK: - Shared list chrome for master browsers

private struct BrowserHeader: View {
    @Binding var searchText: String
    let placeholder: String
    let countText: String
    var body: some View {
        HStack {
            SearchBar(text: $searchText, placeholder: placeholder)
            Text(countText).font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
    }
}

// MARK: - Function browser

public struct MasterFunctionBrowser: View {
    @Bindable var state: DecompilerObservableState
    @Binding var searchText: String

    public init(state: DecompilerObservableState, searchText: Binding<String>) {
        self.state = state
        self._searchText = searchText
    }

    private var filtered: [DecompilerFunction] {
        guard !searchText.isEmpty else { return state.functions }
        let q = searchText.lowercased()
        return state.functions.filter {
            $0.displayName.lowercased().contains(q)
                || $0.address.hexString.lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            BrowserHeader(searchText: $searchText, placeholder: "Filter functions",
                          countText: "\(filtered.count)/\(state.functions.count)")
            List(filtered, selection: Binding(
                get: { state.selectedFunctionAddress },
                set: { addr in
                    if let addr { state.selectFunction(at: DecompilerAddress(virtual: addr.value)) }
                }
            )) { fn in
                HStack(spacing: 6) {
                    Text(fn.address.hexString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .trailing)
                    Text(fn.displayName)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    if fn.hasPseudocode {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .tag(fn.address)
                .contextMenu {
                    Button("Copy Address") { NSPasteboardCopy(fn.address.hexString) }
                    Button("Disassemble") {
                        state.selectFunction(fn)
                        Task { try? await state.loadDisassembly() }
                    }
                    Button("Decompile") {
                        state.selectFunction(fn)
                        Task { try? await state.decompileSelected() }
                    }
                    Divider()
                    Button(fn.isPinned ? "Unpin" : "Pin") {
                        Task { await state.togglePin(at: fn.address) }
                    }
                }
            }
        }
    }
}

// MARK: - Symbol browser

public struct MasterSymbolBrowser: View {
    @Bindable var state: DecompilerObservableState
    @Binding var searchText: String

    public init(state: DecompilerObservableState, searchText: Binding<String>) {
        self.state = state
        self._searchText = searchText
    }

    private var filtered: [BinarySymbol] {
        guard !searchText.isEmpty else { return state.symbols }
        let q = searchText.lowercased()
        return state.symbols.filter {
            $0.effectiveName.lowercased().contains(q) || $0.name.lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            BrowserHeader(searchText: $searchText, placeholder: "Filter symbols",
                          countText: "\(filtered.count)/\(state.symbols.count)")
            List(filtered, id: \.id) { sym in
                HStack(spacing: 6) {
                    Text(sym.kind.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sym.effectiveName)
                            .font(.system(.callout, design: .monospaced))
                            .lineLimit(1)
                        if let addr = sym.address {
                            Text(addr.hexString).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let addr = sym.address { state.selectAddress(addr) }
                }
                .contextMenu {
                    Button("Copy Name") { NSPasteboardCopy(sym.effectiveName) }
                    if let addr = sym.address {
                        Button("Copy Address") { NSPasteboardCopy(addr.hexString) }
                        Button("Go to Address") { state.navigate(to: addr) }
                    }
                }
            }
        }
    }
}

// MARK: - Import / export browsers

public struct MasterImportBrowser: View {
    let state: DecompilerObservableState
    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        List(state.binary?.imports ?? [], id: \.self) { imp in
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle").foregroundStyle(.orange).frame(width: 14)
                Text(imp.name).font(.system(.callout, design: .monospaced)).lineLimit(1)
                Spacer()
                Text(imp.library).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .contextMenu {
                Button("Copy Name") { NSPasteboardCopy(imp.name) }
            }
        }
    }
}

public struct MasterExportBrowser: View {
    let state: DecompilerObservableState
    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        List(state.binary?.exports ?? [], id: \.self) { exp in
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle").foregroundStyle(.green).frame(width: 14)
                Text(exp.name).font(.system(.callout, design: .monospaced)).lineLimit(1)
                Spacer()
                Text(exp.address.hexString).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { state.selectAddress(exp.address) }
            .contextMenu {
                Button("Copy Name") { NSPasteboardCopy(exp.name) }
                Button("Go to Address") { state.navigate(to: exp.address) }
            }
        }
    }
}

// MARK: - Strings browser (master)

public struct MasterStringsBrowser: View {
    @Bindable var state: DecompilerObservableState
    @Binding var searchText: String

    public init(state: DecompilerObservableState, searchText: Binding<String>) {
        self.state = state
        self._searchText = searchText
    }

    private var filtered: [BinaryString] {
        guard !searchText.isEmpty else { return state.strings }
        let q = searchText.lowercased()
        return state.strings.filter { $0.text.lowercased().contains(q) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            BrowserHeader(searchText: $searchText, placeholder: "Filter strings",
                          countText: "\(filtered.count)/\(state.strings.count)")
            List(filtered, id: \.self) { s in
                HStack(spacing: 6) {
                    Text(s.address.hexString)
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                    Text(s.text).font(.system(.callout, design: .monospaced)).lineLimit(1)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { state.selectAddress(s.address) }
                .contextMenu {
                    Button("Copy String") { NSPasteboardCopy(s.text) }
                    Button("Go to Address") { state.navigate(to: s.address) }
                }
            }
        }
    }
}

// MARK: - Sections / memory map

/// Segment/section table with protection flags — the memory map.
public struct SectionsBrowser: View {
    let state: DecompilerObservableState
    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        List {
            ForEach(state.binary?.segments ?? [], id: \.name) { seg in
                Section {
                    ForEach(seg.sections, id: \.name) { sec in
                        HStack(spacing: 6) {
                            Text(sec.name)
                                .font(.system(.callout, design: .monospaced))
                            Spacer()
                            Text(sec.address.hexString)
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text("\(sec.size)")
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text(protections(sec))
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 4)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { state.selectAddress(sec.address) }
                        .contextMenu {
                            Button("Copy Address") { NSPasteboardCopy(sec.address.hexString) }
                            Button("Go to Address") { state.navigate(to: sec.address) }
                        }
                    }
                } header: {
                    HStack {
                        Text(seg.name).font(.headline.monospaced())
                        Spacer()
                        Text("vm \(String(seg.vmAddress, radix: 16)) +\(seg.vmSize)")
                            .font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func protections(_ sec: BinarySectionInfo) -> String {
        var p = ""
        p += sec.isExecutable ? "x" : "-"
        p += sec.isWritable ? "w" : "-"
        return p
    }
}

// MARK: - Cross references

public struct ReferenceBrowser: View {
    let state: DecompilerObservableState
    public init(state: DecompilerObservableState) { self.state = state }

    /// Xrefs touching the current selection first, then the rest.
    private var relevant: [CrossReference] {
        guard let sel = state.selectedAddress?.value else { return state.crossReferences }
        return state.crossReferences.filter {
            $0.source.value == sel || $0.destination.value == sel
        }
    }

    public var body: some View {
        List(relevant.prefix(2000)) { ref in
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon(for: ref.kind))
                        .foregroundStyle(color(for: ref.kind))
                        .frame(width: 14)
                    Text(ref.kind.rawValue).font(.caption.weight(.medium))
                    Spacer()
                }
                HStack(spacing: 4) {
                    Text(ref.source.hexString).font(.caption2.monospaced())
                    Image(systemName: "arrow.right").font(.caption2)
                    Text(ref.destination.hexString).font(.caption2.monospaced())
                }
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { state.navigate(to: ref.destination) }
            .contextMenu {
                Button("Go to Source") { state.navigate(to: ref.source) }
                Button("Go to Destination") { state.navigate(to: ref.destination) }
            }
        }
    }

    private func icon(for kind: CrossReference.Kind) -> String {
        switch kind {
        case .call: return "phone.arrow.up.right"
        case .jump, .branch: return "arrow.turn.down.right"
        case .data, .string, .symbol, .section, .memory: return "cube"
        }
    }

    private func color(for kind: CrossReference.Kind) -> Color {
        switch kind {
        case .call: return .purple
        case .jump, .branch: return .blue
        default: return .secondary
        }
    }
}

// MARK: - Analysis console

/// Bottom console: progress, console log lines, and analysis history.
public struct AnalysisConsole: View {
    @Bindable var state: DecompilerObservableState
    @State private var showHistory = false

    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "text.alignleft").foregroundStyle(.secondary)
                Text("Console").font(.headline)
                Spacer()
                Picker("View", selection: $showHistory) {
                    Text("Log").tag(false)
                    Text("History").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                Button("Clear") { state.clearConsole() }
                    .controlSize(.small)
                    .disabled(state.consoleMessages.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            Divider()
            if showHistory {
                List(Array(state.history.reversed().prefix(500))) { entry in
                    HStack(spacing: 8) {
                        Text(entry.date, style: .time).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        Image(systemName: entry.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(entry.succeeded ? .green : .red)
                            .font(.caption2)
                        Text(entry.operation).font(.caption)
                        Text(entry.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(state.consoleMessages) { msg in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(msg.date, style: .time)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                    Text(msg.text)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(color(for: msg.kind))
                                        .textSelection(.enabled)
                                    Spacer(minLength: 0)
                                }
                                .id(msg.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: state.consoleMessages.count) { _, _ in
                        if let last = state.consoleMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .background(.bar)
    }

    private func color(for kind: ConsoleMessage.Kind) -> Color {
        switch kind {
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        case .engine: return .blue
        }
    }
}

// MARK: - Master inspector

public struct MasterInspectorView: View {
    @Bindable var state: DecompilerObservableState

    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch state.inspectorItem {
                case .function:
                    if let fn = state.selectedFunction { functionSection(fn) }
                case .address:
                    addressSection
                case .instruction:
                    instructionSection
                case .binary, .none:
                    binarySection
                }

                if let fn = state.selectedFunction {
                    pseudocodeSection(fn)
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func functionSection(_ fn: DecompilerFunction) -> some View {
        InspectorPanel(fn.displayName, subtitle: fn.address.hexString) {
            InfoRow("Address", fn.address.hexString, mono: true)
            InfoRow("Size", "\(fn.size) bytes")
            InfoRow("Kind", fn.kind.rawValue)
            if let end = fn.endAddress { InfoRow("End", end.hexString, mono: true) }
            if let orig = fn.originalName, orig != fn.name {
                InfoRow("Original", orig, mono: true)
            }
            InfoRow("Callers", "\(fn.callers.count)")
            InfoRow("Callees", "\(fn.callees.count)")
            HStack {
                Button("Rename…") { renamePrompt(fn) }.controlSize(.small)
                Button(fn.isPinned ? "Unpin" : "Pin") {
                    Task { await state.togglePin(at: fn.address) }
                }.controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Callers").font(.callout.weight(.medium))
                ForEach(fn.callers.prefix(30), id: \.hexString) { addr in
                    Button(addr.hexString) { state.navigate(to: addr) }
                        .buttonStyle(.link)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
    }

    private var addressSection: some View {
        InspectorPanel("Address", subtitle: state.selectedAddress?.hexString) {
            if let addr = state.selectedAddress {
                InfoRow("Address", addr.hexString, mono: true)
                InfoRow("Space", addr.kind.rawValue)
                if let fn = state.function(containing: addr) {
                    InfoRow("Function", fn.displayName)
                    Button("Select \(fn.displayName)") { state.selectFunction(fn) }.controlSize(.small)
                }
                if let label = state.userLabels[addr.hexString] { InfoRow("Label", label) }
                if let comment = state.comments[addr.hexString] { InfoRow("Comment", comment) }
                HStack {
                    Button("Pin") { Task { await state.togglePin(at: addr) } }.controlSize(.small)
                    Button("Label…") { labelPrompt(addr) }.controlSize(.small)
                    Button("Comment…") { commentPrompt(addr) }.controlSize(.small)
                }
            } else {
                Text("No address selected.").foregroundStyle(.secondary)
            }
        }
    }

    private var instructionSection: some View {
        InspectorPanel("Instruction") {
            if let range = state.selectedInstructionRange,
               let ins = state.disassembly.first(where: { range.contains($0.address.value) }) {
                InfoRow("Address", ins.address.hexString, mono: true)
                InfoRow("Bytes", ins.rawBytes.map { String(format: "%02x", $0) }.joined(separator: " "), mono: true)
                InfoRow("Text", ins.text, mono: true)
                InfoRow("Class", ins.classification.rawValue)
                if let t = ins.branchTarget {
                    InfoRow("Target", t.hexString, mono: true)
                    Button("Go to target") { state.navigate(to: t) }.controlSize(.small)
                }
                InfoRow("Xrefs", "\(ins.referenceCount)")
            } else {
                Text("Select an instruction.").foregroundStyle(.secondary)
            }
        }
    }

    private var binarySection: some View {
        InspectorPanel("Binary") {
            if let image = state.binary {
                InfoRow("Format", image.format.displayName)
                InfoRow("Arch", image.architecture.displayName)
                InfoRow("Entry", image.entryPoint?.hexString ?? "—", mono: true)
                InfoRow("Signed", image.isSigned ? "Yes" : "No")
                InfoRow("Encrypted", image.isEncrypted ? "Yes" : "No")
                InfoRow("Debug info", image.hasDebugInfo ? "Yes" : "No")
                InfoRow("UUID", image.identity.binaryUUID ?? "—", mono: true)
            } else {
                Text("No binary loaded.").foregroundStyle(.secondary)
            }
        }
    }

    private func pseudocodeSection(_ fn: DecompilerFunction) -> some View {
        InspectorPanel("Pseudocode") {
            if let result = state.pseudocode(for: fn) {
                Text(result.signature ?? result.functionName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                ScrollView {
                    Text(result.pseudocode)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 260)
            } else {
                Text("No pseudocode for this function.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Decompile") {
                    state.selectFunction(fn)
                    Task { try? await state.decompileSelected() }
                }
                .controlSize(.small)
            }
        }
    }

    private func renamePrompt(_ fn: DecompilerFunction) {
        let alert = NSAlert()
        alert.messageText = "Rename Function"
        alert.informativeText = "New name for \(fn.displayName)"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = fn.name
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { Task { await state.renameSelectedFunction(to: name) } }
        }
    }

    private func labelPrompt(_ addr: DecompilerAddress) {
        let alert = NSAlert()
        alert.messageText = "Add Label"
        alert.informativeText = "Label for \(addr.hexString)"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { Task { await state.addLabel(name, at: addr) } }
        }
    }

    private func commentPrompt(_ addr: DecompilerAddress) {
        let alert = NSAlert()
        alert.messageText = "Add Comment"
        alert.informativeText = "Comment for \(addr.hexString)"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let text = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { Task { await state.addComment(text, at: addr) } }
        }
    }
}
