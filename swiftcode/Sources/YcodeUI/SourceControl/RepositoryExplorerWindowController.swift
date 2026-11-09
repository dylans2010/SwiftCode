import AppKit
import SwiftUI
import YcodeIDECore
import YcodeIDEShell
import YcodeAssistant

@MainActor
public final class RepositoryExplorerWindowManager: NSObject {
    public static let shared = RepositoryExplorerWindowManager()
    private var controllers: [String: RepositoryExplorerWindowController] = [:]

    private override init() {}

    public func showWindow(workspaceFolder: URL? = nil, project: Project? = nil) {
        let fallbackProject: Project = {
            var p = Project(name: workspaceFolder?.lastPathComponent ?? "Repository")
            if let folder = workspaceFolder {
                p.customDirectoryPath = folder.path
            }
            return p
        }()
        let activeProject = project ?? ProjectSessionStore.shared.activeProject ?? fallbackProject
        let key = activeProject.directoryURL.path
        if let existing = controllers[key] {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        let vm = GitViewModel()
        vm.repositoryURL = activeProject.directoryURL
        Task {
            await vm.refreshInstallationStatus()
            await vm.refreshStatus()
        }

        let controller = RepositoryExplorerWindowController(gitViewModel: vm, project: activeProject)
        controllers[key] = controller
        controller.window?.delegate = self
        controller.window?.makeKeyAndOrderFront(nil)
    }

    public func closeWindow(key: String) {
        controllers[key]?.close()
        controllers[key] = nil
    }
}

extension RepositoryExplorerWindowManager: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let entry = controllers.first(where: { $0.value.window === window }) else { return }
        controllers[entry.key] = nil
    }
}

@MainActor
public final class RepositoryExplorerWindowController: NSWindowController {
    public let gitViewModel: GitViewModel
    public let project: Project

    public init(gitViewModel: GitViewModel, project: Project) {
        self.gitViewModel = gitViewModel
        self.project = project
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1150, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Repository Explorer — \(project.name)"
        window.minSize = NSSize(width: 900, height: 600)
        window.center()
        window.setFrameAutosaveName("SwiftCodeRepositoryExplorerWindow")
        let rootView = RepositoryExplorerView(gitViewModel: gitViewModel, project: project)
        window.contentView = NSHostingView(rootView: rootView)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
