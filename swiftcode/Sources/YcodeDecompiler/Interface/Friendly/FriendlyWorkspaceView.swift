import SwiftUI

/// Sidebar destinations in Friendly mode.
public enum FriendlySection: String, CaseIterable, Identifiable, Sendable {
    case overview, functions, code, strings, dependencies, symbols, binaryInfo, history

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview: return "Overview"
        case .functions: return "Functions"
        case .code: return "Decompiled Code"
        case .strings: return "Strings"
        case .dependencies: return "Dependencies"
        case .symbols: return "Symbols"
        case .binaryInfo: return "Binary Information"
        case .history: return "Analysis History"
        }
    }

    public var systemImage: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .functions: return "function"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .strings: return "textformat"
        case .dependencies: return "shippingbox"
        case .symbols: return "tag"
        case .binaryInfo: return "info.square"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

/// Friendly mode workspace: guided, section-based navigation over the same
/// session data Master mode exposes as raw panes.
public struct FriendlyWorkspaceView: View {
    @Bindable var state: DecompilerObservableState
    @State private var section: FriendlySection? = .overview
    @State private var searchText = ""

    public init(state: DecompilerObservableState) {
        self.state = state
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .inspector(isPresented: $state.showInspector) {
                    FriendlyInspectorView(state: state)
                        .inspectorColumnWidth(min: 240, ideal: 300, max: 420)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            state.decompileAsset()
                        } label: {
                            Label("Decompile Asset", systemImage: "arrow.down.doc")
                        }
                        .help("Decompile every function and generate the editable source project")
                        .disabled(state.binary == nil || state.isDecompilingAsset)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            state.assemble()
                        } label: {
                            Label("Assemble", systemImage: "hammer")
                        }
                        .help("Compile and link the reconstructed project into a new dynamic library")
                        .disabled(state.reconstructedProject == nil || state.isAssembling)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Picker("Backend", selection: backendSelection) {
                            Text("Automatic").tag(nil as String?)
                            ForEach(backendOptions, id: \.0.id) { backend, availability in
                                Text(availability.isAvailable ? backend.displayName : "\(backend.displayName) (unavailable)")
                                    .tag(Optional(backend.id))
                                    .disabled(!availability.isAvailable)
                            }
                        }
                        .pickerStyle(.menu)
                        .help(backendPickerHelp)
                        .disabled(state.reconstructedProject == nil)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            state.openInMainEditor()
                        } label: {
                            Label("Open in Editor", systemImage: "arrow.up.forward.app")
                        }
                        .help("Open the reconstructed project in SwiftCode's main editor")
                        .disabled(state.reconstructedProject == nil)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            state.showInspector.toggle()
                        } label: {
                            Label("Inspector", systemImage: "sidebar.right")
                        }
                        .help("Toggle the inspector")
                    }
                }
        }
        .task { await state.reloadAll() }
        .onChange(of: state.pendingCommand) { _, cmd in
            if cmd == .search {
                section = .functions
                state.pendingCommand = nil
            }
        }
    }

    private var sidebar: some View {
        List(FriendlySection.allCases, selection: $section) { item in
            Label(item.title, systemImage: item.systemImage)
                .tag(item)
        }
        .navigationTitle(state.binary?.identity.originalFileName ?? "Decompiler")
        .safeAreaInset(edge: .bottom) {
            StatusBar(progress: state.progress, isAnalyzing: state.isAnalyzing)
        }
    }

    @ViewBuilder
    private var detail: some View {
        VStack(spacing: 0) {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.lastAssembly != nil {
                Divider()
                AssemblyResultView(state: state)
                    .frame(maxHeight: 320)
            }

            // Decompile Assist slot: the AI module injects its chat UI via
            // `state.assistPanel`. The panel chrome (header + status) is real
            // even before the chat content is attached.
            if state.showAssist {
                assistPanel
            }
        }
    }

    private var backendOptions: [(any AssembleBackend, BackendAvailability)] {
        let configuration = state.reconstructedProject?.configuration
            ?? BuildConfiguration(outputFileName: "libreconstructed.dylib")
        return BackendRegistry.availableBackends(configuration: configuration)
    }

    private var backendSelection: Binding<String?> {
        Binding(
            get: { state.selectedBackendID },
            set: { id in Task { await state.setBackend(id) } }
        )
    }

    private var backendPickerHelp: String {
        let unavailable = backendOptions.filter { !$0.1.isAvailable }
        guard !unavailable.isEmpty else {
            return "Choose the Assemble backend. Automatic routes each source file to the backend registered for its extension."
        }
        let details = unavailable.map { backend, availability in
            if case .unavailable(let reason, let guidance) = availability {
                return "\(backend.displayName): \(reason) \(guidance)"
            }
            return backend.displayName
        }.joined(separator: " ")
        return "Choose the Assemble backend. Unavailable backends need their toolchain installed. \(details)"
    }

    @ViewBuilder
    private var detailContent: some View {
        switch section ?? .overview {
        case .overview:
            BinaryOverviewView(state: state)
        case .functions:
            FriendlyFunctionBrowser(state: state, searchText: $searchText)
        case .code:
            FriendlyCodeViewer(state: state)
        case .strings:
            StringsBrowser(state: state, searchText: $searchText)
        case .dependencies:
            DependenciesBrowser(state: state)
        case .symbols:
            SymbolsBrowser(state: state, searchText: $searchText)
        case .binaryInfo:
            BinaryInfoView(state: state)
        case .history:
            AnalysisHistoryView(state: state)
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

/// Root view: picks Friendly or Master workspace from session mode.
public struct DecompilerRootView: View {
    @Bindable var state: DecompilerObservableState

    public init(state: DecompilerObservableState) {
        self.state = state
    }

    public var body: some View {
        Group {
            switch state.mode {
            case .friendly:
                FriendlyWorkspaceView(state: state)
            case .master:
                MasterWorkspaceView(state: state)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
