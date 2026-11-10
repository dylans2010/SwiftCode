import Foundation

/// Classifies analysis tools by the approval they require before running.
/// Read-only tools (queries, listings, exports of already-computed data)
/// run without prompting; anything that mutates analysis state or writes
/// files requires explicit user approval.
public enum PermissionPolicy {
    public enum Risk: String, Sendable, Codable {
        /// Pure query — no mutation, no filesystem writes.
        case readOnly
        /// Mutates analysis state or writes files — needs approval.
        case requiresApproval
    }

    /// Tool-name prefixes that always require approval.
    private static let approvalPrefixes = [
        "rename_", "add_", "annotate_", "create_user_label",
        "save_analysis_finding", "delete_", "remove_", "set_",
        "update_", "write_", "import_"
    ]

    /// Exact tool names that always require approval.
    private static let approvalExact: Set<String> = [
        "create_user_label", "save_analysis_finding"
    ]

    /// Tool-name prefixes known to be read-only queries.
    private static let readOnlyPrefixes = [
        "get_", "list_", "search_", "find_", "read_", "show_",
        "describe_", "query_", "lookup_", "count_", "summarize_"
    ]

    /// Classify a tool by name. Unknown tools default to
    /// `.requiresApproval` — fail-safe: an unrecognized name is never
    /// silently treated as read-only.
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

    /// Convenience boolean form of `classify`.
    public static func requiresApproval(toolName: String) -> Bool {
        classify(toolName: toolName) == .requiresApproval
    }
}
