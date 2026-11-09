import AppKit
import SwiftUI

@MainActor
public final class DeviceConnectWindowManager: NSObject {
    public static let shared = DeviceConnectWindowManager()
    private var controller: DeviceConnectWindowController?

    public func showWindow() {
        if let existing = controller {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let controller = DeviceConnectWindowController()
        self.controller = controller
        controller.window?.delegate = self
        controller.window?.makeKeyAndOrderFront(nil)
    }

    public func toggle() {
        if let controller, controller.window?.isVisible == true {
            controller.close()
        } else {
            showWindow()
        }
    }
}

extension DeviceConnectWindowManager: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === controller?.window {
            controller = nil
        }
    }
}

@MainActor
public final class DeviceConnectWindowController: NSWindowController {
    public static let shared = DeviceConnectWindowController()

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1050, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Device Connect — Physical & Tethered Hardware"
        window.center()
        window.setFrameAutosaveName("SwiftCodeDeviceConnectWindow")
        window.contentView = NSHostingView(rootView: DeviceConnectView())
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

