import AppKit
import SwiftUI




public enum SDKFileSymbols {
    public static func symbol(forPathExtension ext: String, isFolder: Bool = false) -> String {
        if isFolder {
            return "folder.fill"
        }

        let cleaned = ext.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch cleaned {
        case "swift":
            return "swift"
        case "json":
            return "curlybraces.square.fill"
        case "xml":
            return "chevron.left.slash.chevron.right"
        case "entitlements":
            return "lock.shield.fill"
        case "plist":
            return "list.bullet.rectangle.fill"
        case "md", "markdown":
            return "text.quote"
        case "xcassets", "appiconset", "png", "jpg", "jpeg", "gif", "svg", "heic", "webp", "tiff", "bmp", "ico", "icns":
            return "photo.on.rectangle.angled"
        case "xcodeproj", "xcworkspace":
            return "hammer.fill"
        case "sh", "bash", "zsh":
            return "terminal.fill"
        case "c", "cpp", "h", "m", "mm":
            return "c.square.fill"
        case "txt":
            return "doc.plaintext"
        case "yml", "yaml":
            return "gearshape.2.fill"
        case "js", "ts", "jsx", "tsx":
            return "curlybraces"
        case "css":
            return "paintbrush.fill"
        case "html":
            return "globe"
        case "pbxproj", "swiftpm", "package":
            return "shippingbox.fill"
        case "gitignore":
            return "eye.slash.fill"
        case "zip":
            return "archivebox.fill"
        case "pdf":
            return "doc.richtext.fill"
        case "mov", "mp4":
            return "film.fill"
        case "mp3", "wav":
            return "waveform"
        default:
            if cleaned.hasPrefix(".") {
                return "eye.slash"
            }
            return "doc"
        }
    }

    public static func color(forPathExtension ext: String, isFolder: Bool = false) -> Color {
        if isFolder {
            return .blue
        }
        let cleaned = ext.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch cleaned {
        case "swift":
            return .orange
        case "json":
            return .yellow
        case "xml":
            return .cyan
        case "entitlements":
            return .purple
        case "plist":
            return .blue
        case "md", "markdown":
            return .mint
        case "xcassets", "appiconset", "png", "jpg", "jpeg", "gif", "svg", "heic", "webp", "tiff", "bmp", "ico", "icns":
            return .pink
        case "xcodeproj", "xcworkspace":
            return .blue
        case "sh", "bash", "zsh":
            return .green
        case "c", "cpp", "h", "m", "mm":
            return .indigo
        default:
            return .secondary
        }
    }
}



@MainActor
public enum SDKStudioPasteboard {
    public private(set) static var lastCopied: String?

    public static func copy(_ text: String) {
        lastCopied = text
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
