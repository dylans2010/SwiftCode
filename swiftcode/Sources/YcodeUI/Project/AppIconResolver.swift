import AppKit
import Foundation



@MainActor
public enum AppIconResolver {
    public static func icon(forXcodeproj url: URL, size: CGFloat = 32) -> NSImage? {
        let base = url.deletingLastPathComponent()
        if let image = largestAppIcon(in: base) {
            image.size = NSSize(width: size, height: size)
            return image
        }
        let wsIcon = NSWorkspace.shared.icon(forFile: url.path)
        wsIcon.size = NSSize(width: size, height: size)
        return wsIcon
    }

    public static func largestAppIcon(in directory: URL) -> NSImage? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return nil }
        var best: (image: NSImage, pixels: Int)?
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "Contents.json",
                  fileURL.path.contains(".appiconset") else { continue }
            guard let data = try? Data(contentsOf: fileURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let images = json["images"] as? [[String: Any]] else { continue }
            let dir = fileURL.deletingLastPathComponent()
            for entry in images {
                guard let filename = entry["filename"] as? String, !filename.isEmpty else { continue }
                let imageURL = dir.appendingPathComponent(filename)
                guard let image = NSImage(contentsOf: imageURL),
                      let rep = image.representations.first else { continue }
                let pixels = rep.pixelsWide * rep.pixelsHigh
                if best == nil || pixels > best!.pixels {
                    best = (image, pixels)
                }
            }
        }
        return best?.image
    }

    public static func appIconName(forTarget target: String, settings: [String: String]) -> String {
        settings["ASSETCATALOG_COMPILER_APPICON_NAME"] ?? "AppIcon"
    }
}
