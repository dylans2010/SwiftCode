import Foundation

















public enum AssistModeGate {
    
    public static func allows(toolId: String, mode: AssistMode) -> Bool {
        
        
        
        
        if toolId == "execution_plan" { return true }
        switch mode {
        case .plan:
            return AssistToolRouter.metadata(for: toolId).isReadOnly
        case .agent, .turbo:
            return true
        }
    }

    
    
    
    public static func refusalMessage(toolId: String, mode: AssistMode) -> String {
        "Tool '\(toolId)' is blocked in \(mode.displayName) mode. Plan mode allows reading, searching, building and planning only — no file writes, terminal commands, Workers or other mutations. Ask for a plan first, or switch to Agent or Turbo mode to run it."
    }
}
