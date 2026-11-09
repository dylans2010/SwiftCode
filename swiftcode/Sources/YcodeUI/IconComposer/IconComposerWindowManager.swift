import AppKit
import SwiftUI
import YcodeIDECore
import YcodeIcon

@MainActor
public final class IconComposerWindowManager: NSObject, NSWindowDelegate {
    public static let shared = IconComposerWindowManager()
    private var windowController: NSWindowController?
    private var hostingController: NSHostingController<IconComposerView>?
    private var model: IconComposerModel?

    private override init() {}

    public func showIconComposer(appIconSet url: URL) {
        let m = IconComposerModel(appIconSet: url)
        model = m
        let window = ensureWindow()
        hostingController?.rootView = IconComposerView(model: m)
        window.title = "Icon Composer — \(url.deletingPathExtension().lastPathComponent)"
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func showIconComposer(iconPackage url: URL) {
        guard let pkg = try? IconPackage(contentsOf: url) else {
            showWindow()
            return
        }
        let m = IconComposerModel(package: pkg)
        model = m
        let window = ensureWindow()
        hostingController?.rootView = IconComposerView(model: m)
        window.title = "Icon Composer — \(pkg.name)"
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func showWindow(workspaceFolder: URL? = nil) {
        _ = workspaceFolder
        if windowController?.window?.isVisible == true {
            windowController?.window?.makeKeyAndOrderFront(nil)
            return
        }
        let m = IconComposerModel()
        model = m
        let window = ensureWindow()
        window.title = "Icon Composer"
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func ensureWindow() -> NSWindow {
        if let window = windowController?.window {
            return window
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Icon Composer"
        window.minSize = NSSize(width: 1000, height: 640)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("IconComposerMainWindow")
        let hosting = NSHostingController(rootView: IconComposerView(model: model ?? IconComposerModel()))
        window.contentViewController = hosting
        hostingController = hosting
        let wc = NSWindowController(window: window)
        wc.window?.delegate = self
        windowController = wc
        return window
    }

    public func windowWillClose(_ notification: Notification) {
        windowController = nil
        hostingController = nil
        model = nil
    }
}
