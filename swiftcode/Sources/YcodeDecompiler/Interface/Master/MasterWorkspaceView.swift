import SwiftUI

/// Left-sidebar categories in Master mode.
public enum MasterSidebarItem: String, CaseIterable, Identifiable, Sendable {
    case functions, symbols, imports, exports, strings, sections, references

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .functions: return "Functions"
        case .symbols: return "Symbols"
        case .imports: return "Imports"
        case .exports: return "Exports"
        case .strings: return "Strings"
        case .sections: return "Sections"
        case .references: return "References"
        }
    }
    public var systemImage: String {
        switch self {
        case .functions: return "function"
        case .symbols: return "tag"
        case .imports: return "arrow.down.circle"
        case .exports: return "arrow.up.circle"
        case .strings: return "textformat"
        case .sections: return "square.split.2x2"
        case .references: return "arrow.triangle.branch"
        }
    }
}

/// Center editor tabs in Master mode.
public enum MasterEditorTab: String, CaseIterable, Identifiable, Sendable {
    case disassembly, pseudocode, hex, controlFlow

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .disassembly: return "Disassembly"
        case .pseudocode: return "Pseudocode"
        case .hex: return "Hex"
        case .controlFlow: return "Control Flow"
        }
    }
    public var systemImage: String {
        switch self {
        case .disassembly: return "list.number"
        case .pseudocode: return "chevron.left.forwardslash.chevron.right"
        case .hex: return "number"
        case .controlFlow: return "point.3.connected.trianglepath.dotted"
        }
    }
}

/// Master mode workspace: dense multi-pane layout — navigator sidebar,
/// tabbed editors in the center, inspector on the right, console below.
public struct MasterWorkspaceView: View {
    @Bindable var state: DecompilerObservableState
    @State private var sidebarItem: MasterSidebarItem = .functions
    @State private var editorTab: MasterEditorTab = .disassembly
    @State private var searchText = ""

    public init(state: DecompilerObservableState) {
        self.state = state
    }

    public var body: some View {
        HSplitView {
            // Left: navigator
            VStack(spacing: 0) {
                Picker("Pane", selection: $sidebarItem) {
                    ForEach(MasterSidebarItem.allCases) { item in
                        Label(item.title, systemImage: item.systemImage).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(6)
                .labelsHidden()

                navigatorContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 240, idealWidth: 300, maxWidth: 420)

            // Center: tabbed editors
            VStack(spacing: 0) {
                Picker("Editor", selection: $editorTab) {
                    ForEach(MasterEditorTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(6)
                .labelsHidden()

                editorContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Decompile Assist slot: the AI module injects its chat UI
                // via `state.assistPanel`; same chrome as Friendly mode.
                if state.showAssist {
                    assistPanel
                }
            }
            .frame(minWidth: 420)

            // Right: inspector
            if state.showInspector {
                MasterInspectorView(state: state)
                    .frame(minWidth: 240, idealWidth: 300, maxWidth: 460)
            }
        }
        // Bottom: console, collapsible
        .safeAreaInset(edge: .bottom) {
            if state.showConsole {
                AnalysisConsole(state: state)
                    .frame(height: 180)
            }
            StatusBar(progress: state.progress, isAnalyzing: state.isAnalyzing,
                      extra: state.binary?.identity.originalFileName)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.showConsole.toggle()
                } label: {
                    Label("Console", systemImage: "text.alignleft")
                }
            }
        }
        .task { await state.reloadAll() }
        .onChange(of: state.pendingCommand) { _, cmd in
            if cmd == .search {
                sidebarItem = .functions
                state.pendingCommand = nil
            }
        }
    }

    @ViewBuilder
    private var navigatorContent: some View {
        switch sidebarItem {
        case .functions:
            MasterFunctionBrowser(state: state, searchText: $searchText)
        case .symbols:
            MasterSymbolBrowser(state: state, searchText: $searchText)
        case .imports:
            MasterImportBrowser(state: state)
        case .exports:
            MasterExportBrowser(state: state)
        case .strings:
            MasterStringsBrowser(state: state, searchText: $searchText)
        case .sections:
            SectionsBrowser(state: state)
        case .references:
            ReferenceBrowser(state: state)
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        switch editorTab {
        case .disassembly:
            DisassemblyEditor(state: state)
        case .pseudocode:
            PseudocodeEditor(state: state)
        case .hex:
            HexEditor(state: state)
        case .controlFlow:
            ControlFlowGraphView(state: state)
        }
    }

    /// Bottom Decompile Assist panel chrome — mirrors the Friendly-mode panel:
    /// header with session status, close button, then the injected chat view.
    private var assistPanel: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                Text("Decompile Assist")
                    .font(.headline)
                Spacer()
                if state.isAnalyzing {
                    Text(state.progress.message.isEmpty ? "Analyzing…" : state.progress.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if state.binary == nil {
                    Text("Import a binary to begin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    state.showAssist = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Hide Decompile Assist")
                .accessibilityLabel("Hide Decompile Assist")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            if let panel = state.assistPanel {
                panel
                    .frame(minHeight: 160, maxHeight: 320)
            } else {
                Text("Ask questions about the selected function, request summaries, or explore findings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .background(.regularMaterial)
    }
}
