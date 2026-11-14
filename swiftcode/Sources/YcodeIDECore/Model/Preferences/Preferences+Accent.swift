import Foundation






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
    
    
    
    public var appAccentColor: String {
        get { customAccentColor }
        set { customAccentColor = newValue }
    }

    
    public var hasCustomAccentColor: Bool {
        !appAccentColor.trimmingCharacters(in: .whitespaces).isEmpty
    }

    
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

    
    public var selectedAccentPreset: AccentColorPreset? {
        let current = appAccentColor.trimmingCharacters(in: .whitespaces).uppercased()
        guard !current.isEmpty else { return nil }
        return Self.accentColorPresets.first { $0.hex.uppercased() == current }
    }

    
    public func selectAccentPreset(_ preset: AccentColorPreset?) {
        appAccentColor = preset?.hex ?? ""
    }
}
