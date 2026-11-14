import SwiftUI
import YcodeIDECore
#if canImport(AppKit)
import AppKit
#endif






@Observable
@MainActor
public final class AppAccentState {
    public static let shared = AppAccentState()

    
    public private(set) var hex: String
    
    public private(set) var revision = 0

    private nonisolated(unsafe) var observer: NSObjectProtocol?

    private init() {
        hex = Preferences.shared.customAccentColor
        observer = NotificationCenter.default.addObserver(
            forName: Preferences.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let current = Preferences.shared.customAccentColor
                if current != self.hex {
                    self.hex = current
                    self.revision &+= 1
                }
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    
    
    public var color: Color {
        if let c = ThemeColor(hex: hex) {
            return Color(.sRGB, red: c.redFraction, green: c.greenFraction, blue: c.blueFraction)
        }
        return .accentColor
    }

    
    public func select(_ preset: AccentColorPreset?) {
        Preferences.shared.selectAccentPreset(preset)
    }

    
    public func setCustomHex(_ value: String) {
        Preferences.shared.appAccentColor = value
    }

    public func useSystemDefault() {
        Preferences.shared.appAccentColor = ""
    }
}

extension Theme {
    
    public static var accentSwiftUIColor: Color { Color(nsColor: accentColor) }
}


public struct AppAccentTint<Content: View>: View {
    @State private var accent = AppAccentState.shared
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content.tint(accent.color)
    }
}



public struct AccentColorSettingsRow: View {
    @State private var accent = AppAccentState.shared
    @State private var customColor: Color = .accentColor

    public init() {}

    public var body: some View {
        let _ = accent.revision
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(Preferences.accentColorPresets) { preset in
                    AccentSwatch(preset: preset, isSelected: accent.hex.uppercased() == preset.hex.uppercased()) {
                        accent.select(preset)
                        syncCustomColor()
                    }
                }
            }

            HStack(spacing: 10) {
                ColorPicker("Custom", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 40)
                    .onChange(of: customColor) { _, newColor in
                        accent.setCustomHex(Self.hexString(from: newColor))
                    }

                Text("Custom Accent Color")
                    .font(.callout)

                Spacer()

                if !Preferences.shared.appAccentColor.isEmpty {
                    Button("System Default") {
                        accent.useSystemDefault()
                        syncCustomColor()
                    }
                    .controlSize(.small)
                }
            }
        }
        .onAppear { syncCustomColor() }
    }

    private func syncCustomColor() {
        if let c = ThemeColor(hex: Preferences.shared.appAccentColor) {
            customColor = Color(.sRGB, red: c.redFraction, green: c.greenFraction, blue: c.blueFraction)
        } else {
            customColor = .accentColor
        }
    }

    static func hexString(from color: Color) -> String {
        #if canImport(AppKit)
        guard let ns = NSColor(color).usingColorSpace(.sRGB) else { return "" }
        return String(format: "#%02X%02X%02X",
                      Int((ns.redComponent * 255).rounded()),
                      Int((ns.greenComponent * 255).rounded()),
                      Int((ns.blueComponent * 255).rounded()))
        #else
        return ""
        #endif
    }
}

private struct AccentSwatch: View {
    let preset: AccentColorPreset
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: preset.hex))
                .frame(width: 26, height: 26)
                .overlay {
                    Circle().stroke(isSelected ? Color.primary : Color.secondary.opacity(0.4),
                                    lineWidth: isSelected ? 2.5 : 1)
                }
                .scaleEffect(hovering ? 1.12 : 1.0)
                .shadow(color: Color(hex: preset.hex).opacity(0.5), radius: hovering ? 6 : 2, y: 2)
        }
        .buttonStyle(.plain)
        .help("\(preset.name) \(preset.hex)")
        .onHover { hovering = $0 }
    }
}
