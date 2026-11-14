import SwiftUI
import AppKit







public struct DisassemblyEditor: View {
    @Bindable var state: DecompilerObservableState
    @State private var jumpAddress = ""
    @State private var selectedAddress: UInt64?

    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onChange(of: state.selectedFunctionAddress) { _, _ in
            Task { try? await state.loadDisassembly() }
        }
        .onAppear {
            if state.disassembly.isEmpty, state.selectedFunctionAddress != nil {
                Task { try? await state.loadDisassembly() }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let fn = state.selectedFunction {
                Text(fn.displayName)
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                Text("\(state.disassembly.count) instructions")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No function selected")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            AddressField(placeholder: "Go to address") { addr in
                jumpTo(addr)
            }
            if let target = selectedInstruction?.branchTarget {
                Button("Follow → \(target.hexString)") {
                    state.navigate(to: target)
                    if let fn = state.function(containing: target) {
                        state.selectFunction(fn)
                    }
                }
                .controlSize(.small)
            }
            Button("Reload") {
                Task { try? await state.loadDisassembly() }
            }
            .controlSize(.small)
            .disabled(state.selectedFunctionAddress == nil || state.isAnalyzing)
            CopyButton(state.disassembly.map(\.text).joined(separator: "\n"), label: "Copy Listing")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        if state.selectedFunctionAddress == nil {
            EmptyStateView(
                systemImage: "function",
                title: "No function selected",
                message: "Select a function in the Functions pane to disassemble it."
            )
        } else if state.disassembly.isEmpty {
            VStack(spacing: 10) {
                if state.isAnalyzing {
                    ProgressView()
                    Text("Waiting for analysis…").foregroundStyle(.secondary)
                } else {
                    Text("No disassembly loaded.")
                        .foregroundStyle(.secondary)
                    Button("Disassemble Function") {
                        Task { try? await state.loadDisassembly() }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            instructionTable
        }
    }

    private var instructionTable: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0) {
                
                HStack(spacing: 0) {
                    Text("Address").frame(width: 110, alignment: .trailing).padding(.trailing, 12)
                    Text("Bytes").frame(width: 120, alignment: .leading).padding(.trailing, 12)
                    Text("Instruction").frame(maxWidth: .infinity, alignment: .leading)
                    Text("X").frame(width: 34, alignment: .trailing)
                }
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.vertical, 4)

                ForEach(state.disassembly) { ins in
                    row(for: ins)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private func row(for ins: Instruction) -> some View {
        let isSelected = selectedAddress == ins.address.value
        return HStack(spacing: 0) {
            Text(ins.address.hexString)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 110, alignment: .trailing)
                .padding(.trailing, 12)
            Text(ins.rawBytes.map { String(format: "%02x", $0) }.joined(separator: " "))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 120, alignment: .leading)
                .padding(.trailing, 12)
            HStack(spacing: 6) {
                Text(ins.mnemonic)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(mnemonicColor(ins.classification))
                Text(ins.operandText)
                    .font(.system(.callout, design: .monospaced))
                if let label = ins.label {
                    Text(label).font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                }
                if let comment = ins.comment {
                    Text("; \(comment)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(ins.referenceCount > 0 ? "\(ins.referenceCount)" : "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedAddress = ins.address.value
            state.selectedInstructionRange = ins.address.value...ins.address.value + UInt64(max(ins.size, 1)) - 1
            state.inspectorItem = .instruction
            state.selectAddress(ins.address, inspector: .instruction)
        }
        .contextMenu {
            Button("Copy Address") { NSPasteboardCopy(ins.address.hexString) }
            Button("Copy Instruction") { NSPasteboardCopy(ins.text) }
            Button("Copy Bytes") {
                NSPasteboardCopy(ins.rawBytes.map { String(format: "%02x", $0) }.joined(separator: " "))
            }
            if let target = ins.branchTarget {
                Divider()
                Button("Go to \(target.hexString)") { state.navigate(to: target) }
            }
            Divider()
            Button("Add Comment…") { commentPrompt(ins.address) }
            Button("Add Label…") { labelPrompt(ins.address) }
        }
    }

    private var selectedInstruction: Instruction? {
        guard let addr = selectedAddress else { return nil }
        return state.disassembly.first { $0.address.value == addr }
    }

    private func jumpTo(_ addr: DecompilerAddress) {
        if let ins = state.disassembly.first(where: { $0.address.value == addr.value }) {
            selectedAddress = ins.address.value
        }
    }

    private func mnemonicColor(_ c: Instruction.Classification) -> Color {
        switch c {
        case .call: return .purple
        case .branch, .returnInstruction: return .blue
        case .invalid, .data: return .red
        default: return .primary
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
}






public struct PseudocodeEditor: View {
    @Bindable var state: DecompilerObservableState
    @State private var errorMessage: String?

    public init(state: DecompilerObservableState) { self.state = state }

    private var result: DecompilationResult? {
        guard let fn = state.selectedFunction else { return nil }
        return state.pseudocode(for: fn)
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
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

    private var header: some View {
        HStack(spacing: 10) {
            if let fn = state.selectedFunction {
                Text(fn.displayName)
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                if let r = result {
                    Text("\(r.engineID)\(r.engineVersion.map { " \($0)" } ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("No function selected").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Decompile") {
                Task {
                    do { _ = try await state.decompileSelected() }
                    catch { errorMessage = error.localizedDescription }
                }
            }
            .disabled(state.selectedFunctionAddress == nil || state.isAnalyzing)
            if let r = result {
                CopyButton(r.pseudocode, label: "Copy")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        if state.selectedFunction == nil {
            EmptyStateView(systemImage: "chevron.left.forwardslash.chevron.right",
                           title: "No function selected",
                           message: "Select a function to view or generate its pseudocode.")
        } else if let result {
            codeView(result)
        } else {
            VStack(spacing: 10) {
                Text("No pseudocode for this function yet.")
                    .foregroundStyle(.secondary)
                Button("Decompile Function") {
                    Task {
                        do { _ = try await state.decompileSelected() }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func codeView(_ result: DecompilationResult) -> some View {
        let lines = result.pseudocode.components(separatedBy: .newlines)
        
        var lineToAddrs: [Int: [UInt64]] = [:]
        for (addr, line) in result.addressLineMap {
            lineToAddrs[line, default: []].append(addr)
        }
        return HStack(spacing: 0) {
            
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(lines.indices, id: \.self) { i in
                    let lineNo = i + 1
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(lineNo)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        ForEach(lineToAddrs[lineNo] ?? [], id: \.self) { addr in
                            Button {
                                state.navigate(to: DecompilerAddress(virtual: addr))
                            } label: {
                                Text(String(addr, radix: 16))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 18, alignment: .top)
                }
            }
            .padding(.trailing, 8)
            .padding(.top, 6)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(Highlighting.highlight(lines[i]))
                            .font(.system(.callout, design: .monospaced))
                            .frame(height: 18, alignment: .top)
                            .textSelection(.enabled)
                            .padding(.horizontal, 10)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}




enum Highlighting {
    static let keywords: Set<String> = [
        "auto", "break", "case", "char", "const", "continue", "default", "do",
        "double", "else", "enum", "extern", "float", "for", "goto", "if",
        "inline", "int", "long", "register", "restrict", "return", "short",
        "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
        "unsigned", "void", "volatile", "while", "bool", "true", "false",
        "nullptr", "class", "public", "private", "protected", "virtual",
        "template", "namespace", "using", "new", "delete", "this", "operator",
        "try", "catch", "throw", "async", "await", "in", "out", "inout",
        "let", "var", "func", "switch", "case", "default", "where", "for",
        "while", "return", "if", "else", "guard", "defer", "do", "catch",
        "repeat", "break", "continue", "fallthrough", "import", "typealias",
        "protocol", "extension", "struct", "enum", "class", "actor", "some",
        "any", "self", "Self", "nil", "super", "is", "as", "try", "throws",
    ]

    static let typeNames: Set<String> = [
        "int", "char", "short", "long", "float", "double", "void", "bool",
        "size_t", "ssize_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t",
        "int8_t", "int16_t", "int32_t", "int64_t", "uintptr_t", "intptr_t",
        "BOOL", "NSInteger", "NSUInteger", "CGFloat", "CGFloat", "id", "SEL",
        "Class", "IMP", "dispatch_queue_t",
    ]

    static func highlight(_ line: String) -> AttributedString {
        var result = AttributedString()
        var i = line.startIndex
        var inLineComment = false
        var inBlockComment = false

        func isIdentStart(_ c: Character) -> Bool {
            c.isLetter || c == "_" || c == "$"
        }
        func isIdent(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_" || c == "$"
        }

        while i < line.endIndex {
            let c = line[i]

            
            if !inBlockComment && !inLineComment,
               c == "/", line.index(after: i) < line.endIndex,
               line[line.index(after: i)] == "/" {
                inLineComment = true
            }
            if inLineComment {
                var seg = AttributedString(String(line[i...]))
                seg.foregroundColor = .secondary
                result += seg
                break
            }
            if inBlockComment {
                if c == "*", line.index(after: i) < line.endIndex,
                   line[line.index(after: i)] == "/" {
                    var seg = AttributedString("*/")
                    seg.foregroundColor = .secondary
                    result += seg
                    i = line.index(i, offsetBy: 2)
                    inBlockComment = false
                    continue
                }
                var seg = AttributedString(String(c))
                seg.foregroundColor = .secondary
                result += seg
                i = line.index(after: i)
                continue
            }
            if c == "/", line.index(after: i) < line.endIndex,
               line[line.index(after: i)] == "*" {
                inBlockComment = true
                var seg = AttributedString("/*")
                seg.foregroundColor = .secondary
                result += seg
                i = line.index(i, offsetBy: 2)
                continue
            }

            
            if c == "\"" || c == "'" {
                let quote = c
                var j = line.index(after: i)
                var text = String(c)
                var closed = false
                while j < line.endIndex {
                    let cj = line[j]
                    text.append(cj)
                    if cj == "\\", line.index(after: j) < line.endIndex {
                        text.append(line[line.index(after: j)])
                        j = line.index(j, offsetBy: 2)
                        continue
                    }
                    j = line.index(after: j)
                    if cj == quote { closed = true; break }
                }
                _ = closed
                var seg = AttributedString(text)
                seg.foregroundColor = .orange
                result += seg
                i = j
                continue
            }

            
            if c.isNumber || (c == "-" || c == "+" || c == "&"),
               let next = line[line.index(after: i)...].first,
               next.isNumber || (next == "x" && c != "-" && c != "+") {
                var j = line.index(after: i)
                var text = String(c)
                while j < line.endIndex {
                    let cj = line[j]
                    if cj.isNumber || cj.isLetter || cj == "x" || cj == "X" || cj == "." || cj == "_" {
                        text.append(cj)
                        j = line.index(after: j)
                    } else { break }
                }
                var seg = AttributedString(text)
                seg.foregroundColor = .purple
                result += seg
                i = j
                continue
            }

            
            if isIdentStart(c) {
                var j = i
                var text = ""
                while j < line.endIndex, isIdent(line[j]) {
                    text.append(line[j])
                    j = line.index(after: j)
                }
                var seg = AttributedString(text)
                if keywords.contains(text) {
                    seg.foregroundColor = .pink
                } else if typeNames.contains(text)
                            || (text.first?.isUppercase == true && text.count > 1) {
                    seg.foregroundColor = .teal
                }
                result += seg
                i = j
                continue
            }

            
            var seg = AttributedString(String(c))
            if c == "(" || c == ")" || c == "{" || c == "}" || c == "[" || c == "]" {
                seg.foregroundColor = .secondary
            }
            result += seg
            i = line.index(after: i)
        }
        return result
    }
}






public struct HexEditor: View {
    @Bindable var state: DecompilerObservableState
    @State private var bytes: Data = Data()
    @State private var baseOffset: UInt64 = 0
    @State private var goToText = ""
    @State private var errorMessage: String?
    @State private var selectedRange: ClosedRange<UInt64>?

    private let windowSize = 0x8000 

    public init(state: DecompilerObservableState) { self.state = state }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .task { await reload() }
        .alert("Hex read failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Offset").font(.caption).foregroundStyle(.secondary)
            TextField("0x…", text: $goToText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
                .frame(width: 140)
                .onSubmit(goTo)
            Button("Go") { goTo() }.controlSize(.small)
            Text("base 0x\(String(baseOffset, radix: 16))")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
            Spacer()
            Text("\(bytes.count) bytes loaded")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        if state.binary == nil {
            EmptyStateView(systemImage: "number", title: "No binary loaded",
                           message: "Import a binary to inspect its raw bytes.")
        } else if bytes.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading bytes…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            hexDump
        }
    }

    private var hexDump: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(0..<rowCount, id: \.self) { row in
                    rowView(row)
                }
            }
            .padding(10)
        }
    }

    private var rowCount: Int {
        (bytes.count + 15) / 16
    }

    private func byteAt(_ index: Int) -> UInt8? {
        guard index < bytes.count else { return nil }
        return bytes[bytes.startIndex + index]
    }

    private func rowView(_ row: Int) -> some View {
        let start = row * 16
        let end = min(start + 16, bytes.count)
        let offset = baseOffset + UInt64(start)
        let inSelection = selectedRange.map {
            offset < $0.upperBound && offset + UInt64(end - start) > $0.lowerBound
        } ?? false

        return HStack(spacing: 12) {
            Text("0x" + String(offset, radix: 16).leftPad(toLength: 8, withPad: "0"))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            
            HStack(spacing: 3) {
                ForEach(0..<16, id: \.self) { col in
                    let idx = start + col
                    Text(idx < end ? String(format: "%02x", byteAt(idx) ?? 0) : "  ")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 26, alignment: .center)
                        .background(byteSelected(idx) ? Color.accentColor.opacity(0.3) : Color.clear)
                }
            }
            
            Text(asciiString(start: start, end: end))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(inSelection ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRange = offset...(offset + 15)
        }
        .contextMenu {
            Button("Copy Bytes") {
                let slice = bytes[(bytes.startIndex + start)..<(bytes.startIndex + end)]
                NSPasteboardCopy(slice.map { String(format: "%02x", $0) }.joined(separator: " "))
            }
            Button("Copy Offset") { NSPasteboardCopy("0x" + String(offset, radix: 16)) }
        }
    }

    
    private static let asciiTable: [Character] = {
        var t = [Character](repeating: ".", count: 128)
        t[32] = " "
        for b in 33...126 {
            if let scalar = Unicode.Scalar(UInt32(b)) {
                t[b] = Character(scalar)
            }
        }
        return t
    }()

    private func asciiString(start: Int, end: Int) -> String {
        var out = ""
        for i in start..<end {
            guard let b = byteAt(i), b < 0x80 else { out.append("."); continue }
            out.append(Self.asciiTable[Int(b)])
        }
        return out
    }

    private func byteSelected(_ idx: Int) -> Bool {
        guard let range = selectedRange else { return false }
        let fileOff = baseOffset + UInt64(idx)
        return range.contains(fileOff)
    }

    private func goTo() {
        guard let addr = DecompilerAddress.parse(goToText, defaultKind: .fileOffset) else { return }
        baseOffset = addr.value
        Task { await reload() }
    }

    private func reload() async {
        do {
            bytes = try await state.readBytes(fileOffset: baseOffset, length: windowSize)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}







public struct ControlFlowGraphView: View {
    @Bindable var state: DecompilerObservableState
    @State private var scale: CGFloat = 1.0
    @State private var errorMessage: String?

    private let maxBlocks = 500

    public init(state: DecompilerObservableState) { self.state = state }

    
    private struct RenderBlock: Identifiable {
        let id: String
        let start: UInt64
        let end: UInt64
        let depth: Int
        let isEntry: Bool
        let isExit: Bool
    }

    private struct RenderEdge: Identifiable {
        let id = UUID()
        let from: UInt64
        let to: UInt64
    }

    
    private func buildGraph() -> (blocks: [RenderBlock], edges: [RenderEdge], truncated: Bool, totalBlocks: Int) {
        let ins = state.disassembly
        guard !ins.isEmpty else { return ([], [], false, 0) }

        var addresses = Set<UInt64>()
        for i in ins { addresses.insert(i.address.value) }

        
        
        var leaders = Set<UInt64>()
        leaders.insert(ins[0].address.value)
        for (idx, i) in ins.enumerated() {
            if let t = i.branchTarget?.value, addresses.contains(t) {
                leaders.insert(t)
            }
            switch i.classification {
            case .branch, .call, .returnInstruction:
                if idx + 1 < ins.count { leaders.insert(ins[idx + 1].address.value) }
            default: break
            }
        }
        let sortedLeaders = leaders.sorted()

        
        var blockStarts: [UInt64] = []
        var blockEnd: [UInt64: UInt64] = [:]
        var blockLastInsn: [UInt64: Instruction] = [:]
        for (idx, leader) in sortedLeaders.enumerated() {
            let next = idx + 1 < sortedLeaders.count ? sortedLeaders[idx + 1] : UInt64.max
            blockStarts.append(leader)
            var last: Instruction? = nil
            for i in ins where i.address.value >= leader && i.address.value < next {
                last = i
            }
            if let last {
                blockEnd[leader] = last.address.value
                blockLastInsn[leader] = last
            }
        }

        let truncated = blockStarts.count > maxBlocks
        let used = Array(blockStarts.prefix(maxBlocks))
        let usedSet = Set(used)

        
        var edges: [RenderEdge] = []
        var successors: [UInt64: [UInt64]] = [:]
        for (idx, start) in used.enumerated() {
            guard let last = blockLastInsn[start] else { continue }
            var succs: [UInt64] = []
            if let t = last.branchTarget?.value, usedSet.contains(t) {
                succs.append(t)
            }
            if last.classification != .returnInstruction,
               idx + 1 < used.count {
                succs.append(used[idx + 1])
            }
            for s in succs {
                edges.append(RenderEdge(from: start, to: s))
                successors[start, default: []].append(s)
            }
        }

        
        var depth: [UInt64: Int] = [:]
        let entry = used.first ?? 0
        var queue: [(UInt64, Int)] = [(entry, 0)]
        var visited = Set<UInt64>()
        while !queue.isEmpty {
            let (node, d) = queue.removeFirst()
            if visited.contains(node) { continue }
            visited.insert(node)
            depth[node] = max(depth[node] ?? 0, d)
            for s in successors[node] ?? [] where !visited.contains(s) {
                queue.append((s, d + 1))
            }
        }
        for s in used where depth[s] == nil { depth[s] = 0 }

        let blocks = used.map { start in
            RenderBlock(id: "bb-\(start)", start: start,
                        end: blockEnd[start] ?? start,
                        depth: depth[start] ?? 0,
                        isEntry: start == entry,
                        isExit: (successors[start] ?? []).isEmpty)
        }
        return (blocks, edges, truncated, blockStarts.count)
    }

    
    private let nodeW: CGFloat = 150
    private let nodeH: CGFloat = 44
    private let colGap: CGFloat = 60
    private let rowGap: CGFloat = 24

    private func layout(_ blocks: [RenderBlock]) -> [UInt64: CGPoint] {
        
        var byDepth: [Int: [RenderBlock]] = [:]
        for b in blocks { byDepth[b.depth, default: []].append(b) }
        var positions: [UInt64: CGPoint] = [:]
        let maxDepth = byDepth.keys.max() ?? 0
        for d in 0...maxDepth {
            let col = (byDepth[d] ?? []).sorted { $0.start < $1.start }
            let totalH = CGFloat(col.count) * (nodeH + rowGap) - rowGap
            let startY = -totalH / 2
            for (i, b) in col.enumerated() {
                positions[b.start] = CGPoint(
                    x: CGFloat(d) * (nodeW + colGap),
                    y: startY + CGFloat(i) * (nodeH + rowGap) + nodeH / 2)
            }
        }
        return positions
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let fn = state.selectedFunction {
                    Text("\(fn.displayName) — control flow")
                        .font(.callout.weight(.medium))
                } else {
                    Text("No function selected").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Text("Pinch or scroll to zoom · click a block to navigate")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.bar)
            Divider()
            content
        }
        .alert("Graph error", isPresented: Binding(
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
            EmptyStateView(systemImage: "point.3.connected.trianglepath.dotted",
                           title: "No function selected",
                           message: "Select a function and load its disassembly to view its control-flow graph.")
        } else if state.disassembly.isEmpty {
            VStack(spacing: 10) {
                Text("No disassembly loaded.").foregroundStyle(.secondary)
                Button("Disassemble Function") {
                    Task { try? await state.loadDisassembly() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            graphCanvas
        }
    }

    private var graphCanvas: some View {
        let (blocks, edges, truncated, totalBlocks) = buildGraph()
        let positions = layout(blocks)

        return GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    Canvas { context, _ in
                        
                        for edge in edges {
                            guard let fromPos = positions[edge.from],
                                  let toPos = positions[edge.to] else { continue }
                            var path = Path()
                            let start = CGPoint(x: fromPos.x + nodeW / 2, y: fromPos.y)
                            let end = CGPoint(x: toPos.x - nodeW / 2, y: toPos.y)
                            let midX = (start.x + end.x) / 2
                            path.move(to: start)
                            path.addCurve(to: end,
                                          control1: CGPoint(x: midX, y: start.y),
                                          control2: CGPoint(x: midX, y: end.y))
                            context.stroke(path, with: .color(.secondary.opacity(0.6)),
                                           style: StrokeStyle(lineWidth: 1.5))
                            
                            let angle = atan2(end.y - start.y, end.x - start.x)
                            let head: CGFloat = 7
                            var arrow = Path()
                            arrow.move(to: end)
                            arrow.addLine(to: CGPoint(x: end.x - head * cos(angle - .pi / 6),
                                                      y: end.y - head * sin(angle - .pi / 6)))
                            arrow.move(to: end)
                            arrow.addLine(to: CGPoint(x: end.x - head * cos(angle + .pi / 6),
                                                      y: end.y - head * sin(angle + .pi / 6)))
                            context.stroke(arrow, with: .color(.secondary.opacity(0.6)), lineWidth: 1.5)
                        }
                    }
                    .frame(width: max(geo.size.width, maxX(positions) + nodeW + 40),
                           height: max(geo.size.height, maxY(positions) + nodeH + 40))

                    
                    ForEach(blocks) { block in
                        if let pos = positions[block.start] {
                            nodeView(block)
                                .position(pos)
                        }
                    }
                }
                .scaleEffect(scale)
                .frame(width: max(geo.size.width, maxX(positions) + nodeW + 40) * scale,
                       height: max(geo.size.height, maxY(positions) + nodeH + 40) * scale)
            }
            .gesture(
                MagnifyGesture()
                    .onChanged { value in scale = max(0.3, min(3.0, value.magnification)) }
            )
            .overlay(alignment: .bottomLeading) {
                if truncated {
                    Text("Showing first \(maxBlocks) of \(totalBlocks) blocks — graph truncated")
                        .font(.caption)
                        .padding(6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(10)
                }
            }
        }
    }

    private func maxX(_ positions: [UInt64: CGPoint]) -> CGFloat {
        (positions.values.map(\.x).max() ?? 0) + nodeW / 2
    }
    private func maxY(_ positions: [UInt64: CGPoint]) -> CGFloat {
        (positions.values.map(\.y).max() ?? 0) + nodeH / 2
    }

    private func nodeView(_ block: RenderBlock) -> some View {
        Button {
            state.navigate(to: DecompilerAddress(virtual: block.start))
            if let fn = state.function(containing: DecompilerAddress(virtual: block.start)) {
                state.selectFunction(fn)
            }
            state.inspectorItem = .address
            state.selectAddress(DecompilerAddress(virtual: block.start))
        } label: {
            VStack(spacing: 1) {
                Text("0x" + String(block.start, radix: 16))
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                Text(block.isEntry ? "entry" : (block.isExit ? "exit" : "block"))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(width: nodeW - 8, height: nodeH - 8)
            .background(block.isEntry ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(block.isEntry ? Color.green : Color.accentColor.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
