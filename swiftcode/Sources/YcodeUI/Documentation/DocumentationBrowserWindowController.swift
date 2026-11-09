import AppKit
import SwiftUI

@MainActor
public final class DocumentationBrowserWindowManager {
    public static let shared = DocumentationBrowserWindowManager()

    private var controller: DocumentationBrowserWindowController?
    public var pendingURLToOpen: URL? = nil

    private init() {}

    public func openURL(_ url: URL) {
        pendingURLToOpen = url
        showWindow()
        NotificationCenter.default.post(name: .openDocCURLNotification, object: url)
    }

    public func showWindow() {
        if let controller, let window = controller.window {
            controller.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = DocumentationBrowserWindowController()
        self.controller = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class DocumentationBrowserWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Documentation - Developer Bookshelf (Offline)"
        window.minSize = NSSize(width: 1200, height: 800)
        window.setFrameAutosaveName("DocumentationBrowserWindow")
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: DocumentationBrowserView())
        self.init(window: window)
    }
}
