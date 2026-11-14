import Foundation





public enum PermissionPolicy {
    public enum Risk: String, Sendable, Codable {
        
        case readOnly
        
        case requiresApproval
    }

    
    private static let approvalPrefixes = [
        "rename_", "add_", "annotate_", "create_user_label",
        "save_analysis_finding", "delete_", "remove_", "set_",
        "update_", "write_", "import_"
    ]

    
    private static let approvalExact: Set<String> = [
        "create_user_label", "save_analysis_finding"
    ]

    
    private static let readOnlyPrefixes = [
        "get_", "list_", "search_", "find_", "read_", "show_",
        "describe_", "query_", "lookup_", "count_", "summarize_"
    ]

    
    
    
    public static func classify(toolName: String) -> Risk {
        let name = toolName.lowercased()
        if approvalExact.contains(name) { return .requiresApproval }
        if approvalPrefixes.contains(where: { name.hasPrefix($0) }) {
            return .requiresApproval
        }
        if readOnlyPrefixes.contains(where: { name.hasPrefix($0) }) {
            return .readOnly
        }
        return .requiresApproval
    }

    
    public static func requiresApproval(toolName: String) -> Bool {
        classify(toolName: toolName) == .requiresApproval
    }
}
