import AppKit
import SwiftUI
import YcodeAssistant
import YcodeIDECore

@MainActor
public final class SCSetupOnboardWindowController: NSWindowController, NSWindowDelegate {
    private static var retained: SCSetupOnboardWindowController?

    @discardableResult
    public static func offerIfNeeded() -> Bool {
        let gitMissing = !GitRepository.isGitInstalled()
        Task.detached(priority: .userInitiated) {
            let tokenMissing = defaultSecretStore().readString(SecretAccount.githubToken) == nil
            guard gitMissing || tokenMissing else { return }
            await MainActor.run { present() }
        }
        return true
    }

    @MainActor
    private static func present() {
        let controller = SCSetupOnboardWindowController()
        retained = controller
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
    }

    public init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 560, height: 520)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Up SwiftCode"
        window.minSize = NSSize(width: 480, height: 440)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingController(rootView: SCSetupOnboard { [weak window] in
            window?.performClose(nil)
        })
        window.contentViewController = hosting
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func windowWillClose(_ notification: Notification) {
        Self.retained = nil
    }
}
