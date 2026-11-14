import Foundation
import SwiftUI



public enum DecompilerLifecycle {
    @MainActor private static var didInstall = false

    
    
    
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
            
            
            
            await EngineRegistry.shared.installDefaults()
            await EngineBootstrap.installDefaults()
        }
    }

    
    @MainActor
    public static func showWorkspace(sessionID: UUID? = nil) {
        DecompilerWindowManager.shared.showWindow(sessionID: sessionID)
    }

    
    @MainActor
    public static func closeAllWindows() {
        DecompilerWindowManager.shared.closeAllWindows()
    }

    
    
    @MainActor
    public static var activeState: DecompilerObservableState? {
        DecompilerWindowManager.shared.activeState
    }

    
    
    
    @MainActor
    public static func setAssistPanel(_ panel: @escaping @MainActor (DecompilerObservableState) -> AnyView) {
        for state in DecompilerWindowManager.shared.allStates {
            state.assistPanel = panel(state)
        }
        
        
        assistPanelProvider = panel
        DecompilerWindowManager.shared.onStateCreated = { state in
            state.assistPanel = panel(state)
        }
    }

    
    @MainActor
    public static var assistPanelProvider: (@MainActor (DecompilerObservableState) -> AnyView)?

    
    
    
    @MainActor
    public static func setEditorHandoff(_ handoff: (any DecompilerEditorHandoff)?) {
        DecompilerEditorBridge.register(handoff)
    }
}
