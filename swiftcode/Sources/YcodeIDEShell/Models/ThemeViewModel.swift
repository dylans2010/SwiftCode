import Foundation
import Observation
import SwiftUI
import YcodeIDECore

@Observable
@MainActor
public class ThemeViewModel {
    public var themes: [EditorTheme] = []
    public var currentTheme: EditorTheme
    public var fontSize: CGFloat = 13.0
    public var fontFamily: String = "SF Mono"

    public init() {
        let defaults = EditorTheme.builtIns
        let defaultTheme = defaults.first ?? EditorTheme(
            name: "SwiftCode Dark",
            fontName: "SF Mono",
            fontSize: 13,
            background: "#1E1E1E",
            foreground: "#D4D4D4",
            selection: "#264F78",
            currentLine: "#2F3333",
            tokens: [:],
            consoleFontName: "SF Mono",
            consoleFontSize: 11,
            consoleBackground: nil as String?,
            consoleText: nil as String?
        )

        self.currentTheme = defaultTheme
        self.themes = defaults.isEmpty ? [defaultTheme] : defaults
    }

    public func loadThemes() async {
        do {
            let loaded = try await ThemeStore.shared.loadThemes()
            for theme in loaded {
                if !themes.contains(where: { $0.name == theme.name }) {
                    themes.append(theme)
                }
            }
        } catch {
            LoggingTool.error("Failed to load themes: \(error)")
        }
    }
}
