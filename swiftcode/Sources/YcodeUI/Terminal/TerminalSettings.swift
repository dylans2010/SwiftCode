import AppKit

public struct TerminalTheme: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isDark: Bool
    public let background: UInt32
    public let foreground: UInt32
    public let cursor: UInt32
    public let selection: UInt32
    public let ansi: [UInt32]

    public static let systemID = "system"

    public static let dark = TerminalTheme(
        id: "dark", name: "SwiftCode Dark", isDark: true, background: 0x1E1F22, foreground: 0xDFE1E5, cursor: 0xDFE1E5, selection: 0x3A5A8C,
        ansi: [0x1E1F22, 0xF0616D, 0x8FCF7B, 0xE8C06A, 0x6AA7F0, 0xC58AF0, 0x5FC9D8, 0xC9CCD3,
               0x6B6F78, 0xFF7B86, 0xA6E391, 0xF5D58A, 0x8ABDFF, 0xD9A6FF, 0x7FE0EC, 0xFFFFFF])
    public static let light = TerminalTheme(
        id: "light", name: "SwiftCode Light", isDark: false, background: 0xFFFFFF, foreground: 0x1F2328, cursor: 0x1F2328, selection: 0xB4D5FE,
        ansi: [0x1F2328, 0xC9302C, 0x1E7F34, 0x9A6700, 0x0B5FD3, 0x8250DF, 0x1B7C83, 0x6E7781,
               0x57606A, 0xE5484D, 0x2DA44E, 0xBF8700, 0x218BFF, 0xA475F9, 0x3192AA, 0x8C959F])
    public static let all: [TerminalTheme] = [
        dark, light,
        TerminalTheme(id: "midnight", name: "Midnight", isDark: true, background: 0x0F1219, foreground: 0xD8DEE9, cursor: 0x8FBCFF, selection: 0x2B3A55,
                      ansi: [0x1A1E29, 0xF7768E, 0x9ECE6A, 0xE0AF68, 0x7AA2F7, 0xBB9AF7, 0x7DCFFF, 0xA9B1D6,
                             0x414868, 0xF7768E, 0x9ECE6A, 0xE0AF68, 0x7AA2F7, 0xBB9AF7, 0x7DCFFF, 0xC0CAF5]),
        TerminalTheme(id: "monokai", name: "Monokai", isDark: true, background: 0x272822, foreground: 0xF8F8F2, cursor: 0xF8F8F0, selection: 0x49483E,
                      ansi: [0x272822, 0xF92672, 0xA6E22E, 0xF4BF75, 0x66D9EF, 0xAE81FF, 0xA1EFE4, 0xF8F8F2,
                             0x75715E, 0xF92672, 0xA6E22E, 0xF4BF75, 0x66D9EF, 0xAE81FF, 0xA1EFE4, 0xF9F8F5]),
        TerminalTheme(id: "dracula", name: "Dracula", isDark: true, background: 0x282A36, foreground: 0xF8F8F2, cursor: 0xF8F8F2, selection: 0x44475A,
                      ansi: [0x21222C, 0xFF5555, 0x50FA7B, 0xF1FA8C, 0xBD93F9, 0xFF79C6, 0x8BE9FD, 0xF8F8F2,
                             0x6272A4, 0xFF6E6E, 0x69FF94, 0xFFFFA5, 0xD6ACFF, 0xFF92DF, 0xA4FFFF, 0xFFFFFF]),
        TerminalTheme(id: "nord", name: "Nord", isDark: true, background: 0x2E3440, foreground: 0xD8DEE9, cursor: 0xD8DEE9, selection: 0x434C5E,
                      ansi: [0x3B4252, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x88C0D0, 0xE5E9F0,
                             0x4C566A, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x8FBCBB, 0xECEFF4]),
        TerminalTheme(id: "gruvbox", name: "Gruvbox Dark", isDark: true, background: 0x282828, foreground: 0xEBDBB2, cursor: 0xEBDBB2, selection: 0x504945,
                      ansi: [0x282828, 0xCC241D, 0x98971A, 0xD79921, 0x458588, 0xB16286, 0x689D6A, 0xA89984,
                             0x928374, 0xFB4934, 0xB8BB26, 0xFABD2F, 0x83A598, 0xD3869B, 0x8EC07C, 0xEBDBB2]),
        TerminalTheme(id: "onedark", name: "One Dark", isDark: true, background: 0x282C34, foreground: 0xABB2BF, cursor: 0x528BFF, selection: 0x3E4451,
                      ansi: [0x282C34, 0xE06C75, 0x98C379, 0xE5C07B, 0x61AFEF, 0xC678DD, 0x56B6C2, 0xABB2BF,
                             0x5C6370, 0xE06C75, 0x98C379, 0xE5C07B, 0x61AFEF, 0xC678DD, 0x56B6C2, 0xFFFFFF]),
        TerminalTheme(id: "solarized-dark", name: "Solarized Dark", isDark: true, background: 0x002B36, foreground: 0x839496, cursor: 0x93A1A1, selection: 0x073642,
                      ansi: [0x073642, 0xDC322F, 0x859900, 0xB58900, 0x268BD2, 0xD33682, 0x2AA198, 0xEEE8D5,
                             0x586E75, 0xCB4B16, 0x859900, 0xB58900, 0x268BD2, 0x6C71C4, 0x2AA198, 0xFDF6E3]),
        TerminalTheme(id: "solarized-light", name: "Solarized Light", isDark: false, background: 0xFDF6E3, foreground: 0x657B83, cursor: 0x586E75, selection: 0xEEE8D5,
                      ansi: [0x073642, 0xDC322F, 0x859900, 0xB58900, 0x268BD2, 0xD33682, 0x2AA198, 0xEEE8D5,
                             0x002B36, 0xCB4B16, 0x586E75, 0x657B83, 0x839496, 0x6C71C4, 0x93A1A1, 0xFDF6E3]),
    ]

    public static func theme(id: String, darkAppearance: Bool) -> TerminalTheme {
        all.first { $0.id == id } ?? (darkAppearance ? dark : light)
    }

    public func rgb(_ color: TerminalColor, foreground isForeground: Bool, bold: Bool = false) -> UInt32 {
        switch color {
        case .standard: return isForeground ? foreground : background
        case .rgb(let r, let g, let b): return UInt32(r) << 16 | UInt32(g) << 8 | UInt32(b)
        case .indexed(let i):
            if i < 16 { return ansi[Int(isForeground && bold && i < 8 ? i + 8 : i)] }
            if i < 232 {
                let n = Int(i) - 16
                let steps: [UInt32] = [0, 95, 135, 175, 215, 255]
                return steps[n / 36] << 16 | steps[(n / 6) % 6] << 8 | steps[n % 6]
            }
            let v = UInt32(8 + (Int(i) - 232) * 10)
            return v << 16 | v << 8 | v
        }
    }
}

public struct TerminalSnippet: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var command: String

    public init(name: String, command: String) {
        self.name = name
        self.command = command
    }
}

public struct TerminalSettings: Codable, Equatable, Sendable {
    public var themeID = TerminalTheme.systemID
    public var fontName = ""
    public var fontSize: Double = 12
    public var cursorShape = TerminalCursorShape.block
    public var cursorBlink = true
    public var optionAsMeta = false
    public var copyOnSelect = false
    public var audibleBell = false
    public var loginShell = true
    public var scrollbackLines = 10000
    public var shellPath = ""
    public var snippets: [TerminalSnippet] = []

    public static let didChange = Notification.Name("SwiftCodeTerminalSettingsDidChange")
    public static let defaultsKey = "SwiftCodeTerminalSettings"
    public static let fontSizeRange = 8.0...32.0

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TerminalSettings()
        themeID = try c.decodeIfPresent(String.self, forKey: .themeID) ?? d.themeID
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? d.fontName
        fontSize = min(max(try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? d.fontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        cursorShape = try c.decodeIfPresent(TerminalCursorShape.self, forKey: .cursorShape) ?? d.cursorShape
        cursorBlink = try c.decodeIfPresent(Bool.self, forKey: .cursorBlink) ?? d.cursorBlink
        optionAsMeta = try c.decodeIfPresent(Bool.self, forKey: .optionAsMeta) ?? d.optionAsMeta
        copyOnSelect = try c.decodeIfPresent(Bool.self, forKey: .copyOnSelect) ?? d.copyOnSelect
        audibleBell = try c.decodeIfPresent(Bool.self, forKey: .audibleBell) ?? d.audibleBell
        loginShell = try c.decodeIfPresent(Bool.self, forKey: .loginShell) ?? d.loginShell
        scrollbackLines = max(0, try c.decodeIfPresent(Int.self, forKey: .scrollbackLines) ?? d.scrollbackLines)
        shellPath = try c.decodeIfPresent(String.self, forKey: .shellPath) ?? d.shellPath
        snippets = try c.decodeIfPresent([TerminalSnippet].self, forKey: .snippets) ?? []
    }

    public static func load(_ defaults: UserDefaults = .standard) -> TerminalSettings {
        guard let data = defaults.data(forKey: defaultsKey), let s = try? JSONDecoder().decode(TerminalSettings.self, from: data) else {
            return TerminalSettings()
        }
        return s
    }

    @MainActor
    public func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.defaultsKey) }
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    public var resolvedShell: String {
        !shellPath.isEmpty && FileManager.default.isExecutableFile(atPath: shellPath) ? shellPath : PseudoTerminalProcess.defaultShell()
    }

    @MainActor
    public var font: NSFont {
        let size = CGFloat(fontSize)
        if !fontName.isEmpty, let f = NSFont(name: fontName, size: size), f.isFixedPitch { return f }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

public enum TerminalProjectCommands {
    public static func suggestions(in folder: URL?) -> [TerminalSnippet] {
        guard let folder else { return [] }
        let fm = FileManager.default
        func has(_ name: String) -> Bool { fm.fileExists(atPath: folder.appendingPathComponent(name).path) }
        var out: [TerminalSnippet] = []
        if has("Package.swift") {
            out += [.init(name: "swift build", command: "swift build"), .init(name: "swift test", command: "swift test"),
                    .init(name: "swift package resolve", command: "swift package resolve"),
                    .init(name: "swift package update", command: "swift package update")]
        }
        let names = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        if let project = names.sorted().first(where: { $0.hasSuffix(".xcodeproj") }) {
            out.append(.init(name: "xcodebuild -list", command: "xcodebuild -list -project \(quote(project))"))
        }
        if has(".git") {
            out += [.init(name: "git status", command: "git status"), .init(name: "git log (last 20)", command: "git log --oneline --graph -20"),
                    .init(name: "git diff --stat", command: "git diff --stat"), .init(name: "git fetch", command: "git fetch --all --prune")]
        }
        if has("package.json") {
            out += [.init(name: "npm install", command: "npm install"), .init(name: "npm test", command: "npm test")]
        }
        if has("Cargo.toml") {
            out += [.init(name: "cargo build", command: "cargo build"), .init(name: "cargo test", command: "cargo test")]
        }
        if has("Makefile") { out.append(.init(name: "make", command: "make")) }
        if has("Podfile") { out.append(.init(name: "pod install", command: "pod install")) }
        return out
    }

    public static func quote(_ s: String) -> String {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./:@%+=,")
        if !s.isEmpty, s.unicodeScalars.allSatisfy(safe.contains) { return s }
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
