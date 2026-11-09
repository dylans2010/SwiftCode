import Foundation
import SwiftUI
import YcodeIDECore
import YcodeIDEShell

public struct ShellColors {
    public let dark: Bool
    public var onAccent = false

    public init(_ scheme: ColorScheme) { dark = scheme == .dark }

    private func gray(_ light: Double, _ dark: Double) -> Color {
        let v = (self.dark ? dark : light) / 255
        return Color(.sRGB, red: v, green: v, blue: v)
    }

    public var sidebar: Color { gray(251, 28) }
    public var content: Color { gray(255, 30) }
    public var capsuleStroke: Color { gray(225, 20) }
    public var segmentPill: Color { gray(204, 70) }
    public var selectorPill: Color { gray(226, 59) }
    public var separator: Color { gray(229, 57) }
    public var sidebarDivider: Color { gray(227, 21) }
    public var label: Color { onAccent ? .white : gray(23, 253) }
    public var secondaryLabel: Color { onAccent ? .white : gray(128, 123) }
    public var tertiaryLabel: Color { gray(170, 90) }
    public var toolbarIcon: Color { gray(138, 126) }
    public var chevron: Color { onAccent ? .white : gray(124, 152) }
    public var popUpFill: Color { gray(232, 46) }
    public var fieldStroke: Color { gray(213, 49) }
    public var fieldFill: Color { gray(255, 22) }
    public var rowSelection: Color { gray(220, 64) }
    public var minimapText: Color { gray(189, 86) }
    public var accent: Color {
        if let c = ThemeColor(hex: UserDefaults.standard.string(forKey: "SwiftCode.customAccentColor") ?? "") {
            return Color(.sRGB, red: c.redFraction, green: c.greenFraction, blue: c.blueFraction)
        }
        return dark ? Color(.sRGB, red: 53 / 255, green: 116 / 255, blue: 233 / 255) : Color(.sRGB, red: 52 / 255, green: 120 / 255, blue: 246 / 255)
    }
    public var error: Color { Color(.sRGB, red: 1, green: 59 / 255, blue: 48 / 255) }
    public var warning: Color { Color(.sRGB, red: 1, green: 204 / 255, blue: 0) }
    public var success: Color { Color(.sRGB, red: 52 / 255, green: 199 / 255, blue: 89 / 255) }

    public func tint(_ t: OutlineRow.Tint) -> Color {
        if onAccent { return .white }
        return switch t {
        case .accent: accent
        case .secondary: secondaryLabel
        case .error: error
        case .warning: warning
        case .success: success
        }
    }
}

public enum ShellFonts {
    public static let row = Font.system(size: 13)
    public static let rowBold = Font.system(size: 13, weight: .semibold)
    public static let small = Font.system(size: 11)
    public static let smallBold = Font.system(size: 11, weight: .bold)
    public static let mini = Font.system(size: 10)
    #if os(Linux)
    public static let smallTracking: CGFloat = 0.35
    #else
    public static let smallTracking: CGFloat = 0
    #endif
    public static let activityName = Font.system(size: 13, weight: .bold)
    public static let toolbarTitle = Font.system(size: 13, weight: .semibold)
    public static let symbol = Font.system(size: 15)
    public static func editor(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }
}

public struct GlassCapsule: View {
    public var height: CGFloat
    @Environment(\.colorScheme) private var scheme

    public init(height: CGFloat = CGFloat(WorkspaceChrome.toolbarItemHeight)) {
        self.height = height
    }

    public var body: some View {
        let c = ShellColors(scheme)
        Capsule(style: .continuous).fill(Color.clear)
            .overlay { Capsule(style: .continuous).stroke(c.capsuleStroke, lineWidth: 1) }
            .frame(height: height)
    }
}

public struct GlassSegments: View {
    public struct Segment {
        public var symbol: String
        public var help: String
        public var isOn: Bool
        public var isEnabled: Bool
        public var target: String
        public var action: () -> Void

        public init(symbol: String, help: String, isOn: Bool = false, isEnabled: Bool = true, target: String, action: @escaping () -> Void) {
            self.symbol = symbol
            self.help = help
            self.isOn = isOn
            self.isEnabled = isEnabled
            self.target = target
            self.action = action
        }
    }

    public var segments: [Segment]
    public var segmentWidth: CGFloat
    public var dividers: Bool
    public var symbolSize: CGFloat
    @Environment(\.colorScheme) private var scheme

    public init(segments: [Segment], segmentWidth: CGFloat = 30, dividers: Bool = true, symbolSize: CGFloat = 15) {
        self.segments = segments
        self.segmentWidth = segmentWidth
        self.dividers = dividers
        self.symbolSize = symbolSize
    }

    public var body: some View {
        let c = ShellColors(scheme)
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { pair in
                let s = pair.element
                if pair.offset > 0 && dividers {
                    Rectangle().fill(c.capsuleStroke).frame(width: 1, height: 18)
                }
                Button(action: s.action) {
                    ZStack {
                        if s.isOn { Capsule(style: .continuous).fill(c.segmentPill).frame(width: segmentWidth + 6, height: 28) }
                        Image(systemName: s.symbol)
                            .font(.system(size: symbolSize))
                            .foregroundStyle(s.isOn ? c.label : c.toolbarIcon)
                            .opacity(s.isEnabled ? 1 : 0.35)
                    }
                    .frame(width: segmentWidth + 6, height: CGFloat(WorkspaceChrome.toolbarItemHeight))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!s.isEnabled)
                .help(s.help)
                .accessibilityLabel(s.help)
                .shellTarget(s.target)
            }
        }
        .padding(.horizontal, 4)
        .background { GlassCapsule() }
    }
}

public struct GlassCircleButton: View {
    public var symbol: String
    public var help: String
    public var diameter: CGFloat
    public var isEnabled: Bool
    public var target: String
    public var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    public init(symbol: String, help: String, diameter: CGFloat = CGFloat(WorkspaceChrome.toolbarItemHeight), isEnabled: Bool = true, target: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.help = help
        self.diameter = diameter
        self.isEnabled = isEnabled
        self.target = target
        self.action = action
    }

    public var body: some View {
        let c = ShellColors(scheme)
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(c.toolbarIcon)
                .opacity(isEnabled ? 1 : 0.35)
                .frame(width: diameter, height: diameter)
                .background { Circle().stroke(c.capsuleStroke, lineWidth: 1) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(help)
        .accessibilityLabel(help)
        .shellTarget(target)
    }
}

public struct Hairline: View {
    public var color: Color
    public var vertical = false
    public init(color: Color, vertical: Bool = false) {
        self.color = color
        self.vertical = vertical
    }
    public var body: some View {
        Rectangle().fill(color).frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

public struct PopUpLook: View {
    public var title: String
    public var bold: Bool
    @Environment(\.colorScheme) private var scheme

    public init(title: String, bold: Bool = false) {
        self.title = title
        self.bold = bold
    }

    public var body: some View {
        let c = ShellColors(scheme)
        HStack(spacing: 4) {
            Text(verbatim: title).font(bold ? ShellFonts.smallBold : ShellFonts.small).tracking(ShellFonts.smallTracking).foregroundStyle(c.label).lineLimit(1)
            Spacer(minLength: 2)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(c.label)
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background { RoundedRectangle(cornerRadius: 5, style: .continuous).fill(c.popUpFill) }
    }
}

extension View {
    public func shellTarget(_ name: String) -> some View {
        accessibilityIdentifier(name)
    }
}

public struct ProblemBanner: View {
    public var message: String
    public var dismiss: () -> Void
    @Environment(\.colorScheme) private var scheme

    public init(message: String, dismiss: @escaping () -> Void = {}) {
        self.message = message
        self.dismiss = dismiss
    }

    public var body: some View {
        let c = ShellColors(scheme)
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(c.warning)
            Text(verbatim: message).font(ShellFonts.small).tracking(ShellFonts.smallTracking).foregroundStyle(c.label).lineLimit(2)
            Spacer(minLength: 4)
            Button(action: dismiss) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).foregroundStyle(c.secondaryLabel)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(c.warning.opacity(c.dark ? 0.18 : 0.14))
        .shellTarget("editor problem")
    }
}
