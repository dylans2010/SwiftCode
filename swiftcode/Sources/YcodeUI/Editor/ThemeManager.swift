import SwiftUI
import Foundation

public struct ThemeColors: Codable, Equatable, Sendable {
    public var background: String
    public var editorText: String
    public var syntaxKeyword: String
    public var syntaxString: String
    public var syntaxComment: String
    public var syntaxType: String
    public var syntaxNumber: String
    public var syntaxFunction: String
    public var accent: String
    public var toolbar: String
    public var panelBackground: String
    public var selection: String
    public var lineHighlight: String
    public var cursor: String
    public var fontName: String
    public var fontSize: Double

    public init(
        background: String,
        editorText: String,
        syntaxKeyword: String,
        syntaxString: String,
        syntaxComment: String,
        syntaxType: String,
        syntaxNumber: String? = nil,
        syntaxFunction: String? = nil,
        accent: String,
        toolbar: String,
        panelBackground: String,
        selection: String? = nil,
        lineHighlight: String? = nil,
        cursor: String? = nil,
        fontName: String = "SF Mono",
        fontSize: Double = 12
    ) {
        self.background = background
        self.editorText = editorText
        self.syntaxKeyword = syntaxKeyword
        self.syntaxString = syntaxString
        self.syntaxComment = syntaxComment
        self.syntaxType = syntaxType
        self.syntaxNumber = syntaxNumber ?? syntaxKeyword
        self.syntaxFunction = syntaxFunction ?? accent
        self.accent = accent
        self.toolbar = toolbar
        self.panelBackground = panelBackground
        self.selection = selection ?? accent
        self.lineHighlight = lineHighlight ?? panelBackground
        self.cursor = cursor ?? accent
        self.fontName = fontName
        self.fontSize = fontSize
    }

    
    
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        background = try c.decodeIfPresent(String.self, forKey: .background) ?? "#FFFFFF"
        editorText = try c.decodeIfPresent(String.self, forKey: .editorText) ?? "#000000"
        syntaxKeyword = try c.decodeIfPresent(String.self, forKey: .syntaxKeyword) ?? "#0000FF"
        syntaxString = try c.decodeIfPresent(String.self, forKey: .syntaxString) ?? "#A31515"
        syntaxComment = try c.decodeIfPresent(String.self, forKey: .syntaxComment) ?? "#008000"
        syntaxType = try c.decodeIfPresent(String.self, forKey: .syntaxType) ?? "#267F99"
        syntaxNumber = try c.decodeIfPresent(String.self, forKey: .syntaxNumber) ?? syntaxKeyword
        accent = try c.decodeIfPresent(String.self, forKey: .accent) ?? "#007AFF"
        syntaxFunction = try c.decodeIfPresent(String.self, forKey: .syntaxFunction) ?? accent
        toolbar = try c.decodeIfPresent(String.self, forKey: .toolbar) ?? "#F2F2F7"
        panelBackground = try c.decodeIfPresent(String.self, forKey: .panelBackground) ?? "#F5F5F5"
        selection = try c.decodeIfPresent(String.self, forKey: .selection) ?? accent
        lineHighlight = try c.decodeIfPresent(String.self, forKey: .lineHighlight) ?? panelBackground
        cursor = try c.decodeIfPresent(String.self, forKey: .cursor) ?? accent
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? "SF Mono"
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 12
    }
}

public struct AppTheme: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var isBuiltIn: Bool
    public var colors: ThemeColors

    public init(id: String, name: String, isBuiltIn: Bool, colors: ThemeColors) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.colors = colors
    }

    
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        colors = try c.decode(ThemeColors.self, forKey: .colors)
    }

    
    static func p(_ id: String, _ name: String, _ bg: String, _ fg: String, _ kw: String, _ str: String,
                  _ com: String, _ typ: String, _ num: String, _ acc: String, _ tool: String, _ panel: String) -> AppTheme {
        AppTheme(id: id, name: name, isBuiltIn: true,
                 colors: ThemeColors(background: bg, editorText: fg, syntaxKeyword: kw, syntaxString: str,
                                     syntaxComment: com, syntaxType: typ, syntaxNumber: num, syntaxFunction: acc,
                                     accent: acc, toolbar: tool, panelBackground: panel,
                                     fontName: "SF Mono", fontSize: 12))
    }

    public static let light = AppTheme(
        id: "light", name: "Light", isBuiltIn: true,
        colors: ThemeColors(
            background: "#FFFFFF", editorText: "#000000",
            syntaxKeyword: "#AD3DA4", syntaxString: "#C41A16",
            syntaxComment: "#007400", syntaxType: "#3900A0",
            accent: "#007AFF", toolbar: "#F2F2F7", panelBackground: "#F5F5F5"
        )
    )
    public static let dark = AppTheme(
        id: "dark", name: "Dark", isBuiltIn: true,
        colors: ThemeColors(
            background: "#1A1A2E", editorText: "#DCDCDC",
            syntaxKeyword: "#FC5FA3", syntaxString: "#FC6A5D",
            syntaxComment: "#6C7986", syntaxType: "#5DD8FF",
            accent: "#FF9500", toolbar: "#1C1C1E", panelBackground: "#242430"
        )
    )
    public static let monokai = AppTheme(
        id: "monokai", name: "Monokai", isBuiltIn: true,
        colors: ThemeColors(
            background: "#272822", editorText: "#F8F8F2",
            syntaxKeyword: "#F92672", syntaxString: "#E6DB74",
            syntaxComment: "#75715E", syntaxType: "#66D9EF",
            accent: "#A6E22E", toolbar: "#1E1F1C", panelBackground: "#3E3D32"
        )
    )
    public static let dracula = AppTheme(
        id: "dracula", name: "Dracula", isBuiltIn: true,
        colors: ThemeColors(
            background: "#282A36", editorText: "#F8F8F2",
            syntaxKeyword: "#FF79C6", syntaxString: "#F1FA8C",
            syntaxComment: "#6272A4", syntaxType: "#8BE9FD",
            accent: "#BD93F9", toolbar: "#21222C", panelBackground: "#343746"
        )
    )
    public static let oneDark = AppTheme(
        id: "one_dark", name: "One Dark", isBuiltIn: true,
        colors: ThemeColors(
            background: "#282C34", editorText: "#ABB2BF",
            syntaxKeyword: "#C678DD", syntaxString: "#98C379",
            syntaxComment: "#5C6370", syntaxType: "#61AFEF",
            accent: "#E06C75", toolbar: "#21252B", panelBackground: "#2C313A"
        )
    )
    public static let solarized = AppTheme(
        id: "solarized", name: "Solarized Dark", isBuiltIn: true,
        colors: ThemeColors(
            background: "#002B36", editorText: "#839496",
            syntaxKeyword: "#859900", syntaxString: "#2AA198",
            syntaxComment: "#586E75", syntaxType: "#268BD2",
            accent: "#B58900", toolbar: "#073642", panelBackground: "#073642"
        )
    )

    public static let tokyoNight = AppTheme(
        id: "tokyo_night", name: "Tokyo Night", isBuiltIn: true,
        colors: ThemeColors(background: "#1A1B26", editorText: "#C0CAF5", syntaxKeyword: "#BB9AF7", syntaxString: "#9ECE6A", syntaxComment: "#565F89", syntaxType: "#7AA2F7", accent: "#7AA2F7", toolbar: "#16161E", panelBackground: "#24283B", fontName: "SF Mono", fontSize: 12)
    )
    public static let gruvbox = AppTheme(
        id: "gruvbox", name: "Gruvbox Dark", isBuiltIn: true,
        colors: ThemeColors(background: "#282828", editorText: "#EBDBB2", syntaxKeyword: "#FB4934", syntaxString: "#B8BB26", syntaxComment: "#928374", syntaxType: "#83A598", accent: "#FABD2F", toolbar: "#1D2021", panelBackground: "#3C3836", fontName: "SF Mono", fontSize: 12)
    )
    public static let nord = AppTheme(
        id: "nord", name: "Nord", isBuiltIn: true,
        colors: ThemeColors(background: "#2E3440", editorText: "#D8DEE9", syntaxKeyword: "#81A1C1", syntaxString: "#A3BE8C", syntaxComment: "#4C566A", syntaxType: "#88C0D0", accent: "#88C0D0", toolbar: "#242933", panelBackground: "#3B4252", fontName: "SF Mono", fontSize: 12)
    )
    public static let catppuccin = AppTheme(
        id: "catppuccin", name: "Catppuccin Mocha", isBuiltIn: true,
        colors: ThemeColors(background: "#1E1E2E", editorText: "#CDD6F4", syntaxKeyword: "#CBA6F7", syntaxString: "#A6E3A1", syntaxComment: "#6C7086", syntaxType: "#89DCEB", accent: "#F5C2E7", toolbar: "#181825", panelBackground: "#313244", fontName: "SF Mono", fontSize: 12)
    )
    public static let githubLight = AppTheme(
        id: "github_light", name: "GitHub Light", isBuiltIn: true,
        colors: ThemeColors(background: "#FFFFFF", editorText: "#24292F", syntaxKeyword: "#CF222E", syntaxString: "#0A3069", syntaxComment: "#6E7781", syntaxType: "#0550AE", accent: "#0969DA", toolbar: "#F6F8FA", panelBackground: "#EAEEF2", fontName: "SF Mono", fontSize: 12)
    )
    public static let xcodeDefault = AppTheme(
        id: "xcode_default", name: "Xcode Default", isBuiltIn: true,
        colors: ThemeColors(background: "#FFFFFF", editorText: "#000000", syntaxKeyword: "#AD3DA4", syntaxString: "#C41A16", syntaxComment: "#007400", syntaxType: "#3900A0", accent: "#007AFF", toolbar: "#F2F2F7", panelBackground: "#F5F5F5", fontName: "SF Mono", fontSize: 12)
    )
    public static let ayuDark = AppTheme(
        id: "ayu_dark", name: "Ayu Dark", isBuiltIn: true,
        colors: ThemeColors(background: "#0B0E14", editorText: "#BFBDB6", syntaxKeyword: "#FF8F40", syntaxString: "#AAD94C", syntaxComment: "#626A73", syntaxType: "#39BAE6", accent: "#FFB454", toolbar: "#0B0E14", panelBackground: "#11151C", fontName: "SF Mono", fontSize: 12)
    )
    public static let nightOwl = AppTheme(
        id: "night_owl", name: "Night Owl", isBuiltIn: true,
        colors: ThemeColors(background: "#011627", editorText: "#D6DEEB", syntaxKeyword: "#C792EA", syntaxString: "#ADDB67", syntaxComment: "#637777", syntaxType: "#82AAFF", accent: "#7FDBCA", toolbar: "#01111D", panelBackground: "#0B253A", fontName: "SF Mono", fontSize: 12)
    )
    public static let palenight = AppTheme(
        id: "palenight", name: "Palenight", isBuiltIn: true,
        colors: ThemeColors(background: "#292D3E", editorText: "#A6ACCD", syntaxKeyword: "#C792EA", syntaxString: "#C3E88D", syntaxComment: "#676E95", syntaxType: "#82AAFF", accent: "#FFCB6B", toolbar: "#202331", panelBackground: "#32374D", fontName: "SF Mono", fontSize: 12)
    )
    public static let cobalt2 = AppTheme(
        id: "cobalt2", name: "Cobalt2", isBuiltIn: true,
        colors: ThemeColors(background: "#193549", editorText: "#FFFFFF", syntaxKeyword: "#FF9E64", syntaxString: "#9CCC65", syntaxComment: "#7587A6", syntaxType: "#FFC600", accent: "#FFC600", toolbar: "#122738", panelBackground: "#1F4662", fontName: "SF Mono", fontSize: 12)
    )
    public static let synthwave = AppTheme(
        id: "synthwave", name: "SynthWave '84", isBuiltIn: true,
        colors: ThemeColors(background: "#262335", editorText: "#FFFFFF", syntaxKeyword: "#FF7EDB", syntaxString: "#FEDE5D", syntaxComment: "#6A6A87", syntaxType: "#36F9F6", accent: "#F92AAD", toolbar: "#1A1626", panelBackground: "#34294F", fontName: "SF Mono", fontSize: 12)
    )
    public static let highContrast = AppTheme(
        id: "high_contrast", name: "High Contrast", isBuiltIn: true,
        colors: ThemeColors(background: "#000000", editorText: "#FFFFFF", syntaxKeyword: "#FFFF00", syntaxString: "#00FF00", syntaxComment: "#808080", syntaxType: "#00FFFF", accent: "#FFFF00", toolbar: "#000000", panelBackground: "#1A1A1A", fontName: "SF Mono", fontSize: 13)
    )
    public static let sepia = AppTheme(
        id: "sepia", name: "Sepia", isBuiltIn: true,
        colors: ThemeColors(background: "#F4ECD8", editorText: "#433422", syntaxKeyword: "#8B4513", syntaxString: "#2E7D32", syntaxComment: "#9C8E7C", syntaxType: "#1565C0", accent: "#8B4513", toolbar: "#EDE3C8", panelBackground: "#E8DCC0", fontName: "SF Mono", fontSize: 12)
    )
    public static let midnight = AppTheme(
        id: "midnight", name: "Midnight Blue", isBuiltIn: true,
        colors: ThemeColors(background: "#0F172A", editorText: "#E2E8F0", syntaxKeyword: "#C084FC", syntaxString: "#86EFAC", syntaxComment: "#64748B", syntaxType: "#7DD3FC", accent: "#38BDF8", toolbar: "#020617", panelBackground: "#1E293B", fontName: "SF Mono", fontSize: 12)
    )
    public static let rosePine = AppTheme(
        id: "rose_pine", name: "Rosé Pine", isBuiltIn: true,
        colors: ThemeColors(background: "#191724", editorText: "#E0DEF4", syntaxKeyword: "#C4A7E7", syntaxString: "#9CCFD8", syntaxComment: "#6E6A86", syntaxType: "#9CCFD8", accent: "#EBBCBA", toolbar: "#1F1D2E", panelBackground: "#26233A", fontName: "SF Mono", fontSize: 12)
    )
    public static let everforest = AppTheme(
        id: "everforest", name: "Everforest", isBuiltIn: true,
        colors: ThemeColors(background: "#2D353B", editorText: "#D3C6AA", syntaxKeyword: "#E67E80", syntaxString: "#A7C080", syntaxComment: "#859289", syntaxType: "#7FBBB3", accent: "#DBBC7F", toolbar: "#232A2E", panelBackground: "#343F44", fontName: "SF Mono", fontSize: 12)
    )
    public static let kanagawa = AppTheme(
        id: "kanagawa", name: "Kanagawa", isBuiltIn: true,
        colors: ThemeColors(background: "#1F1F28", editorText: "#DCD7BA", syntaxKeyword: "#957FB8", syntaxString: "#98BB6C", syntaxComment: "#727169", syntaxType: "#7E9CD8", accent: "#FFA066", toolbar: "#1A1A22", panelBackground: "#2A2A37", fontName: "SF Mono", fontSize: 12)
    )

    public static let xcodeDark = AppTheme(
        id: "xcode_dark", name: "Xcode Dark", isBuiltIn: true,
        colors: ThemeColors(
            background: "#1F2024", editorText: "#DFDFDF",
            syntaxKeyword: "#FC5FA3", syntaxString: "#FC6A5D",
            syntaxComment: "#6C7986", syntaxType: "#5DD8FF",
            syntaxNumber: "#D0BF69", syntaxFunction: "#A167E6",
            accent: "#007AFF", toolbar: "#18191D", panelBackground: "#24252A"
        )
    )
    public static let xcodeLight = AppTheme(
        id: "xcode_light", name: "Xcode Light", isBuiltIn: true,
        colors: ThemeColors(
            background: "#FFFFFF", editorText: "#000000",
            syntaxKeyword: "#AD3DA4", syntaxString: "#C41A16",
            syntaxComment: "#707F8C", syntaxType: "#4B21B0",
            syntaxNumber: "#1C00CF", syntaxFunction: "#326D78",
            accent: "#007AFF", toolbar: "#F2F2F7", panelBackground: "#F6F6F6"
        )
    )
    public static let midnightPurple = AppTheme(
        id: "midnight_purple", name: "Midnight Purple", isBuiltIn: true,
        colors: ThemeColors(
            background: "#130A2A", editorText: "#E0D7F5",
            syntaxKeyword: "#C084FC", syntaxString: "#F472B6",
            syntaxComment: "#7E6B9B", syntaxType: "#818CF8",
            syntaxNumber: "#FDE047", syntaxFunction: "#E879F9",
            accent: "#A855F7", toolbar: "#0E0720", panelBackground: "#1D113A"
        )
    )
    public static let cyberpunk = AppTheme(
        id: "cyberpunk", name: "Cyberpunk", isBuiltIn: true,
        colors: ThemeColors(
            background: "#120B1F", editorText: "#EAEAEA",
            syntaxKeyword: "#FF007F", syntaxString: "#FFE600",
            syntaxComment: "#716585", syntaxType: "#00F0FF",
            syntaxNumber: "#00FF9F", syntaxFunction: "#FF2A85",
            accent: "#00F0FF", toolbar: "#0A0512", panelBackground: "#1B0F2E"
        )
    )
    public static let solarizedDark = AppTheme(
        id: "solarized_dark", name: "Solarized Dark", isBuiltIn: true,
        colors: ThemeColors(
            background: "#002B36", editorText: "#839496",
            syntaxKeyword: "#859900", syntaxString: "#2AA198",
            syntaxComment: "#586E75", syntaxType: "#268BD2",
            syntaxNumber: "#D33682", syntaxFunction: "#B58900",
            accent: "#B58900", toolbar: "#073642", panelBackground: "#073642"
        )
    )
    public static let solarizedLight = AppTheme(
        id: "solarized_light", name: "Solarized Light", isBuiltIn: true,
        colors: ThemeColors(
            background: "#FDF6E3", editorText: "#657B83",
            syntaxKeyword: "#859900", syntaxString: "#2AA198",
            syntaxComment: "#93A1A1", syntaxType: "#268BD2",
            syntaxNumber: "#D33682", syntaxFunction: "#B58900",
            accent: "#B58900", toolbar: "#EEE8D5", panelBackground: "#F5EFDC"
        )
    )
    public static let monokaiPro = AppTheme(
        id: "monokai_pro", name: "Monokai Pro", isBuiltIn: true,
        colors: ThemeColors(
            background: "#2D2A2E", editorText: "#FCFCFA",
            syntaxKeyword: "#FF6188", syntaxString: "#FFD866",
            syntaxComment: "#727072", syntaxType: "#78DCE8",
            syntaxNumber: "#AB9DF2", syntaxFunction: "#A9DC76",
            accent: "#A9DC76", toolbar: "#221F22", panelBackground: "#3A363B"
        )
    )
    public static let synthwave84 = AppTheme(
        id: "synthwave_84", name: "Synthwave '84", isBuiltIn: true,
        colors: ThemeColors(
            background: "#262335", editorText: "#FFFFFF",
            syntaxKeyword: "#FF7EDB", syntaxString: "#FEDE5D",
            syntaxComment: "#6A6A87", syntaxType: "#36F9F6",
            syntaxNumber: "#F97E72", syntaxFunction: "#36F9F6",
            accent: "#F92AAD", toolbar: "#1A1626", panelBackground: "#34294F"
        )
    )
    public static let catppuccinMocha = AppTheme(
        id: "catppuccin_mocha", name: "Catppuccin Mocha", isBuiltIn: true,
        colors: ThemeColors(
            background: "#1E1E2E", editorText: "#CDD6F4",
            syntaxKeyword: "#CBA6F7", syntaxString: "#A6E3A1",
            syntaxComment: "#6C7086", syntaxType: "#89DCEB",
            syntaxNumber: "#FAB387", syntaxFunction: "#89B4FA",
            accent: "#F5C2E7", toolbar: "#181825", panelBackground: "#313244"
        )
    )
    public static let catppuccinLatte = AppTheme(
        id: "catppuccin_latte", name: "Catppuccin Latte", isBuiltIn: true,
        colors: ThemeColors(
            background: "#EFF1F5", editorText: "#4C4F69",
            syntaxKeyword: "#8839EF", syntaxString: "#40A02B",
            syntaxComment: "#9CA0B0", syntaxType: "#1E66F5",
            syntaxNumber: "#FE640B", syntaxFunction: "#04A5E5",
            accent: "#EA76CB", toolbar: "#E6E9EF", panelBackground: "#DCE0E8"
        )
    )
    public static let forest = AppTheme(
        id: "forest", name: "Forest", isBuiltIn: true,
        colors: ThemeColors(
            background: "#1B2B23", editorText: "#D8E6DF",
            syntaxKeyword: "#87D37C", syntaxString: "#F5D76E",
            syntaxComment: "#5D7D6D", syntaxType: "#4ECDC4",
            syntaxNumber: "#E67E22", syntaxFunction: "#2ECC71",
            accent: "#2ECC71", toolbar: "#14211B", panelBackground: "#23372D"
        )
    )
    public static let cobalt = AppTheme(
        id: "cobalt", name: "Cobalt", isBuiltIn: true,
        colors: ThemeColors(
            background: "#193549", editorText: "#E1EFFF",
            syntaxKeyword: "#FF9D00", syntaxString: "#3AD900",
            syntaxComment: "#0088FF", syntaxType: "#80FFBB",
            syntaxNumber: "#FF628C", syntaxFunction: "#FFEE80",
            accent: "#FFC600", toolbar: "#132737", panelBackground: "#1F435D"
        )
    )
    public static let gruvboxDark = AppTheme(
        id: "gruvbox_dark", name: "Gruvbox Dark", isBuiltIn: true,
        colors: ThemeColors(background: "#282828", editorText: "#EBDBB2", syntaxKeyword: "#FB4934", syntaxString: "#B8BB26", syntaxComment: "#928374", syntaxType: "#83A598", accent: "#FABD2F", toolbar: "#1D2021", panelBackground: "#3C3836", fontName: "SF Mono", fontSize: 12)
    )
    public static let githubDark = AppTheme(
        id: "github_dark", name: "GitHub Dark", isBuiltIn: true,
        colors: ThemeColors(background: "#0D1117", editorText: "#E6EDF3", syntaxKeyword: "#FF7B72", syntaxString: "#A5D6FF", syntaxComment: "#8B949E", syntaxType: "#79C0FF", syntaxNumber: "#79C0FF", syntaxFunction: "#D2A8FF", accent: "#2F81F7", toolbar: "#161B22", panelBackground: "#161B22", selection: "#264F78", lineHighlight: "#161B22", cursor: "#E6EDF3", fontName: "SF Mono", fontSize: 12)
    )
    public static let gruvboxLight = AppTheme(
        id: "gruvbox_light", name: "Gruvbox Light", isBuiltIn: true,
        colors: ThemeColors(background: "#FBF1C7", editorText: "#3C3836", syntaxKeyword: "#9D0006", syntaxString: "#79740E", syntaxComment: "#928374", syntaxType: "#076678", syntaxNumber: "#8F3F71", syntaxFunction: "#427B58", accent: "#AF3A03", toolbar: "#EBDBB2", panelBackground: "#F2E5BC", selection: "#D5C4A1", lineHighlight: "#F2E5BC", cursor: "#3C3836", fontName: "SF Mono", fontSize: 12)
    )
    public static let oneLight = AppTheme(
        id: "one_light", name: "One Light", isBuiltIn: true,
        colors: ThemeColors(background: "#FAFAFA", editorText: "#383A42", syntaxKeyword: "#A626A4", syntaxString: "#50A14F", syntaxComment: "#A0A1A7", syntaxType: "#C18401", syntaxNumber: "#B76B01", syntaxFunction: "#4078F2", accent: "#4078F2", toolbar: "#F0F0F0", panelBackground: "#EDEDED", selection: "#D3E0F0", lineHighlight: "#F0F0F0", cursor: "#383A42", fontName: "SF Mono", fontSize: 12)
    )
    public static let ayuLight = AppTheme(
        id: "ayu_light", name: "Ayu Light", isBuiltIn: true,
        colors: ThemeColors(background: "#FAFAFA", editorText: "#5C6773", syntaxKeyword: "#F29718", syntaxString: "#86B300", syntaxComment: "#ABB0BF", syntaxType: "#399EE6", syntaxNumber: "#FF9940", syntaxFunction: "#F29718", accent: "#FF9940", toolbar: "#F3F4F5", panelBackground: "#EDEEF0", selection: "#FFE8C2", lineHighlight: "#F0F1F2", cursor: "#FF9940", fontName: "SF Mono", fontSize: 12)
    )
    public static let ayuMirage = AppTheme(
        id: "ayu_mirage", name: "Ayu Mirage", isBuiltIn: true,
        colors: ThemeColors(background: "#1F2430", editorText: "#CBCCC6", syntaxKeyword: "#FFA759", syntaxString: "#BAE67E", syntaxComment: "#5C6773", syntaxType: "#73D0FF", syntaxNumber: "#FFD580", syntaxFunction: "#FFD580", accent: "#FFCC66", toolbar: "#1A1F2B", panelBackground: "#232834", selection: "#33415E", lineHighlight: "#232834", cursor: "#FFCC66", fontName: "SF Mono", fontSize: 12)
    )
    public static let tokyoNightDay = AppTheme(
        id: "tokyo_night_day", name: "Tokyo Night Day", isBuiltIn: true,
        colors: ThemeColors(background: "#E1E2E7", editorText: "#3760BF", syntaxKeyword: "#9854F1", syntaxString: "#587539", syntaxComment: "#848CB5", syntaxType: "#2E7DE9", syntaxNumber: "#B15C00", syntaxFunction: "#2E7DE9", accent: "#2E7DE9", toolbar: "#D8DAE2", panelBackground: "#DDE0E8", selection: "#C0CAF5", lineHighlight: "#DDE0E8", cursor: "#3760BF", fontName: "SF Mono", fontSize: 12)
    )
    public static let rosePineMoon = AppTheme(
        id: "rose_pine_moon", name: "Rosé Pine Moon", isBuiltIn: true,
        colors: ThemeColors(background: "#232136", editorText: "#E0DEF4", syntaxKeyword: "#C4A7E7", syntaxString: "#9CCFD8", syntaxComment: "#6E6A86", syntaxType: "#9CCFD8", syntaxNumber: "#F6C177", syntaxFunction: "#EBBCBA", accent: "#EA9A97", toolbar: "#1F1D2E", panelBackground: "#2A273F", selection: "#44415A", lineHighlight: "#2A273F", cursor: "#E0DEF4", fontName: "SF Mono", fontSize: 12)
    )
    public static let rosePineDawn = AppTheme(
        id: "rose_pine_dawn", name: "Rosé Pine Dawn", isBuiltIn: true,
        colors: ThemeColors(background: "#FAF4ED", editorText: "#575279", syntaxKeyword: "#907AA9", syntaxString: "#56949F", syntaxComment: "#9893A5", syntaxType: "#286983", syntaxNumber: "#EA9D34", syntaxFunction: "#D7827E", accent: "#D7827E", toolbar: "#F2E9E1", panelBackground: "#F2E9DE", selection: "#E5D5CB", lineHighlight: "#F2E9E1", cursor: "#575279", fontName: "SF Mono", fontSize: 12)
    )
    public static let catppuccinFrappe = AppTheme(
        id: "catppuccin_frappe", name: "Catppuccin Frappé", isBuiltIn: true,
        colors: ThemeColors(background: "#303446", editorText: "#C6D0F5", syntaxKeyword: "#CA9EE6", syntaxString: "#A6D189", syntaxComment: "#737994", syntaxType: "#85C1DC", syntaxNumber: "#EF9F76", syntaxFunction: "#8CAAEE", accent: "#F4B8E4", toolbar: "#292C3C", panelBackground: "#414559", selection: "#51576D", lineHighlight: "#414559", cursor: "#F4B8E4", fontName: "SF Mono", fontSize: 12)
    )
    public static let catppuccinMacchiato = AppTheme(
        id: "catppuccin_macchiato", name: "Catppuccin Macchiato", isBuiltIn: true,
        colors: ThemeColors(background: "#24273A", editorText: "#CAD3F5", syntaxKeyword: "#C6A0F6", syntaxString: "#A6DA95", syntaxComment: "#5B6078", syntaxType: "#8BD5CA", syntaxNumber: "#F5A97F", syntaxFunction: "#8AADF4", accent: "#F5BDE6", toolbar: "#1E2030", panelBackground: "#363A4F", selection: "#494D64", lineHighlight: "#363A4F", cursor: "#F5BDE6", fontName: "SF Mono", fontSize: 12)
    )

    public static let githubDimmed = p("github_dimmed", "GitHub Dark Dimmed", "#22272E", "#ADBAC7", "#F47067", "#96D0FF", "#768390", "#F47067", "#F69D50", "#D2A8FF", "#1C2127", "#2D333B")
    public static let githubLightHC = p("github_light_hc", "GitHub Light High Contrast", "#FFFFFF", "#000000", "#8250DF", "#0A3069", "#57606A", "#8250DF", "#0550AE", "#0969DA", "#F6F8FA", "#EAEEF2")
    public static let tokyoStorm = p("tokyo_storm", "Tokyo Night Storm", "#24283B", "#C0CAF5", "#BB9AF7", "#9ECE6A", "#545C7E", "#7AA2F7", "#FF9E64", "#7DCFFF", "#1F2335", "#2F344D")
    public static let oneDarkPro = p("one_dark_pro", "One Dark Pro", "#282C34", "#ABB2BF", "#C678DD", "#98C379", "#7F848E", "#E06C75", "#D19A66", "#61AFEF", "#21252B", "#2C313A")
    public static let nightfox = p("nightfox", "Nightfox", "#192330", "#D1D6C9", "#C793C9", "#99C794", "#566276", "#7AA2F7", "#E0AF68", "#FF9E64", "#141C27", "#212B3A")
    public static let oceanicNext = p("oceanic_next", "Oceanic Next", "#1B2B34", "#D8DEE9", "#B48EAD", "#99C794", "#65737E", "#8FA1B3", "#D08770", "#EC5F67", "#14232B", "#223440")
    public static let poimandres = p("poimandres", "Poimandres", "#1B1E28", "#CDD6F4", "#C792EA", "#C3E88D", "#51576D", "#89B4FA", "#F5C2E7", "#89B4FA", "#161821", "#262B3A")
    public static let darkPlus = p("dark_plus", "Dark+", "#1E1E1E", "#D4D4D4", "#569CD6", "#CE9178", "#6A9955", "#4EC9B0", "#B5CEA8", "#9CDCFE", "#181818", "#2A2D2E")
    public static let andromeeda = p("andromeeda", "Andromeeda", "#232A2E", "#D6DBE5", "#F670D0", "#99C794", "#7A8699", "#82AAFF", "#F78C6C", "#7FDBCA", "#1C2226", "#2B343A")
    public static let aurora = p("aurora", "Aurora", "#1E1B24", "#E6E6E6", "#FFB86C", "#A8CC7C", "#7E6F8E", "#82AAFF", "#FFCB6B", "#7FDBCA", "#181520", "#282230")
    public static let buffer = p("buffer", "Buffer", "#282A2B", "#EFF1F5", "#CC99CD", "#65C184", "#505862", "#67B7A4", "#F99157", "#67B7A4", "#1F2122", "#2F3338")
    public static let brogrammer = p("brogrammer", "Brogrammer", "#0C101C", "#FFFFFF", "#C586C0", "#CE9178", "#6A9955", "#4EC9B0", "#D7BA7D", "#9CDCFE", "#080B14", "#10182B")
    public static let darkside = p("darkside", "Darkside", "#282A36", "#FFFFFF", "#FF757F", "#F1FA8C", "#6272A4", "#8BE9FD", "#BD93F9", "#8BE9FD", "#21222C", "#343746")
    public static let edge = p("edge", "Edge", "#1A1B22", "#ABB2BF", "#C678DD", "#98C379", "#5C6370", "#56B6C2", "#D19A66", "#61AFEF", "#141519", "#22242C")
    public static let flexoki = p("flexoki", "Flexoki", "#100F0F", "#D0C8C0", "#E67E80", "#A7C080", "#6E6A60", "#7FA6C9", "#D0BF8F", "#7FA6C9", "#0A0909", "#1C1B19")
    public static let hacker = p("hacker", "Hacker", "#000000", "#FFFFFF", "#00FF00", "#00FF00", "#555555", "#00FF00", "#00FFFF", "#00FF00", "#000000", "#0A0A0A")
    public static let irBlack = p("ir_black", "IR Black", "#000000", "#F8F8F8", "#569CD6", "#CE9178", "#6A9955", "#4EC9B0", "#B5CEA8", "#9CDCFE", "#000000", "#141414")
    public static let jack = p("jack", "Jack", "#000000", "#FFFFFF", "#FFFFFF", "#FFFF00", "#FF0000", "#FFFFFF", "#FFFFFF", "#00FFFF", "#000000", "#0D0D0D")
    public static let kale = p("kale", "Kale", "#031A16", "#E4F0EA", "#7FDBCA", "#FDE047", "#406353", "#82AAFF", "#FB8C00", "#82AAFF", "#02120E", "#07241E")
    public static let macClassic = p("mac_classic", "Mac Classic", "#FFFFFF", "#000000", "#0000FF", "#FF0000", "#008000", "#000080", "#FF00FF", "#800080", "#FFFFFF", "#EDEDED")
    public static let mariana = p("mariana", "Mariana", "#0F1419", "#D8DEE9", "#C792EA", "#C3E88D", "#546E7A", "#82AAFF", "#F78C6C", "#7FDBCA", "#0A0E13", "#161D24")
    public static let metropolis = p("metropolis", "Metropolis", "#2B2B2B", "#E8E8E8", "#F92672", "#A6E22E", "#75715E", "#66D9EF", "#AE81FF", "#56B6C2", "#202020", "#333333")
    public static let mirage = p("mirage", "Mirage", "#000000", "#F7EBC6", "#FFB000", "#95FFA4", "#AEAEAE", "#66D9EF", "#FD971F", "#66D9EF", "#000000", "#0D0D0D")
    public static let mojave = p("mojave", "Mojave", "#1F222D", "#E6E6E6", "#C792EA", "#C3E88D", "#5C6370", "#82AAFF", "#F78C6C", "#7FDBCA", "#181B24", "#262B38")
    public static let primer = p("primer", "Primer", "#FFFFFF", "#24292F", "#8250DF", "#0A3069", "#57606A", "#953800", "#0550AE", "#0969DA", "#F6F8FA", "#EAEEF2")
    public static let quietlight = p("quietlight", "Quietlight", "#FFFFFF", "#000000", "#0000FF", "#DD1144", "#008000", "#000080", "#098658", "#000080", "#F6F8FA", "#EDEDED")
    public static let red = p("red", "Red", "#38080A", "#F8F8F8", "#FF7583", "#FC6A5D", "#888888", "#5DD8FF", "#D0BF69", "#5DD8FF", "#2A0607", "#421013")
    public static let sublime = p("sublime", "Sublime", "#282B2B", "#E8E8E8", "#CC99CD", "#8EC07C", "#65737E", "#56B6C2", "#D19A66", "#56B6C2", "#1F2121", "#313434")
    public static let twilight = p("twilight", "Twilight", "#131313", "#F8F8F2", "#F92672", "#A6E22E", "#75715E", "#66D9EF", "#AE81FF", "#56B6C2", "#0D0D0D", "#1E1E1E")
    public static let verminal = p("verminal", "Verminal", "#35242F", "#FFFFFF", "#FFB000", "#FC6A5D", "#8A7F8D", "#66D9EF", "#AE81FF", "#66D9EF", "#2A1D26", "#3D2A38")
    public static let vsCodeLightPlus = p("vscode_light_plus", "VS Code Light+", "#FFFFFF", "#000000", "#0000FF", "#A31515", "#008000", "#267F99", "#098658", "#AF00DB", "#F3F3F3", "#EDEDED")

    public static let builtIns: [AppTheme] = [
        .xcodeDark, .xcodeLight, .midnightPurple, .cyberpunk,
        .solarizedDark, .solarizedLight, .monokaiPro, .dracula,
        .gruvboxDark, .nord, .oneDark, .synthwave84, .tokyoNight,
        .catppuccinMocha, .catppuccinLatte, .forest, .cobalt,
        .light, .dark, .xcodeDefault, .githubLight, .monokai,
        .solarized, .gruvbox, .catppuccin, .ayuDark, .nightOwl,
        .palenight, .cobalt2, .synthwave, .rosePine, .everforest,
        .kanagawa, .midnight, .sepia, .highContrast,
        .githubDark, .gruvboxLight, .oneLight, .ayuLight, .ayuMirage,
        .tokyoNightDay, .rosePineMoon, .rosePineDawn, .catppuccinFrappe, .catppuccinMacchiato,
        .githubDimmed, .githubLightHC, .tokyoStorm, .oneDarkPro, .nightfox,
        .oceanicNext, .poimandres, .darkPlus, .andromeeda, .aurora,
        .buffer, .brogrammer, .darkside, .edge, .flexoki,
        .hacker, .irBlack, .jack, .kale, .macClassic,
        .mariana, .metropolis, .mirage, .mojave, .primer,
        .quietlight, .red, .sublime, .twilight, .verminal, .vsCodeLightPlus
    ]
}

@Observable
@MainActor
public final class ThemeManager {
    public static let shared = ThemeManager()

    public var customThemes: [AppTheme] = [] {
        didSet { save() }
    }

    private let defaultsKey = "customThemes"

    private init() { load() }

    public var allThemes: [AppTheme] {
        
        
        let overridden = Set(customThemes.map(\.id))
        return customThemes + AppTheme.builtIns.filter { !overridden.contains($0.id) }
    }
    public var themes: [AppTheme] { allThemes }

    public func theme(for id: String) -> AppTheme? {
        allThemes.first { $0.id == id }
    }

    public func add(_ theme: AppTheme) {
        var mutable = theme
        mutable.isBuiltIn = false
        customThemes.append(mutable)
    }

    public func update(_ theme: AppTheme) {
        
        
        
        
        var mutable = theme
        mutable.isBuiltIn = false
        if let idx = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[idx] = mutable
        } else {
            customThemes.append(mutable)
        }
    }

    public func delete(_ theme: AppTheme) {
        customThemes.removeAll { $0.id == theme.id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(customThemes) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        
        
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        let decoder = JSONDecoder()
        customThemes = raw.compactMap { dict in
            guard let d = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? decoder.decode(AppTheme.self, from: d)
        }
    }

    public func reset() { customThemes = [] }
}
