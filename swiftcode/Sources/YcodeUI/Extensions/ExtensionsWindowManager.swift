import AppKit
import SwiftUI
import SwiftCodeExtensions






@MainActor
public final class ExtensionsWindowManager: NSObject, NSWindowDelegate {
    public static let shared = ExtensionsWindowManager()

    private var window: NSWindow?
    private var didCheckUpdates = false

    private override init() {
        super.init()
    }

    public func show() {
        Task {
            let manager = ExtensionManager.shared
            await manager.ensureReady()
            if !didCheckUpdates {
                didCheckUpdates = true
                await manager.checkUpdates()
            }
        }
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = NSHostingController(rootView: ExtensionsHomeView())
        let w = NSWindow(contentViewController: controller)
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.title = "SwiftCode Extensions"
        w.setContentSize(NSSize(width: 1024, height: 660))
        w.minSize = NSSize(width: 820, height: 520)
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        self.window = w
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        self.window = nil
    }
}
