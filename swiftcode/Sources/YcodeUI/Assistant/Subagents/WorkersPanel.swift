import AppKit
import SwiftUI
import YcodeAssistant

@MainActor
public enum WorkersPanel {
    private static weak var activeHost: WorkersHostingController?
    private static var windowController: NSWindowController?

    /// Presents the full Assist Workers dashboard as a modal sheet from the current view controller or key window.
    public static func present(from presenter: NSViewController? = nil) {
        if let activeHost, let window = activeHost.view.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let host = WorkersHostingController(rootView: WorkersMainView())
        host.preferredContentSize = CGSize(width: 620, height: 540)
        host.sizingOptions = [.preferredContentSize]
        host.rootView = WorkersMainView(onClose: { [weak host] in
            guard let host else { return }
            if host.presentingViewController != nil {
                host.dismiss(nil)
            } else {
                host.view.window?.close()
            }
        })

        let target = presenter?.view.window?.contentViewController ?? presenter ?? NSApp.keyWindow?.contentViewController
        if let target, target.view.window != nil {
            target.presentAsSheet(host)
        } else {
            let window = NSWindow(contentViewController: host)
            window.title = "Assist Workers"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(host.preferredContentSize)
            let controller = NSWindowController(window: window)
            windowController = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        activeHost = host
    }

    /// Returns a localized, concise title for toolbar or status buttons representing the current worker runtime state.
    public static func buttonTitle() -> String {
        let state = WorkerRuntimeState.shared
        let active = state.activeWorkers.count
        if active > 0 { return "Workers · \(active)" }
        let total = state.allWorkers.count
        return total > 0 ? "Workers · \(total)" : "Workers"
    }
}

private final class WorkersHostingController: NSHostingController<WorkersMainView> {
    override func cancelOperation(_ sender: Any?) {
        dismiss(nil)
    }
}

@MainActor
public final class WorkersStripView: NSView {
    private let hosting: NSHostingView<WorkersOnAssistView>

    public init() {
        hosting = NSHostingView(rootView: WorkersOnAssistView())
        hosting.sizingOptions = [.intrinsicContentSize]
        super.init(frame: .zero)
        wantsLayer = true
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isHidden = WorkerRuntimeState.shared.allWorkers.isEmpty
        observe()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func observe() {
        withObservationTracking {
            _ = WorkerRuntimeState.shared.allWorkers.isEmpty
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isHidden = WorkerRuntimeState.shared.allWorkers.isEmpty
                self.observe()
            }
        }
    }
}
