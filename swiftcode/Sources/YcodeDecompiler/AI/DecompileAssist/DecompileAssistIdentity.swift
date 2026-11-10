import Foundation

/// Stable identity for the Decompile Assist subsystem.
public enum DecompileAssistIdentity {
    /// Display name shown in the UI.
    public static let name = "Decompile Assist"
    /// Prefix for every SDK session id owned by Decompile Assist. The shared
    /// `GoogleCloudSDKRuntime` is multiplexed across features; tool-execution
    /// dispatch uses this prefix to route requests to the right session.
    public static let sessionIDPrefix = "decompile-assist-"
}
