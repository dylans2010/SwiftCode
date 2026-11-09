import SwiftUI

public final class StylingRegistry: Sendable {
    public static let shared = StylingRegistry()

    private init() {}

    public func registerDefaults() {
    }
}

public struct StylingBootstrap {
    public static func initialize() {
        StylingRegistry.shared.registerDefaults()
    }

    @MainActor
    public static func configureEnvironment<V: View>(_ view: V) -> some View {
        AppAccentTint {
            view
                .environment(AdaptiveLayoutEngine.shared)
                .liquidGlassEnabled(true)
                .liquidGlassStyle(.standard)
        }
    }
}
