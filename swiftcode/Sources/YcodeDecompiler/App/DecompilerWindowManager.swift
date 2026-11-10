import SwiftUI
import AppKit

/// Owns the Decompiler workspace windows.
///
/// Design choice: **one window per session**, keyed by session UUID. Each
/// window gets its own `DecompilerObservableState` bound to its
/// `DecompilerSession`, so multiple binaries can be analyzed side by side
/// without state leaking between them. Sessions themselves are owned by
/// `DecompilerSessionManager`; closing a window only closes the window —
/// the session stays alive in the manager and can be re-shown.
@MainActor
public final class DecompilerWindowManager: NSObject, NSWindowDelegate {
    public static let shared = DecompilerWindowManager()

    /// Window controllers keyed by the session UUID they display.
    private var controllers: [UUID: DecompilerWindowController] = [:]
    /// Observable states keyed by session UUID (kept so re-shown windows
    /// resume with their selection and view state intact).
    private var states: [UUID: DecompilerObservableState] = [:]

    /// Called whenever a new observable state is created (e.g. to inject
    /// the Decompile Assist panel provided by the AI module).
    public var onStateCreated: ((DecompilerObservableState) -> Void)?

    private override init() { super.init() }

    /// The state of the key (frontmost) Decompiler window, if any.
    public var activeState: DecompilerObservableState? {
        guard let key = NSApp.keyWindow?.windowController as? DecompilerWindowController
                ?? controllers.values.first(where: { $0.window?.isKeyWindow == true })
                ?? controllers.values.first else { return nil }
        return key.state
    }

    /// All live states (for app-level wiring such as injecting the assist panel).
    public var allStates: [DecompilerObservableState] { Array(states.values) }

    /// Show (or create) the workspace window for a session.
    /// Pass nil to use the manager's active session or create a fresh one.
    public func showWindow(sessionID: UUID? = nil) {
        Task { await showWindowAsync(sessionID: sessionID) }
    }

    public func showWindowAsync(sessionID: UUID? = nil) async {
        let manager = DecompilerSessionManager.shared
        let session: DecompilerSession
        if let sessionID,
           let existing = await manager.session(id: sessionID) {
            session = existing
        } else if let active = await manager.activeSession() {
            session = active
        } else {
            session = await manager.createSession()
        }

        if let existing = controllers[session.id] {
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let state: DecompilerObservableState
        if let existing = states[session.id] {
            state = existing
        } else {
            state = DecompilerObservableState(session: session)
            states[session.id] = state
            onStateCreated?(state)
            Task { await state.reloadAll() }
        }

        let controller = DecompilerWindowController(state: state)
        controller.window?.delegate = self
        controllers[session.id] = controller
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Close the window for a specific session, or all windows when nil.
    public func closeWindow(sessionID: UUID? = nil) {
        if let sessionID {
            controllers[sessionID]?.close()
        } else {
            for controller in controllers.values { controller.close() }
        }
    }

    public func closeAllWindows() {
        controllers.values.forEach { $0.close() }
    }

    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let controller = window.windowController as? DecompilerWindowController
        else { return }
        controllers = controllers.filter { $0.value !== controller }
        // The session and its observable state survive so the window can be
        // re-opened with the same selection; the state is dropped only when
        // the session itself is closed via DecompilerSessionManager.
    }
}
