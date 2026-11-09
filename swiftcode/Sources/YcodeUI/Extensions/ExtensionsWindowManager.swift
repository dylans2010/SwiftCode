import AppKit
import SwiftUI
import SwiftCodeExtensions






@MainActor
public final class ExtensionsWindowManager {
    public static let shared = ExtensionsWindowManager()

    private var window: NSWindow?
    private var didCheckUpdates = false

    private init() {}

    public func show() {
        Task {
            let manager = ExtensionManager.shared
            await manager.ensureReady()
            if !didCheckUpdates {
                didCheckUpdates = true
                await manager.checkUpdates()
            }
        }
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = NSHostingController(rootView: ExtensionsHomeView())
        let w = window ?? NSWindow(contentViewController: controller)
        w.contentViewController = controller
        w.title = "SwiftCode Extensions"
        w.setContentSize(NSSize(width: 1024, height: 660))
        w.minSize = NSSize(width: 820, height: 520)
        window = w
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
