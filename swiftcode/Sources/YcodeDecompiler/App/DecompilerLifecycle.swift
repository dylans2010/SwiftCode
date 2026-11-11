import Foundation
import SwiftUI

/// Startup wiring for the Decompiler subsystem: engine registration and
/// window/command hooks. Call once from the app entry point.
public enum DecompilerLifecycle {
    @MainActor private static var didInstall = false

    /// Install default analysis engines and register window command hooks.
    /// Safe to call multiple times — installation happens once (the check
    /// runs on the main actor so concurrent calls cannot double-install).
    public static func installDefaultEngines() {
        Task { await installOnce() }
    }

    @MainActor
    private static func installOnce() {
        guard !didInstall else { return }
        didInstall = true
#if canImport(Subprocess)
        ProcessRunnerRegistry.register(SwiftSubprocessRunner())
#endif
#if canImport(SwiftTreeSitter)
        PreAssembleValidatorRegistry.register(TreeSitterSourceValidator())
#endif
        BackendRegistry.register(QuickJSBackend())
        Task {
            // Built-in registry defaults plus concrete engine bootstrap
            // (Ghidra headless, bundled tools, etc.) provided by the
            // Engines layer.
            await EngineRegistry.shared.installDefaults()
            await EngineBootstrap.installDefaults()
        }
    }

    /// Show the Decompiler workspace window (creating a session if needed).
    @MainActor
    public static func showWorkspace(sessionID: UUID? = nil) {
        DecompilerWindowManager.shared.showWindow(sessionID: sessionID)
    }

    /// Close every Decompiler workspace window.
    @MainActor
    public static func closeAllWindows() {
        DecompilerWindowManager.shared.closeAllWindows()
    }

    /// The observable state of the frontmost Decompiler window, if any.
    /// App layers use this to inject the Decompile Assist panel.
    @MainActor
    public static var activeState: DecompilerObservableState? {
        DecompilerWindowManager.shared.activeState
    }

    /// Inject the Decompile Assist chat view into every current and future
    /// workspace. `panel` is a factory invoked once per observable state so
    /// each window's panel is bound to that window's own session.
    @MainActor
    public static func setAssistPanel(_ panel: @escaping @MainActor (DecompilerObservableState) -> AnyView) {
        for state in DecompilerWindowManager.shared.allStates {
            state.assistPanel = panel(state)
        }
        // Also stash the factory on the manager path for windows created
        // later: new states pick it up via `assistPanelProvider`.
        assistPanelProvider = panel
        DecompilerWindowManager.shared.onStateCreated = { state in
            state.assistPanel = panel(state)
        }
    }

    /// Provider used to fill `assistPanel` on newly created states.
    @MainActor
    public static var assistPanelProvider: (@MainActor (DecompilerObservableState) -> AnyView)?

    /// Register the main-editor handoff (implemented by the app layer) so
    /// reconstructed projects open in SwiftCode's primary editor instead of
    /// the Decompiler's read-only viewers.
    @MainActor
    public static func setEditorHandoff(_ handoff: (any DecompilerEditorHandoff)?) {
        DecompilerEditorBridge.register(handoff)
    }
}
