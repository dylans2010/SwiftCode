import SwiftUI
import AppKit









@MainActor
public final class DecompilerWindowManager: NSObject, NSWindowDelegate {
    public static let shared = DecompilerWindowManager()

    
    private var controllers: [UUID: DecompilerWindowController] = [:]
    
    
    private var states: [UUID: DecompilerObservableState] = [:]

    
    
    public var onStateCreated: ((DecompilerObservableState) -> Void)?

    private override init() { super.init() }

    
    public var activeState: DecompilerObservableState? {
        guard let key = NSApp.keyWindow?.windowController as? DecompilerWindowController
                ?? controllers.values.first(where: { $0.window?.isKeyWindow == true })
                ?? controllers.values.first else { return nil }
        return key.state
    }

    
    public var allStates: [DecompilerObservableState] { Array(states.values) }

    
    
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
        
        
        
    }
}
