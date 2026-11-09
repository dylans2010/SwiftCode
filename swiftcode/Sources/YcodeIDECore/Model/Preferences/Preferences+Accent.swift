import Foundation

/// A named preset for the app-wide accent color.
///
/// Presets store `#RRGGBB` hex values in `Preferences.customAccentColor`.
/// An empty value means "System Default", which resolves to the platform
/// accent color (`NSColor.controlAccentColor` / SwiftUI `accentColor`).
public struct AccentColorPreset: Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let hex: String

    public init(name: String, hex: String) {
        self.name = name
        self.hex = hex
    }
}

extension Preferences {
    /// The app-wide accent color override, as `#RRGGBB`. Empty = system default.
    /// This is the same backing key historically used by the editor "custom
    /// accent color" setting; it now drives the whole app's accent color.
    public var appAccentColor: String {
        get { customAccentColor }
        set { customAccentColor = newValue }
    }

    /// Whether the user has chosen a custom accent (vs. the system default).
    public var hasCustomAccentColor: Bool {
        !appAccentColor.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Built-in accent color presets shown in Settings ▸ Appearance.
    public static let accentColorPresets: [AccentColorPreset] = [
        AccentColorPreset(name: "System Blue", hex: "#007AFF"),
        AccentColorPreset(name: "Graphite", hex: "#8E8E93"),
        AccentColorPreset(name: "Indigo", hex: "#5856D6"),
        AccentColorPreset(name: "Purple", hex: "#AF52DE"),
        AccentColorPreset(name: "Pink", hex: "#FF2D55"),
        AccentColorPreset(name: "Red", hex: "#FF3B30"),
        AccentColorPreset(name: "Orange", hex: "#FF9500"),
        AccentColorPreset(name: "Yellow", hex: "#FFCC00"),
        AccentColorPreset(name: "Green", hex: "#34C759"),
        AccentColorPreset(name: "Mint", hex: "#00C7BE"),
        AccentColorPreset(name: "Teal", hex: "#30B0C7"),
        AccentColorPreset(name: "Brown", hex: "#A2845E"),
    ]

    /// The preset matching the stored accent hex, if any.
    public var selectedAccentPreset: AccentColorPreset? {
        let current = appAccentColor.trimmingCharacters(in: .whitespaces).uppercased()
        guard !current.isEmpty else { return nil }
        return Self.accentColorPresets.first { $0.hex.uppercased() == current }
    }

    /// Applies a preset (or `nil` for the system default) as the app accent.
    public func selectAccentPreset(_ preset: AccentColorPreset?) {
        appAccentColor = preset?.hex ?? ""
    }
}
