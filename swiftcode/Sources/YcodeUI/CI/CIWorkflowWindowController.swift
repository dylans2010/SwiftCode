import AppKit
import SwiftUI
import YcodeIDECore
import YcodeIDEShell

@MainActor
public final class CIWorkflowWindowManager: NSObject {
    public static let shared = CIWorkflowWindowManager()
    private var controllers: [String: CIWorkflowWindowController] = [:]

    private override init() {}

    public func showWindow(workspaceFolder: URL) {
        let key = workspaceFolder.standardizedFileURL.path
        if let existing = controllers[key] {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let controller = CIWorkflowWindowController(workspaceFolder: workspaceFolder)
        controllers[key] = controller
        controller.window?.delegate = self
        controller.window?.makeKeyAndOrderFront(nil)
    }

    public func closeWindow(workspaceFolder: URL) {
        controllers[workspaceFolder.standardizedFileURL.path]?.close()
    }

    func controllerClosed(_ controller: CIWorkflowWindowController) {
        controllers[controller.workspaceFolder.standardizedFileURL.path] = nil
    }
}

extension CIWorkflowWindowManager: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let wc = controllers.values.first(where: { $0.window === window }) else { return }
        controllerClosed(wc)
    }
}

@MainActor
public final class CIWorkflowWindowController: NSWindowController, NSToolbarDelegate {
    public static let size = NSSize(width: 1200, height: 780)

    public let workspaceFolder: URL

    public init(workspaceFolder: URL) {
        self.workspaceFolder = workspaceFolder
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CI Visual Workflows — \(workspaceFolder.lastPathComponent)"
        window.minSize = NSSize(width: 900, height: 600)
        window.setFrameAutosaveName("SwiftCodeCIWorkflowWindow")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupContent()
        setupToolbar(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupContent() {
        guard let window else { return }
        let project = ProjectSessionStore.shared.activeProject
            ?? Project(name: workspaceFolder.lastPathComponent, directoryURL: workspaceFolder)
        let gitViewModel = GitViewModel()
        gitViewModel.repositoryURL = workspaceFolder
        window.contentView = NSHostingView(rootView: WorkflowDashboardView(project: project, gitViewModel: gitViewModel))
    }

    private func setupToolbar(window: NSWindow) {
        let toolbar = NSToolbar(identifier: "CIWorkflowToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
    }

    public func toolbar(_ toolbar: NSToolbar,
                        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                        willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard itemIdentifier == .actionsRunsMonitor else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Actions Runs Monitor"
        item.paletteLabel = "Actions Runs Monitor"
        item.toolTip = "Open the GitHub Actions runs monitor"
        item.image = NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: nil)
        item.target = self
        item.action = #selector(showActionsRunsMonitor(_:))
        return item
    }

    @objc private func showActionsRunsMonitor(_ sender: Any?) {
        CIWindowManager.shared.showWindow(workspaceFolder: workspaceFolder)
    }
}

private extension NSToolbarItem.Identifier {
    static let actionsRunsMonitor = NSToolbarItem.Identifier("com.swiftcode.ci.actionsRunsMonitor")
}
