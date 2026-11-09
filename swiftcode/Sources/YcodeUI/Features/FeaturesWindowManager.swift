import AppKit
import SwiftUI
import YcodeIDECore
import YcodeAssistant



@MainActor
public final class FeaturesWindowManager: NSObject, NSWindowDelegate {
    public static let shared = FeaturesWindowManager()

    private var controllers: [String: NSWindowController] = [:]

    private override init() { super.init() }

    

    public func showExtensionMarketplace() {
        show("extensionMarketplace", title: "Extension Marketplace", size: NSSize(width: 900, height: 640)) {
            ExtensionMarketplaceView()
        }
    }

    public func showAssetManager() {
        show("assetManager", title: "Asset Manager", size: NSSize(width: 860, height: 620)) {
            AssetManagerView()
                .environment(ProjectSessionStore.shared)
        }
    }

    

    public func showTestTools(project: Project? = nil) {
        let resolved = project ?? ProjectSessionStore.shared.activeProject
        guard let resolved else { return }
        show("testTools", title: "Test Center", size: NSSize(width: 980, height: 720)) {
            TestToolsView(project: resolved)
        }
    }

    

    public func showDebuggingTools() {
        show("debuggingTools", title: "Debug Tools", size: NSSize(width: 980, height: 760)) {
            DebuggingToolsView()
        }
    }

    

    public func showChooseModel() {
        show("chooseModel", title: "Choose My Own Model", size: NSSize(width: 560, height: 640)) {
            ChooseModelView()
                .environmentObject(AppSettings.shared)
        }
    }

    

    private func show<Content: View>(_ key: String, title: String, size: NSSize, @ViewBuilder content: () -> Content) {
        if let existing = controllers[key], let window = existing.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content())
        let controller = NSWindowController(window: window)
        controllers[key] = controller
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        controllers = controllers.filter { $0.value.window !== window }
    }
}
