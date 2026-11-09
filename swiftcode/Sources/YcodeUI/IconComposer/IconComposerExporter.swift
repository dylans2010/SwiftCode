import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import YcodeIDECore
import YcodeIcon

public enum IconComposerExporter {
    public struct ExportError: Error, CustomStringConvertible {
        public var description: String
    }

    public static func export(package: IconPackage, to set: AssetCatalog.AssetSet) throws -> [URL] {
        var obj = AssetCatalog.readContents(set.url)
        let key = set.kind.slotKey ?? "images"
        guard var entries = obj[key] as? [[String: Any]], !entries.isEmpty else {
            throw ExportError(description: "\(set.name).appiconset has no image slots in Contents.json")
        }
        var cache: [String: CGImage] = [:]
        var usedNames = Set<String>()
        var written: [URL] = []
        var changed = false
        for i in entries.indices {
            var entry = entries[i]
            let slot = AssetCatalog.slot(entry)
            guard let spec = renderSpec(for: slot) else { continue }
            let cacheKey = "\(spec.appearance.rawValue)|\(spec.platform.rawValue)|\(spec.pixels)|\(spec.mask)"
            let image: CGImage
            if let hit = cache[cacheKey] {
                image = hit
            } else {
                guard let rendered = IconComposerRenderer.render(document: package.document, package: package,
                                                                 appearance: spec.appearance, platform: spec.platform,
                                                                 pixels: spec.pixels, mask: spec.mask) else {
                    throw ExportError(description: "Failed to render \(spec.pixels)px icon for \(slot.title)")
                }
                cache[cacheKey] = rendered
                image = rendered
            }
            guard let data = IconComposerRenderer.pngData(image) else { continue }
            let name = uniqueFileName(base: fileBase(slot: slot, index: i), ext: "png", in: set.url, used: &usedNames)
            let dest = set.url.appendingPathComponent(name)
            try data.write(to: dest, options: .atomic)
            written.append(dest)
            entry["filename"] = name
            entries[i] = entry
            changed = true
        }
        if changed {
            obj[key] = entries
            try AssetCatalog.json(obj).write(to: set.url.appendingPathComponent("Contents.json"), options: .atomic)
        }
        return written
    }

    struct RenderSpec {
        var appearance: IconAppearance
        var platform: IconPlatform
        var pixels: Int
        var mask: IconComposerMask
    }

    static func renderSpec(for slot: AssetCatalog.Slot) -> RenderSpec? {
        guard let size = slot.size else { return nil }
        let parts = size.split(separator: "x")
        guard parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]) else { return nil }
        let scale: Double
        switch slot.scale {
        case "2x": scale = 2
        case "3x": scale = 3
        default: scale = 1
        }
        let pixelsW: Int
        let pixelsH: Int
        if slot.scale == nil, slot.platform != nil {
            pixelsW = Int(w)
            pixelsH = Int(h)
        } else {
            pixelsW = Int((w * scale).rounded())
            pixelsH = Int((h * scale).rounded())
        }
        let pixels = max(pixelsW, pixelsH)
        guard pixels > 0 else { return nil }
        let platform: IconPlatform
        switch slot.platform ?? platformForIdiom(slot.idiom) {
        case "macos": platform = .macOS
        case "watchos": platform = .watchOS
        case "tvos", "xros", "visionos": platform = .iOS
        default: platform = .iOS
        }
        let appearance: IconAppearance
        if let a = slot.appearance {
            appearance = a.contains("tint") ? .tinted : .dark
        } else {
            appearance = .light
        }
        let mask: IconComposerMask
        switch slot.idiom {
        case "mac": mask = .squircle
        case "watch": mask = .circle
        default: mask = .none
        }
        return RenderSpec(appearance: appearance, platform: platform, pixels: pixels, mask: mask)
    }

    static func platformForIdiom(_ idiom: String) -> String {
        switch idiom {
        case "mac": return "macos"
        case "watch": return "watchos"
        case "tv": return "tvos"
        case "vision": return "visionos"
        default: return "ios"
        }
    }

    static func fileBase(slot: AssetCatalog.Slot, index: Int) -> String {
        var parts = ["icon"]
        if let p = slot.platform { parts.append(p) }
        parts.append(slot.idiom)
        if let s = slot.size { parts.append(s.replacingOccurrences(of: "x", with: "-")) }
        if let s = slot.scale { parts.append(s.replacingOccurrences(of: "x", with: "-")) }
        if let a = slot.appearance { parts.append(a) }
        return parts.joined(separator: "-") + "-\(index)"
    }

    static func uniqueFileName(base: String, ext: String, in dir: URL, used: inout Set<String>) -> String {
        var name = "\(base).\(ext)"
        var i = 2
        while used.contains(name) || FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path) {
            name = "\(base)-\(i).\(ext)"
            i += 1
        }
        used.insert(name)
        return name
    }
}
