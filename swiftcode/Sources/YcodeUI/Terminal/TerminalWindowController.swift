import AppKit
import SwiftUI

@MainActor
public final class TerminalWindowManager: NSObject {
    public static let shared = TerminalWindowManager()
    private var controller: TerminalWindowController?

    private override init() {}

    public func showWindow(workspaceFolder: URL? = nil) {
        if let existing = controller {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let controller = TerminalWindowController(workspaceFolder: workspaceFolder)
        self.controller = controller
        controller.window?.delegate = self
        controller.window?.makeKeyAndOrderFront(nil)
    }

    public func toggle(workspaceFolder: URL? = nil) {
        if let controller, controller.window?.isVisible == true {
            controller.close()
        } else {
            showWindow(workspaceFolder: workspaceFolder)
        }
    }
}

extension TerminalWindowManager: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === controller?.window {
            controller?.panel.shutdown()
            controller = nil
        }
    }
}

@MainActor
public final class TerminalWindowController: NSWindowController {
    public static let size = NSSize(width: 900, height: 520)

    public let workspaceFolder: URL?

    public init(workspaceFolder: URL? = nil) {
        self.workspaceFolder = workspaceFolder
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = workspaceFolder.map { "Terminal — \($0.lastPathComponent)" } ?? "Integrated Terminal"
        window.setFrameAutosaveName("SwiftCodeTerminalWindow")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 260)
        let panel = TerminalPanelController(workspaceFolder: workspaceFolder)
        panel.showsPanelControls = false
        self.panel = panel
        super.init(window: window)
        window.contentViewController = panel
        window.setContentSize(Self.size)
        panel.onOpenPath = { path, line in
            guard let wc = NSApp.windows.lazy.compactMap({ $0.windowController as? WorkspaceWindowController }).first else { return false }
            wc.window?.makeKeyAndOrderFront(nil)
            wc.open(path: path, line: line)
            return true
        }
    }

    public let panel: TerminalPanelController

    public override func close() {
        panel.shutdown()
        super.close()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
