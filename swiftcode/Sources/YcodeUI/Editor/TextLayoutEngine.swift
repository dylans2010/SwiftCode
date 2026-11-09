import AppKit

@MainActor
public final class TextLayoutEngine {
    public static let shared = TextLayoutEngine()
    private init() {}

    public static func editorFont(size: CGFloat = 14) -> NSFont {
        NSFont(name: "Menlo", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    public static func lineHeight(fontSize: CGFloat = 14) -> CGFloat {
        editorFont(size: fontSize).ascender - editorFont(size: fontSize).descender + editorFont(size: fontSize).leading
    }

    public static func paragraphStyle(fontSize: CGFloat = 14) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let h = lineHeight(fontSize: fontSize)
        style.minimumLineHeight = h
        style.maximumLineHeight = h
        style.lineSpacing = 0
        return style
    }

    public static let lineNumberColumnWidth: CGFloat = 50

    public static func textContainerInset(topPadding: CGFloat = 8) -> NSSize {
        NSSize(width: 10, height: topPadding)
    }

    public static func yPosition(forLine line: Int, fontSize: CGFloat = 14, topInset: CGFloat = 8) -> CGFloat {
        topInset + CGFloat(line - 1) * lineHeight(fontSize: fontSize)
    }

    public static func lineCount(in text: String) -> Int {
        max(1, text.components(separatedBy: "\n").count)
    }

    public static func expandTabs(_ text: String, tabWidth: Int = 4) -> String {
        text.replacingOccurrences(of: "\t", with: String(repeating: " ", count: tabWidth))
    }

    public static func leadingWhitespace(of line: String) -> String {
        var result = ""
        for ch in line {
            guard ch == " " || ch == "\t" else { break }
            result.append(ch)
        }
        return result
    }

    public static func codeColumnWidth(
        totalWidth: CGFloat,
        minimapWidth: CGFloat = 0
    ) -> CGFloat {
        max(totalWidth - lineNumberColumnWidth - minimapWidth, 200)
    }
}
