import Foundation
import Observation

/// User-facing configuration for Decompile Assist.
/// Persisted under `com.swiftcode.decompiler.assist` in UserDefaults.
@MainActor
@Observable
public final class DecompileAssistConfiguration {
    public static let shared = DecompileAssistConfiguration()

    private enum Keys {
        static let modelOverride = "com.swiftcode.decompiler.assist.modelOverride"
        static let panelVisible = "com.swiftcode.decompiler.assist.panelVisible"
    }

    /// Optional model override. Must be a `gemini-*` model id; nil means the
    /// provider policy chooses the catalog default.
    public var modelOverride: String? {
        didSet { UserDefaults.standard.set(modelOverride, forKey: Keys.modelOverride) }
    }

    /// Whether the Decompile Assist panel is visible in the decompiler UI.
    public var panelVisible: Bool {
        didSet { UserDefaults.standard.set(panelVisible, forKey: Keys.panelVisible) }
    }

    private init() {
        let defaults = UserDefaults.standard
        modelOverride = defaults.string(forKey: Keys.modelOverride)
        panelVisible = defaults.object(forKey: Keys.panelVisible) as? Bool ?? true
    }
}
