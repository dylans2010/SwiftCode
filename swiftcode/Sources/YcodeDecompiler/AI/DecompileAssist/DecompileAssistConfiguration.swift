import Foundation
import Observation



@MainActor
@Observable
public final class DecompileAssistConfiguration {
    public static let shared = DecompileAssistConfiguration()

    private enum Keys {
        static let modelOverride = "com.swiftcode.decompiler.assist.modelOverride"
        static let panelVisible = "com.swiftcode.decompiler.assist.panelVisible"
    }

    
    
    public var modelOverride: String? {
        didSet { UserDefaults.standard.set(modelOverride, forKey: Keys.modelOverride) }
    }

    
    public var panelVisible: Bool {
        didSet { UserDefaults.standard.set(panelVisible, forKey: Keys.panelVisible) }
    }

    private init() {
        let defaults = UserDefaults.standard
        modelOverride = defaults.string(forKey: Keys.modelOverride)
        panelVisible = defaults.object(forKey: Keys.panelVisible) as? Bool ?? true
    }
}
