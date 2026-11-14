import Foundation



public struct WorkspacePreferences: Codable, Sendable {
    
    public var masterLayoutName: String = "default"
    
    public var showInspector: Bool = true
    
    public var showConsole: Bool = false
    
    public var assistantPanelVisible: Bool = true
    
    
    public var friendlySidebarSelection: String = "overview"
    
    public var masterSidebarSelection: String = "functions"
    
    public var showSidebar: Bool = true

    public init() {}

    
    
    public var manifestPreferences: ProjectManifest.WorkspacePreferences {
        var p = ProjectManifest.WorkspacePreferences()
        p.friendlySidebarSelection = friendlySidebarSelection
        p.masterLayout = masterLayoutName
        p.showInspector = showInspector
        p.showConsole = showConsole
        p.assistantPanelVisible = assistantPanelVisible
        return p
    }

    
    public init(manifestPreferences p: ProjectManifest.WorkspacePreferences) {
        self.init()
        friendlySidebarSelection = p.friendlySidebarSelection
        masterLayoutName = p.masterLayout
        showInspector = p.showInspector
        showConsole = p.showConsole
        assistantPanelVisible = p.assistantPanelVisible
    }

    

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
