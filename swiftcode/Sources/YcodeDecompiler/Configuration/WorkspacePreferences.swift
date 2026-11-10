import Foundation

/// Workspace layout and pane-visibility preferences for the decompiler
/// UI (both Friendly and Master modes). Persisted to UserDefaults.
public struct WorkspacePreferences: Codable, Sendable {
    /// Name of the active master-layout preset ("default", "wide", ...).
    public var masterLayoutName: String = "default"
    /// Whether the inspector pane is visible.
    public var showInspector: Bool = true
    /// Whether the console/output pane is visible.
    public var showConsole: Bool = false
    /// Whether the Decompile Assist panel is visible.
    public var assistantPanelVisible: Bool = true
    /// Selected item in the friendly-mode sidebar
    /// ("overview", "functions", "symbols", "strings", "types", ...).
    public var friendlySidebarSelection: String = "overview"
    /// Selected item in the master-mode sidebar.
    public var masterSidebarSelection: String = "functions"
    /// Whether the navigator sidebar is visible at all.
    public var showSidebar: Bool = true

    public init() {}

    /// Bridge into the manifest's nested `WorkspacePreferences` used by
    /// `ProjectManifest` for per-project overrides.
    public var manifestPreferences: ProjectManifest.WorkspacePreferences {
        var p = ProjectManifest.WorkspacePreferences()
        p.friendlySidebarSelection = friendlySidebarSelection
        p.masterLayout = masterLayoutName
        p.showInspector = showInspector
        p.showConsole = showConsole
        p.assistantPanelVisible = assistantPanelVisible
        return p
    }

    /// Adopt values previously stored per-project in a manifest.
    public init(manifestPreferences p: ProjectManifest.WorkspacePreferences) {
        self.init()
        friendlySidebarSelection = p.friendlySidebarSelection
        masterLayoutName = p.masterLayout
        showInspector = p.showInspector
        showConsole = p.showConsole
        assistantPanelVisible = p.assistantPanelVisible
    }

    // MARK: - Persistence (UserDefaults suite "com.swiftcode.decompiler")

    private static let storageKey = "WorkspacePreferences.v1"

    public static var shared: WorkspacePreferences {
        get { DecompilerDefaults.load(WorkspacePreferences.self,
                                      key: storageKey, fallback: WorkspacePreferences()) }
        set { DecompilerDefaults.save(newValue, key: storageKey) }
    }

    public static func load() -> WorkspacePreferences { shared }

    public func save() {
        WorkspacePreferences.shared = self
    }
}
