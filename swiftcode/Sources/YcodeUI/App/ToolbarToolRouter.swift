import AppKit
import YcodeIDECore



@MainActor
public enum ToolbarToolRouter {
    private static var installed = false

    public static func install() {
        guard !installed else { return }
        installed = true
        NotificationCenter.default.addObserver(
            forName: .toolbarToolActivated, object: nil, queue: .main
        ) { note in
            let toolID = note.userInfo?["toolID"] as? String ?? ""
            MainActor.assumeIsolated { handle(toolID: toolID) }
        }
    }

    private static var workspaceFolder: URL {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            return wc.workspaceFolder
        }
        if let wc = NSApp.mainWindow?.windowController as? WorkspaceWindowController {
            return wc.workspaceFolder
        }
        return FileManager.default.temporaryDirectory
    }

    public static func handle(toolID: String) {
        guard let destination = ToolbarActionManager.shared.destination(for: toolID) else { return }
        switch destination {
        case .terminal:
            TerminalWindowManager.shared.showWindow(workspaceFolder: workspaceFolder)
        case .ipaBuild:
            IPABuildWindowManager.shared.showWindow()
        case .deviceConnect:
            DeviceConnectWindowManager.shared.showWindow()
        case .visualUIBuilder:
            VisualUIBuilderWindowManager.shared.showWindow()
        case .codingDictionary:
            CodingDictionaryWindowManager.shared.showWindow()
        case .ciBuild:
            CIWorkflowWindowManager.shared.showWindow(workspaceFolder: workspaceFolder)
        case .virtualization:
            VirtualizationWindowManager.shared.showWindow()
        case .iconComposer:
            IconComposerWindowManager.shared.showWindow(workspaceFolder: workspaceFolder)
        case .sfSymbolsBrowser:
            SFSymbolBrowserWindowManager.shared.showWindow()
        case .databaseExplorer:
            DatabaseExplorerWindowManager.shared.showWindow()
        case .sourceControl:
            SourceControlWindowManager.shared.showWindow(workspaceFolder: workspaceFolder)
        case .extensionMarketplace:
            ExtensionsWindowManager.shared.show()
        case .documentationBrowser, .searchDocumentation:
            DocumentationBrowserWindowManager.shared.showWindow()
        case .devTools:
            SCToolsWindowManager.shared.showWindow(workspaceFolder: workspaceFolder)
        case .deployments:
            DeploymentWindowManager.shared.showWindow(workspaceFolder: workspaceFolder)
        case .simulatorMain:
            if let project = ProjectSessionStore.shared.activeProject {
                SimulatorWindowManager.shared.showWindow(for: project)
            }
        case .assistView:
            NSApp.sendAction(Selector(("showCodingAssistant:")), to: nil, from: nil)
        case .projectSettings:
            NSApp.sendAction(Selector(("showProjectSettings:")), to: nil, from: nil)
        case .settings:
            SettingsWindowController.shared.show(pane: "General")
        default:
            break
        }
    }
}
