import SwiftUI


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


public enum MasterEditorTab: String, CaseIterable, Identifiable, Sendable {
    case disassembly, pseudocode, hex, controlFlow, callGraph, types, security, patternSearch

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .disassembly: return "Disassembly"
        case .pseudocode: return "Pseudocode"
        case .hex: return "Hex"
        case .controlFlow: return "CFG"
        case .callGraph: return "Call Graph"
        case .types: return "Types & Headers"
        case .security: return "Security"
        case .patternSearch: return "Signatures"
        }
    }
    public var systemImage: String {
        switch self {
        case .disassembly: return "list.number"
        case .pseudocode: return "chevron.left.forwardslash.chevron.right"
        case .hex: return "number"
        case .controlFlow: return "point.3.connected.trianglepath.dotted"
        case .callGraph: return "arrow.triangle.branch"
        case .types: return "curlybraces"
        case .security: return "lock.shield"
        case .patternSearch: return "magnifyingglass.circle"
        }
    }
}



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

                
                
                if state.showAssist {
                    assistPanel
                }
            }
            .frame(minWidth: 420)

            
            if state.showInspector {
                MasterInspectorView(state: state)
                    .frame(minWidth: 240, idealWidth: 300, maxWidth: 460)
            }
        }
        
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
        case .callGraph:
            CallGraphExplorerView(state: state)
        case .types:
            MetadataTypeBrowserView(state: state)
        case .security:
            BinarySecurityScannerView(state: state)
        case .patternSearch:
            BytePatternScannerView(state: state)
        }
    }

    
    
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
