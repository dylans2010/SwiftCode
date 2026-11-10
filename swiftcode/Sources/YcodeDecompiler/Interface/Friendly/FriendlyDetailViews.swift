import SwiftUI
import AppKit

// MARK: - Binary overview

/// Friendly landing page: what binary is loaded, what analysis found.
public struct BinaryOverviewView: View {
    @Bindable var state: DecompilerObservableState

    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let image = state.binary {
                    ExplainedSection("Binary", explanation: Explainer.address) {
                        VStack(alignment: .leading, spacing: 4) {
                            InfoRow("Name", image.identity.originalFileName)
                            InfoRow("Format", image.format.displayName)
                            InfoRow("Architecture", image.architecture.displayName)
                            InfoRow("CPU", image.cpuIdentifier, mono: true)
                            InfoRow("File size", ByteCountFormatter.string(fromByteCount: image.identity.fileSize, countStyle: .file))
                            InfoRow("Entry point", image.entryPoint?.hexString ?? "—", mono: true)
                            InfoRow("SHA-256", String(image.identity.sha256.prefix(16)) + "…", mono: true)
                            if !image.identity.sliceName.isEmpty {
                                InfoRow("Slice", image.identity.sliceName)
                            }
                            if let build = image.buildVersion {
                                InfoRow("Build", build)
                            }
                            if let minOS = image.minOSVersion {
                                InfoRow("Min OS", minOS)
                            }
                        }
                    }

                    ExplainedSection("Analysis", explanation: Explainer.provenance) {
                        let counts = state.overviewCounts
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                            countCard("Functions", counts.functions, "function", .blue)
                            countCard("Symbols", counts.symbols, "tag", .purple)
                            countCard("Imports", counts.imports, "arrow.down.circle", .orange)
                            countCard("Exports", counts.exports, "arrow.up.circle", .green)
                            countCard("Strings", counts.strings, "textformat", .teal)
                            countCard("Sections", counts.sections, "square.split.2x2", .indigo)
                        }
                        HStack(spacing: 16) {
                            Label(image.hasDebugInfo ? "Debug info present" : "No debug info",
                                  systemImage: image.hasDebugInfo ? "checkmark.seal" : "exclamationmark.triangle")
                                .foregroundStyle(image.hasDebugInfo ? .green : .orange)
                                .help(image.hasDebugInfo ? Explainer.debugInfo : "This binary was stripped or never had DWARF/PDB debug info, so variable names and types may be missing.")
                            if image.isEncrypted {
                                Label("Encrypted", systemImage: "lock.fill").foregroundStyle(.red)
                            }
                            if image.isSigned {
                                Label("Signed", systemImage: "checkmark.shield").foregroundStyle(.green)
                            }
                        }
                        .font(.callout)
                    }

                    if !state.slices.isEmpty {
                        ExplainedSection("Architecture slices") {
                            Picker("Slice", selection: Binding(
                                get: { state.binary?.identity.sliceIndex ?? 0 },
                                set: { index in Task { try? await state.selectSlice(index) } }
                            )) {
                                ForEach(state.slices, id: \.index) { slice in
                                    Text("\(slice.name) — \(slice.architecture.displayName)").tag(slice.index)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 320)
                        }
                    }

                    if state.functions.isEmpty && !state.isAnalyzing {
                        Button("Run Analysis") { state.startAnalysis() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    EmptyStateView(
                        systemImage: "doc.badge.plus",
                        title: "No binary loaded",
                        message: "Import a Mach-O, ELF, or PE binary to start reverse-engineering it. Use Import Binary in the toolbar.",
                        actionTitle: "Import Binary",
                        action: { DecompilerCommands.perform(.openBinary) }
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private func countCard(_ title: String, _ value: Int, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)").font(.title3.weight(.semibold).monospacedDigit())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Function browser

/// Searchable, sortable function list. Selecting a row selects the function
/// and loads its pseudocode (decompiling on demand).
public struct FriendlyFunctionBrowser: View {
    @Bindable var state: DecompilerObservableState
    @Binding var searchText: String
    @State private var sortByName = false

    public init(state: DecompilerObservableState, searchText: Binding<String>) {
        self.state = state
        self._searchText = searchText
    }

    private var filtered: [DecompilerFunction] {
        var list = state.functions
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.displayName.lowercased().contains(q)
                    || $0.address.hexString.lowercased().contains(q)
                    || ($0.originalName?.lowercased().contains(q) ?? false)
            }
        }
        if sortByName {
            list.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        return list
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                SearchBar(text: $searchText, placeholder: "Filter functions")
                Toggle("Sort by name", isOn: $sortByName)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            .padding(10)

            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: state.binary == nil ? "doc.badge.plus" : "function",
                    title: state.binary == nil ? "No binary loaded" : "No functions",
                    message: state.binary == nil
                        ? "Import a binary, then run analysis to discover functions."
                        : (state.isAnalyzing ? "Analysis is running…" : "Run analysis to discover functions in this binary.")
                )
            } else {
                List(filtered, selection: Binding(
                    get: { state.selectedFunctionAddress },
                    set: { addr in
                        if let addr { state.selectFunction(at: DecompilerAddress(virtual: addr.value)) }
                    }
                )) { fn in
                    HStack(spacing: 8) {
                        Image(systemName: icon(for: fn.kind))
                            .foregroundStyle(color(for: fn.kind))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(fn.displayName)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                            Text("\(fn.address.hexString) · \(fn.size) bytes")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if fn.hasPseudocode {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(.secondary)
                                .help("Pseudocode available")
                        }
                        if fn.isPinned {
                            Image(systemName: "pin.fill").foregroundStyle(.orange)
                                .font(.caption2)
                        }
                    }
                    .tag(fn.address)
                    .contextMenu {
                        Button("Copy Address") {
                            NSPasteboardCopy(fn.address.hexString)
                        }
                        Button(fn.isPinned ? "Unpin" : "Pin") {
                            Task { await state.togglePin(at: fn.address) }
                        }
                        Divider()
                        Button("Disassemble") {
                            state.selectFunction(fn)
                            Task { try? await state.loadDisassembly() }
                        }
                        Button("Decompile") {
                            state.selectFunction(fn)
                            Task { try? await state.decompileSelected() }
                        }
                    }
                }
            }
        }
    }

    private func icon(for kind: DecompilerFunction.Kind) -> String {
        switch kind {
        case .entryPoint: return "play.fill"
        case .importedSymbol: return "arrow.down.circle"
        case .exportedSymbol: return "arrow.up.circle"
        case .thunk: return "arrowshape.turn.up.right"
        case .userLabel: return "bookmark"
        case .discovered: return "function"
        }
    }

    private func color(for kind: DecompilerFunction.Kind) -> Color {
        switch kind {
        case .entryPoint: return .green
        case .importedSymbol: return .orange
        case .exportedSymbol: return .blue
        case .thunk: return .purple
        case .userLabel: return .pink
        case .discovered: return .secondary
        }
    }
}

// MARK: - Code viewer (pseudocode with disassembly fallback)

/// Shows pseudocode for the selected function; falls back to a disassembly
/// listing when no decompiler backend produced pseudocode.
public struct FriendlyCodeViewer: View {
    @Bindable var state: DecompilerObservableState
    @State private var showingDisassembly = false
    @State private var errorMessage: String?

    public init(state: DecompilerObservableState) { self.state = state }

    private var result: DecompilationResult? {
        guard let fn = state.selectedFunction else { return nil }
        return state.pseudocode(for: fn)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let fn = state.selectedFunction {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fn.displayName).font(.headline.monospaced())
                        Text("\(fn.address.hexString) · \(fn.size) bytes · \(fn.kind.rawValue)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("View", selection: $showingDisassembly) {
                        Text("Pseudocode").tag(false)
                        Text("Disassembly").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    .disabled(result == nil && state.disassembly.isEmpty)
                    Button("Decompile") {
                        Task {
                            do { _ = try await state.decompileSelected() }
                            catch { errorMessage = error.localizedDescription }
                        }
                    }
                    .disabled(state.isAnalyzing)
                    CopyButton(result?.pseudocode ?? state.disassembly.map(\.text).joined(separator: "\n") ?? "")
                }
                .padding(10)
                Divider()
            }

            content
        }
        .alert("Decompilation failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if state.selectedFunction == nil {
            EmptyStateView(
                systemImage: "chevron.left.forwardslash.chevron.right",
                title: "No function selected",
                message: "Pick a function in the Functions section to see its pseudocode or disassembly."
            )
        } else if showingDisassembly || (result == nil && !state.disassembly.isEmpty) {
            if state.disassembly.isEmpty {
                DisassemblyLoadingView(state: state)
            } else {
                DisassemblyListingView(instructions: state.disassembly)
            }
        } else if let result {
            PseudocodeTextView(result: result)
        } else {
            EmptyStateView(
                systemImage: "wand.and.stars",
                title: "No pseudocode yet",
                message: "No decompiler backend has produced pseudocode for this function. You can still view its disassembly.",
                actionTitle: "Load Disassembly",
                action: {
                    Task { try? await state.loadDisassembly() ; showingDisassembly = true }
                }
            )
        }
    }
}

/// Loads disassembly for the selected function on appear.
private struct DisassemblyLoadingView: View {
    let state: DecompilerObservableState
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Disassembling…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await state.loadDisassembly()
        }
    }
}

/// Simple monospace listing used by the Friendly code view.
public struct DisassemblyListingView: View {
    let instructions: [Instruction]

    public init(instructions: [Instruction]) { self.instructions = instructions }

    public var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(instructions) { ins in
                    HStack(alignment: .top, spacing: 10) {
                        Text(ins.address.hexString)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .trailing)
                        Text(byteString(ins.rawBytes))
                            .foregroundStyle(.tertiary)
                            .frame(width: 110, alignment: .leading)
                        Text(ins.text)
                            .foregroundStyle(mnemonicColor(ins.classification))
                        if let label = ins.label {
                            Text(label).foregroundStyle(.blue)
                        }
                        if let comment = ins.comment {
                            Text("; \(comment)").foregroundStyle(.orange)
                        }
                    }
                    .font(.system(.callout, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .contextMenu {
                        Button("Copy Address") { NSPasteboardCopy(ins.address.hexString) }
                        Button("Copy Instruction") { NSPasteboardCopy(ins.text) }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func byteString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private func mnemonicColor(_ c: Instruction.Classification) -> Color {
        switch c {
        case .call: return .purple
        case .branch, .returnInstruction: return .blue
        case .invalid, .data: return .red
        default: return .primary
        }
    }
}

/// Pseudocode with line numbers.
public struct PseudocodeTextView: View {
    let result: DecompilationResult

    public init(result: DecompilationResult) { self.result = result }

    private var lines: [String] {
        result.pseudocode.components(separatedBy: .newlines)
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(lines.indices, id: \.self) { i in
                    Text("\(i + 1)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(height: 18, alignment: .top)
                }
            }
            .padding(.trailing, 10)
            .padding(.top, 6)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i])
                            .font(.system(.callout, design: .monospaced))
                            .frame(height: 18, alignment: .top)
                            .textSelection(.enabled)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 0)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - Strings browser

public struct StringsBrowser: View {
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
            HStack {
                SearchBar(text: $searchText, placeholder: "Filter strings")
                Text("\(filtered.count) of \(state.strings.count)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)

            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "textformat",
                    title: state.binary == nil ? "No binary loaded" : "No strings",
                    message: state.binary == nil ? "Import a binary first." : "Run analysis to extract strings, or none were found."
                )
            } else {
                List(filtered, id: \.self) { s in
                    HStack {
                        Text(s.text)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Spacer()
                        Text(s.address.hexString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.selectAddress(s.address, inspector: .address)
                    }
                    .contextMenu {
                        Button("Copy String") { NSPasteboardCopy(s.text) }
                        Button("Copy Address") { NSPasteboardCopy(s.address.hexString) }
                        Button("Go to Address") { state.navigate(to: s.address) }
                    }
                }
            }
        }
    }
}

// MARK: - Dependencies browser

public struct DependenciesBrowser: View {
    @Bindable var state: DecompilerObservableState

    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        List {
            ExplainedSection("Imports", explanation: Explainer.importSymbol) {
                ForEach(state.binary?.imports ?? [], id: \.self) { imp in
                    HStack {
                        Image(systemName: "arrow.down.circle").foregroundStyle(.orange)
                        Text(imp.name).font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(imp.library).font(.caption).foregroundStyle(.secondary)
                        if imp.isWeak { Text("weak").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            }
            ExplainedSection("Exports", explanation: Explainer.exportSymbol) {
                ForEach(state.binary?.exports ?? [], id: \.self) { exp in
                    HStack {
                        Image(systemName: "arrow.up.circle").foregroundStyle(.green)
                        Text(exp.name).font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(exp.address.hexString).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { state.selectAddress(exp.address) }
                }
            }
            ExplainedSection("Linked libraries") {
                ForEach(state.binary?.dependencies ?? [], id: \.self) { dep in
                    HStack {
                        Image(systemName: "shippingbox").foregroundStyle(.secondary)
                        Text(dep.path).font(.system(.callout, design: .monospaced))
                        Spacer()
                        Text(dep.kind).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Symbols browser

public struct SymbolsBrowser: View {
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
            HStack {
                SearchBar(text: $searchText, placeholder: "Filter symbols")
                Text("\(filtered.count) of \(state.symbols.count)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            List(filtered) { sym in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sym.effectiveName).font(.system(.body, design: .monospaced)).lineLimit(1)
                        if sym.userName != nil {
                            Text("original: \(sym.name)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(sym.kind.rawValue).font(.caption2).foregroundStyle(.secondary)
                    if let addr = sym.address {
                        Text(addr.hexString).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let addr = sym.address { state.selectAddress(addr, inspector: .address) }
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

// MARK: - Binary information (segments/sections/signature)

public struct BinaryInfoView: View {
    @Bindable var state: DecompilerObservableState

    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let image = state.binary {
                    ExplainedSection("Segments & sections", explanation: Explainer.segment) {
                        ForEach(image.segments, id: \.name) { seg in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(seg.name).font(.headline.monospaced())
                                    Spacer()
                                    Text(protectionString(seg)).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                                ForEach(seg.sections, id: \.name) { sec in
                                    HStack {
                                        Text("  " + sec.name)
                                            .font(.system(.callout, design: .monospaced))
                                        Spacer()
                                        Text(sec.address.hexString)
                                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                                        Text("\(sec.size) B")
                                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    ExplainedSection("Code signature", explanation: Explainer.entitlements) {
                        InfoRow("Signed", image.isSigned ? "Yes" : "No")
                        if let info = image.codeSignatureInfo {
                            Text(info).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                        }
                        if let ent = image.entitlements {
                            Text("Entitlements").font(.callout.weight(.medium))
                            Text(ent).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                } else {
                    EmptyStateView(systemImage: "info.square", title: "No binary loaded",
                                   message: "Import a binary to inspect its segments, sections, and signature.")
                }
            }
            .padding(20)
        }
    }

    private func protectionString(_ seg: BinarySegmentInfo) -> String {
        var parts: [String] = []
        // Mach-O VM protection bits: 1=read, 2=write, 4=execute.
        if seg.initialProtection & 1 != 0 { parts.append("r") }
        if seg.initialProtection & 2 != 0 { parts.append("w") }
        if seg.initialProtection & 4 != 0 { parts.append("x") }
        return parts.isEmpty ? "---" : parts.joined()
    }
}

// MARK: - Analysis history

public struct AnalysisHistoryView: View {
    let state: DecompilerObservableState

    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        List(Array(state.history.reversed())) { entry in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: entry.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(entry.succeeded ? .green : .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.operation).font(.callout.weight(.medium))
                    if !entry.detail.isEmpty {
                        Text(entry.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.date, style: .time).font(.caption.monospacedDigit())
                    Text(entry.date, style: .date).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Friendly inspector

/// Contextual inspector for Friendly mode: shows details for whatever is
/// selected — function, address, instruction, or the binary itself.
public struct FriendlyInspectorView: View {
    @Bindable var state: DecompilerObservableState

    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        switch state.inspectorItem {
        case .function:
            if let fn = state.selectedFunction {
                functionInspector(fn)
            } else {
                fallbackInspector
            }
        case .address:
            addressInspector
        case .instruction:
            instructionInspector
        case .binary, .none:
            binaryInspector
        }
    }

    private var fallbackInspector: some View {
        InspectorPanel("Nothing selected") {
            Text("Select a function, address, or instruction to see details here.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var binaryInspector: some View {
        InspectorPanel("Binary", subtitle: state.binary?.identity.originalFileName) {
            if let image = state.binary {
                InfoRow("Format", image.format.displayName)
                InfoRow("Architecture", image.architecture.displayName)
                InfoRow("Entry", image.entryPoint?.hexString ?? "—", mono: true)
                InfoRow("Functions", "\(state.functions.count)")
                InfoRow("Symbols", "\(state.symbols.count)")
                InfoRow("Strings", "\(state.strings.count)")
                InfoRow("Debug info", image.hasDebugInfo ? "Yes" : "No")
            } else {
                Text("No binary loaded.").foregroundStyle(.secondary)
            }
        }
    }

    private func functionInspector(_ fn: DecompilerFunction) -> some View {
        InspectorPanel(fn.displayName, subtitle: fn.address.hexString) {
            InfoRow("Address", fn.address.hexString, mono: true)
            InfoRow("Size", "\(fn.size) bytes")
            InfoRow("Kind", fn.kind.rawValue)
            if let end = fn.endAddress {
                InfoRow("End", end.hexString, mono: true)
            }
            if let orig = fn.originalName, orig != fn.name {
                InfoRow("Original name", orig, mono: true)
            }
            if let cc = fn.callingConvention {
                InfoRow("Convention", cc)
            }
            if let rt = fn.returnType {
                InfoRow("Returns", rt)
            }
            if !fn.parameters.isEmpty {
                InfoRow("Params", fn.parameters.joined(separator: ", "))
            }
            if !fn.callers.isEmpty {
                InfoRow("Callers", "\(fn.callers.count)")
            }
            if !fn.callees.isEmpty {
                InfoRow("Callees", "\(fn.callees.count)")
            }
            InfoRow("Pseudocode", fn.hasPseudocode ? "Available" : "Not generated")

            HStack {
                Button("Rename…") { renameFunction(fn) }
                Button(fn.isPinned ? "Unpin" : "Pin") {
                    Task { await state.togglePin(at: fn.address) }
                }
                Spacer()
            }
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 4) {
                Text("Callers").font(.callout.weight(.medium))
                ForEach(fn.callers.prefix(20), id: \.hexString) { addr in
                    Button(addr.hexString) { state.navigate(to: addr) }
                        .buttonStyle(.link)
                        .font(.system(.caption, design: .monospaced))
                }
                if fn.callers.count > 20 {
                    Text("…and \(fn.callers.count - 20) more").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var addressInspector: some View {
        InspectorPanel("Address", subtitle: state.selectedAddress?.hexString) {
            if let addr = state.selectedAddress {
                InfoRow("Address", addr.hexString, mono: true)
                InfoRow("Kind", addr.kind.rawValue)
                if let fn = state.function(containing: addr) {
                    InfoRow("Function", fn.displayName)
                    Button("Select function") { state.selectFunction(fn) }
                        .controlSize(.small)
                }
                if let label = state.userLabels[addr.hexString] {
                    InfoRow("Label", label)
                }
                if let comment = state.comments[addr.hexString] {
                    InfoRow("Comment", comment)
                }
                HStack {
                    Button("Pin") { Task { await state.togglePin(at: addr) } }
                        .controlSize(.small)
                    Button("Add Label…") { addLabel(at: addr) }
                        .controlSize(.small)
                    Button("Add Comment…") { addComment(at: addr) }
                        .controlSize(.small)
                }
            } else {
                Text("No address selected.").foregroundStyle(.secondary)
            }
        }
    }

    private var instructionInspector: some View {
        InspectorPanel("Instruction") {
            if let range = state.selectedInstructionRange,
               let ins = state.disassembly.first(where: { range.contains($0.address.value) }) {
                InfoRow("Address", ins.address.hexString, mono: true)
                InfoRow("Bytes", ins.rawBytes.map { String(format: "%02x", $0) }.joined(separator: " "), mono: true)
                InfoRow("Mnemonic", ins.mnemonic)
                InfoRow("Operands", ins.operandText)
                InfoRow("Class", ins.classification.rawValue)
                if let target = ins.branchTarget {
                    InfoRow("Target", target.hexString, mono: true)
                    Button("Go to target") { state.navigate(to: target) }
                        .controlSize(.small)
                }
                if let comment = ins.comment {
                    InfoRow("Comment", comment)
                }
            } else {
                Text("Select an instruction in the disassembly view.").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Alert-driven edits (kept simple; no custom windows)

    private func renameFunction(_ fn: DecompilerFunction) {
        let alert = NSAlert()
        alert.messageText = "Rename Function"
        alert.informativeText = "Enter a new name for \(fn.displayName). The original name is preserved."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = fn.name
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let newName = field.stringValue.trimmingCharacters(in: .whitespaces)
            if !newName.isEmpty {
                Task { await state.renameSelectedFunction(to: newName) }
            }
        }
    }

    private func addLabel(at addr: DecompilerAddress) {
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

    private func addComment(at addr: DecompilerAddress) {
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

/// Tiny pasteboard helper shared by the browsers.
func NSPasteboardCopy(_ string: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
}
