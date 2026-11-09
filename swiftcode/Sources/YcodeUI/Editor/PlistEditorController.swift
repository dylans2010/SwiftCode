import AppKit
import SwiftUI
import YcodeIDECore
import YcodePlist

@MainActor
public final class PlistEditorModel: ObservableObject {
    @Published public private(set) var tree: PlistTree
    @Published public var selectedPath: [Int]?
    @Published public var contextPath: [Int]?
    @Published public var showsRawKeys = false
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var revealToken = 0
    public let url: URL
    public private(set) var document: PropertyListDocument

    public init(url: URL) throws {
        self.url = url
        document = try PropertyListDocument(data: try Data(contentsOf: url))
        tree = PlistTree(root: document.root)
    }

    func commit() {
        document.root = tree.root
        do {
            try document.data().write(to: url, options: .atomic)
            statusMessage = nil
        } catch {
            statusMessage = "Couldn't save \(url.lastPathComponent): \(error.localizedDescription)"
        }
        if let sel = selectedPath, tree.item(at: sel) == nil { selectedPath = nil }
    }

    func setKey(_ key: String, at path: [Int]) { tree.setKey(key, at: path); commit() }
    func setType(_ type: String, at path: [Int]) { tree.setType(type, at: path); commit() }

    @discardableResult
    func setValueText(_ text: String, at path: [Int]) -> Bool {
        guard let type = tree.item(at: path)?.typeName, let v = PlistTree.parse(text, as: type) else {
            statusMessage = "Invalid \(tree.item(at: path)?.typeName ?? "value") value"
            return false
        }
        tree.setValue(v, at: path)
        commit()
        return true
    }

    @discardableResult
    func insert(after path: [Int], asChild: Bool = false) -> [Int] {
        let p = tree.insert(after: path, asChild: asChild)
        commit()
        return p
    }

    func remove(at path: [Int]) { tree.remove(at: path); commit() }

    func selectItem(at path: [Int]) {
        selectedPath = path
        contextPath = path.first.map { [$0] }
        revealToken += 1
    }

    func showSection(_ path: [Int]?) {
        contextPath = path
        selectedPath = nil
        revealToken += 1
    }

    @discardableResult
    func addItem() -> [Int] {
        let base = selectedPath ?? contextPath
        let p: [Int]
        if let base, let v = tree.item(at: base), PlistTree.isContainer(v) {
            p = insert(after: base, asChild: true)
        } else {
            p = insert(after: base ?? [], asChild: base == nil)
        }
        selectItem(at: p)
        return p
    }

    @discardableResult
    func setTypeOfSelection(_ type: String) -> Bool {
        guard let p = selectedPath else { return false }
        setType(type, at: p)
        selectItem(at: p)
        return true
    }

    var selectedTypeName: String? { selectedPath.flatMap { tree.item(at: $0)?.typeName } }

    func displayedKey(_ key: String) -> String { showsRawKeys ? key : ProjectEditorModel.readableKey(key) }

    func rawKey(forDisplayed text: String, current: String) -> String {
        if text == displayedKey(current) { return current }
        return ProjectEditorModel.readableInfoKeys.first { $0.value == text }?.key ?? text
    }
}

@MainActor
public final class PlistEditorController: NSViewController {
    public let url: URL
    public let model: PlistEditorModel

    public var document: PropertyListDocument { model.document }
    public var tree: PlistTree { model.tree }

    public init(url: URL) throws {
        self.url = url
        model = try PlistEditorModel(url: url)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func loadView() {
        let host = NSHostingView(rootView: PlistEditorView(model: model))
        host.frame = NSRect(x: 0, y: 0, width: 780, height: 500)
        host.autoresizingMask = [.width, .height]
        view = host
    }

    func commit() { model.commit() }

    public func setKey(_ key: String, at path: [Int]) { model.setKey(key, at: path) }
    public func setType(_ type: String, at path: [Int]) { model.setType(type, at: path) }

    @discardableResult
    public func setValueText(_ text: String, at path: [Int]) -> Bool { model.setValueText(text, at: path) }

    @discardableResult
    public func insert(after path: [Int], asChild: Bool = false) -> [Int] { model.insert(after: path, asChild: asChild) }

    public func remove(at path: [Int]) { model.remove(at: path) }

    public var selectedItemPath: [Int]? { model.selectedPath }

    public func selectItem(at path: [Int]) {
        _ = view
        model.selectItem(at: path)
    }

    @discardableResult
    public func addItem() -> [Int] { model.addItem() }

    @discardableResult
    public func setTypeOfSelection(_ type: String) -> Bool { model.setTypeOfSelection(type) }

    public var selectedTypeName: String? { model.selectedTypeName }

    public var showsRawKeys: Bool {
        get { model.showsRawKeys }
        set { model.showsRawKeys = newValue }
    }

    public func displayedKey(_ key: String) -> String { model.displayedKey(key) }
}

private struct PlistOutlineNode: Identifiable {
    let path: [Int]
    let key: String
    let parentIsDictionary: Bool
    let item: PropertyListItem
    let children: [PlistOutlineNode]?

    var id: String { PlistEditorView.pathKey(path) }
}

private struct PlistEditorView: View {
    @ObservedObject var model: PlistEditorModel

    static func pathKey(_ path: [Int]) -> String { path.map(String.init).joined(separator: ".") }

    static func parsePathKey(_ key: String) -> [Int]? {
        if key.isEmpty { return [] }
        return key.split(separator: ".").compactMap { Int($0) }
    }

    private static func isDictionary(_ item: PropertyListItem) -> Bool {
        if case .dictionary = item { return true }
        return false
    }

    static func symbol(for type: String) -> String {
        switch type {
        case "Dictionary": "curlybraces"
        case "Array": "list.bullet"
        case "String": "textformat"
        case "Number": "number"
        case "Boolean": "checkmark.square"
        case "Date": "calendar"
        case "Data": "externaldrive"
        default: "questionmark.square"
        }
    }

    private func makeNode(path: [Int], rawKey: String, parentIsDictionary: Bool) -> PlistOutlineNode {
        guard let item = model.tree.item(at: path) else {
            return PlistOutlineNode(path: path, key: rawKey, parentIsDictionary: parentIsDictionary, item: .string(""), children: nil)
        }
        let isDict = Self.isDictionary(item)
        let children = PlistTree.children(of: item).enumerated().map { i, pair in
            makeNode(path: path + [i], rawKey: pair.key, parentIsDictionary: isDict)
        }
        let kids = children.isEmpty ? nil : children
        return PlistOutlineNode(path: path, key: rawKey, parentIsDictionary: parentIsDictionary, item: item, children: kids)
    }

    private func label(for path: [Int]) -> (key: String, parentIsDictionary: Bool) {
        guard let last = path.last, let parent = model.tree.item(at: Array(path.dropLast())) else { return ("Root", false) }
        let kids = PlistTree.children(of: parent)
        guard kids.indices.contains(last) else { return ("Item \(last)", false) }
        return (kids[last].key, Self.isDictionary(parent))
    }

    private var detailNodes: [PlistOutlineNode] {
        if let ctx = model.contextPath {
            let l = label(for: ctx)
            return [makeNode(path: ctx, rawKey: l.key, parentIsDictionary: l.parentIsDictionary)]
        }
        if PlistTree.isContainer(model.tree.root) {
            let isDict = Self.isDictionary(model.tree.root)
            return PlistTree.children(of: model.tree.root).enumerated().map { i, pair in
                makeNode(path: [i], rawKey: pair.key, parentIsDictionary: isDict)
            }
        }
        return [makeNode(path: [], rawKey: "Root", parentIsDictionary: false)]
    }

    private var topLevelRows: [(index: Int, key: String, item: PropertyListItem)] {
        guard PlistTree.isContainer(model.tree.root) else { return [] }
        return PlistTree.children(of: model.tree.root).enumerated().map { i, pair in
            (i, pair.key, pair.value)
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { model.selectedPath.map(Self.pathKey) },
            set: { newValue in
                model.selectedPath = newValue.flatMap(Self.parsePathKey)
            }
        )
    }

    private var sidebarSelection: Binding<String> {
        Binding(
            get: {
                guard let ctx = model.contextPath, let first = ctx.first else { return "overview" }
                return "section.\(first)"
            },
            set: { newValue in
                if newValue == "overview" {
                    model.showSection(nil)
                } else if newValue.hasPrefix("section."), let i = Int(newValue.dropFirst("section.".count)) {
                    model.showSection([i])
                }
            }
        )
    }

    private var rawKeysBinding: Binding<Bool> {
        Binding(get: { model.showsRawKeys }, set: { model.showsRawKeys = $0 })
    }

    private var formatName: String {
        switch model.document.format {
        case .xml: "XML Property List"
        case .binary: "Binary Property List"
        case .openStep: "OpenStep Property List"
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: sidebarSelection) {
                Section {
                    Label("Overview", systemImage: "doc.text.magnifyingglass")
                        .tag("overview")
                }
                if !topLevelRows.isEmpty {
                    Section("Top-Level Keys") {
                        ForEach(topLevelRows.indices, id: \.self) { i in
                            let row = topLevelRows[i]
                            HStack(spacing: 8) {
                                Image(systemName: Self.symbol(for: row.item.typeName))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.displayedKey(row.key))
                                        .lineLimit(1)
                                    Text("\(row.item.typeName)\(PlistTree.isContainer(row.item) ? " · \(PlistTree.children(of: row.item).count)" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag("section.\(row.index)")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(model.url.deletingPathExtension().lastPathComponent)
        } detail: {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    List(selection: selectionBinding) {
                        OutlineGroup(detailNodes, children: \.children) { node in
                            PlistRowView(node: node, model: model)
                                .tag(node.id)
                        }
                    }
                    .listStyle(.inset)
                    .onChange(of: model.revealToken) { _, _ in
                        guard let path = model.selectedPath ?? model.contextPath else { return }
                        proxy.scrollTo(Self.pathKey(path), anchor: .center)
                    }
                }
                Divider()
                HStack {
                    if let status = model.statusMessage {
                        Text(status).foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(formatName).foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button { _ = model.addItem() } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    Button {
                        if let path = model.selectedPath { model.remove(at: path) }
                    } label: {
                        Label("Remove Item", systemImage: "minus")
                    }
                    .disabled(model.selectedPath == nil)
                    Toggle("Raw Keys", isOn: rawKeysBinding)
                        .toggleStyle(.button)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 440)
    }
}

private struct PlistRowView: View {
    let node: PlistOutlineNode
    @ObservedObject var model: PlistEditorModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: PlistEditorView.symbol(for: node.item.typeName))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            keyEditor
                .frame(minWidth: 110, idealWidth: 190, maxWidth: 300)
            typePicker
            valueEditor
            Spacer(minLength: 4)
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private var keyEditor: some View {
        if node.parentIsDictionary {
            PlistKeyField(node: node, model: model)
        } else {
            Text(node.key)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var typePicker: some View {
        Picker("", selection: Binding(
            get: { node.item.typeName },
            set: { model.setType($0, at: node.path) }
        )) {
            ForEach(PlistTree.types, id: \.self) { Text($0).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    @ViewBuilder
    private var valueEditor: some View {
        if PlistTree.isContainer(node.item) {
            Text(node.item.summary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            PlistValueField(node: node, model: model)
        }
    }
}

private struct PlistKeyField: View {
    let node: PlistOutlineNode
    @ObservedObject var model: PlistEditorModel
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $draft)
            .onAppear { draft = model.displayedKey(node.key) }
            .onChange(of: node.key) { _, key in
                if !focused { draft = model.displayedKey(key) }
            }
            .onChange(of: model.showsRawKeys) { _, _ in
                if !focused { draft = model.displayedKey(node.key) }
            }
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
    }

    private func commit() {
        let raw = model.rawKey(forDisplayed: draft, current: node.key)
        if raw != node.key { model.setKey(raw, at: node.path) }
        draft = model.displayedKey(raw)
    }
}

private struct PlistValueField: View {
    let node: PlistOutlineNode
    @ObservedObject var model: PlistEditorModel
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $draft)
            .font(.callout.monospacedDigit())
            .onAppear { draft = PlistTree.editText(node.item) }
            .onChange(of: PlistTree.editText(node.item)) { _, text in
                if !focused { draft = text }
            }
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
    }

    private func commit() {
        _ = model.setValueText(draft, at: node.path)
    }
}
