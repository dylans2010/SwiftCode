import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import YcodeIDECore
import YcodeIcon

@MainActor
public final class IconComposerModel: ObservableObject {
    @Published public private(set) var package: IconPackage
    @Published public var selectedAppearance: IconAppearance = .light {
        didSet { revision &+= 1 }
    }
    @Published public var selectedPlatform: IconPlatform = .iOS {
        didSet { revision &+= 1 }
    }
    @Published public var selectedGroup: Int = 0 {
        didSet { clampSelection(); revision &+= 1 }
    }
    @Published public var selectedLayer: Int? = nil {
        didSet { revision &+= 1 }
    }
    @Published public private(set) var appIconSetURL: URL?
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var revision = 0
    private var undoSnapshots: [IconDocument] = []
    private var redoSnapshots: [IconDocument] = []

    public var canUndo: Bool { !undoSnapshots.isEmpty }
    public var canRedo: Bool { !redoSnapshots.isEmpty }

    public func recordUndo() {
        undoSnapshots.append(document)
        if undoSnapshots.count > 40 { undoSnapshots.removeFirst() }
        redoSnapshots.removeAll()
    }

    public func undo() {
        guard let prev = undoSnapshots.popLast() else { return }
        redoSnapshots.append(document)
        document = prev
        clampSelection()
        changed()
        save()
    }

    public func redo() {
        guard let next = redoSnapshots.popLast() else { return }
        undoSnapshots.append(document)
        document = next
        clampSelection()
        changed()
        save()
    }

    public var iconPackageURL: URL { package.url }
    public var document: IconDocument {
        get { package.document }
        set { package.document = newValue }
    }

    public init(package: IconPackage) {
        self.package = package
        self.appIconSetURL = nil
    }

    public init() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftCode/IconComposer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Untitled.icon", isDirectory: true)
        package = IconPackage(url: url, document: Self.makeDocument())
    }

    public init(appIconSet setURL: URL) {
        let iconURL = Self.companionIconURL(forAppIconSet: setURL)
        appIconSetURL = setURL
        if let pkg = try? IconPackage(contentsOf: iconURL) {
            package = pkg
        } else {
            var pkg = IconPackage(url: iconURL, document: Self.makeDocument())
            Self.seedArtwork(from: setURL, into: &pkg)
            package = pkg
            try? package.write()
        }
    }

    public static func companionIconURL(forAppIconSet setURL: URL) -> URL {
        setURL.deletingPathExtension().appendingPathExtension("icon")
    }

    public func attach(appIconSet setURL: URL) {
        appIconSetURL = setURL
        statusMessage = "Export target: \(setURL.lastPathComponent)"
    }

    public static func makeDocument() -> IconDocument {
        var doc = IconDocument(fill: .automatic, groups: [IconGroup(name: "Artwork")])
        doc.supportedPlatforms = .multiplatform
        return doc
    }

    public static func seedArtwork(from setURL: URL, into package: inout IconPackage) {
        let set = AssetCatalog.AssetSet(name: setURL.deletingPathExtension().lastPathComponent,
                                        kind: .appIconSet, url: setURL, group: "")
        let slots = AssetCatalog.slots(of: set)
        var best: (url: URL, score: Int)?
        for s in slots {
            guard let f = s.filename else { continue }
            let u = setURL.appendingPathComponent(f)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir), !isDir.boolValue else { continue }
            var score = 0
            if s.platform == "ios", s.scale == nil { score += 10000 }
            if s.idiom == "mac" { score += 1000 }
            if let px = Self.pixelSize(of: s), px > 256 { score += px / 4 }
            if best == nil || score > best!.score { best = (u, score) }
        }
        guard let best, let layer = importImage(best.url, into: package) else { return }
        if package.document.groups.isEmpty {
            package.document.groups.append(IconGroup(name: "Artwork"))
        }
        package.document.groups[0].layers.append(layer)
    }

    public static func pixelSize(of slot: AssetCatalog.Slot) -> Int? {
        guard let size = slot.size else { return nil }
        let parts = size.split(separator: "x")
        guard parts.count == 2, let w = Double(parts[0]) else { return nil }
        let scale = slot.scale == "2x" ? 2.0 : slot.scale == "3x" ? 3.0 : 1.0
        if slot.scale == nil, slot.platform != nil { return Int(w) }
        return Int((w * scale).rounded())
    }

    public static func importImage(_ file: URL, into package: IconPackage) -> IconLayer? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        let imageName = uniqueAssetName(for: file, in: package)
        do {
            try FileManager.default.createDirectory(at: package.assetsURL, withIntermediateDirectories: true)
            try data.write(to: package.assetURL(imageName))
        } catch {
            return nil
        }
        var layer = IconLayer(name: file.deletingPathExtension().lastPathComponent, imageName: imageName)
        layer.glass = IconSpecialized(false)
        return layer
    }

    static func uniqueAssetName(for file: URL, in package: IconPackage) -> String {
        let ext = file.pathExtension.isEmpty ? "png" : file.pathExtension
        let base = file.deletingPathExtension().lastPathComponent
        let fm = FileManager.default
        var name = "\(base).\(ext)"
        var i = 2
        while fm.fileExists(atPath: package.assetURL(name).path) {
            name = "\(base)-\(i).\(ext)"
            i += 1
        }
        return name
    }

    static func writeAsset(_ image: CGImage, named base: String, in package: IconPackage) -> String? {
        guard let data = IconComposerRenderer.pngData(image) else { return nil }
        let fm = FileManager.default
        var name = "\(base).png"
        var i = 2
        while fm.fileExists(atPath: package.assetURL(name).path) {
            name = "\(base)-\(i).png"
            i += 1
        }
        do {
            try fm.createDirectory(at: package.assetsURL, withIntermediateDirectories: true)
            try data.write(to: package.assetURL(name))
            return name
        } catch {
            return nil
        }
    }

    public var groups: [IconGroup] { document.groups }

    public var resolved: ResolvedIcon { document.resolved(selectedAppearance, selectedPlatform) }

    public func select(group: Int, layer: Int? = nil) {
        selectedGroup = group
        selectedLayer = layer
    }

    private func clampSelection() {
        if document.groups.isEmpty {
            selectedGroup = 0
            selectedLayer = nil
            return
        }
        if selectedGroup >= document.groups.count { selectedGroup = document.groups.count - 1 }
        if let l = selectedLayer, l >= document.groups[selectedGroup].layers.count { selectedLayer = nil }
    }

    public func changed() { revision &+= 1 }

    public func save() {
        do {
            try package.write()
            statusMessage = "Saved \(package.url.lastPathComponent)"
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    public func addGroup() {
        document.groups.append(IconGroup(name: "Group \(document.groups.count + 1)"))
        selectedGroup = document.groups.count - 1
        selectedLayer = nil
        changed()
    }

    public func addImageLayer(_ file: URL) {
        guard let layer = Self.importImage(file, into: package) else {
            statusMessage = "Could not read \(file.lastPathComponent)"
            return
        }
        ensureGroup()
        document.groups[selectedGroup].layers.append(layer)
        selectedLayer = document.groups[selectedGroup].layers.count - 1
        changed()
        save()
    }

    public func addShapeLayer(_ shape: IconComposerShapes.Shape) {
        recordUndo()
        guard let image = IconComposerShapes.image(shape, pixels: 512),
              let name = Self.writeAsset(image, named: shape.rawValue, in: package) else {
            statusMessage = "Could not generate shape"
            return
        }
        var layer = IconLayer(name: shape.rawValue.capitalized, imageName: name)
        layer.glass = IconSpecialized(false)
        ensureGroup()
        document.groups[selectedGroup].layers.append(layer)
        selectedLayer = document.groups[selectedGroup].layers.count - 1
        changed()
        save()
    }

    public func addSFSymbolLayer(symbolName: String, weight: NSFont.Weight = .semibold, color: NSColor = .white) {
        recordUndo()
        guard let cg = IconComposerAssetGenerator.renderSFSymbol(symbolName: symbolName, weight: weight, color: color),
              let assetName = Self.writeAsset(cg, named: symbolName.replacingOccurrences(of: ".", with: "-"), in: package) else {
            statusMessage = "Unknown SF Symbol '\(symbolName)'"
            return
        }
        var layer = IconLayer(name: symbolName, imageName: assetName)
        layer.glass = IconSpecialized(true)
        layer.extra[IconComposerRenderer.shadowRadiusKey] = .number(16)
        ensureGroup()
        document.groups[selectedGroup].layers.append(layer)
        selectedLayer = document.groups[selectedGroup].layers.count - 1
        changed()
        save()
    }

    public func addMonogramLayer(text: String, design: NSFontDescriptor.SystemDesign = .rounded, color: NSColor = .white) {
        recordUndo()
        guard let cg = IconComposerAssetGenerator.renderMonogram(text: text, design: design, color: color),
              let assetName = Self.writeAsset(cg, named: "monogram", in: package) else {
            statusMessage = "Could not render monogram"
            return
        }
        var layer = IconLayer(name: "Badge \(text)", imageName: assetName)
        layer.glass = IconSpecialized(true)
        layer.extra[IconComposerRenderer.shadowRadiusKey] = .number(14)
        ensureGroup()
        document.groups[selectedGroup].layers.append(layer)
        selectedLayer = document.groups[selectedGroup].layers.count - 1
        changed()
        save()
    }

    public func duplicateSelectedLayer() {
        guard let l = selectedLayer, document.groups.indices.contains(selectedGroup),
              document.groups[selectedGroup].layers.indices.contains(l) else { return }
        recordUndo()
        var copy = document.groups[selectedGroup].layers[l]
        copy.name = (copy.name ?? "Layer") + " Copy"
        document.groups[selectedGroup].layers.insert(copy, at: l + 1)
        selectedLayer = l + 1
        changed()
        save()
    }

    public func resetSelectedTransform() {
        recordUndo()
        updateSelectedLayer {
            $0.position.value = .identity
            $0.position.specializations = nil
        }
        save()
    }

    public func layerShadowRadius(_ l: IconLayer) -> Double {
        l.extra[IconComposerRenderer.shadowRadiusKey]?.numberValue ?? 0
    }

    public func setLayerShadowRadius(_ v: Double) {
        updateSelectedLayer { $0.extra[IconComposerRenderer.shadowRadiusKey] = .number(v) }
        save()
    }

    public func applyStarterTemplate(_ template: String) {
        recordUndo()
        document.groups = [IconGroup(name: "Background Motif"), IconGroup(name: "Foreground Symbol")]
        selectedGroup = 0
        switch template {
        case "Developer Terminal":
            setDocumentFill(.linearGradient(IconColor.srgb(0.08, 0.10, 0.16), IconColor.srgb(0.16, 0.24, 0.38), orientation: nil))
            addShapeLayer(.roundedSquare)
            setLayerScale(0.76); setLayerOpacity(0.28)
            selectedGroup = 1
            addSFSymbolLayer(symbolName: "terminal.fill", weight: .bold, color: .white)
        case "AI Sparkle Glass":
            setDocumentFill(.linearGradient(IconColor.srgb(0.32, 0.14, 0.82), IconColor.srgb(0.86, 0.26, 0.68), orientation: nil))
            addShapeLayer(.ring)
            setLayerScale(0.84); setLayerOpacity(0.35)
            selectedGroup = 1
            addSFSymbolLayer(symbolName: "sparkles", weight: .bold, color: .white)
        case "Shield Security":
            setDocumentFill(.linearGradient(IconColor.srgb(0.05, 0.42, 0.38), IconColor.srgb(0.12, 0.72, 0.56), orientation: nil))
            addShapeLayer(.hexagon)
            setLayerScale(0.82); setLayerOpacity(0.25)
            selectedGroup = 1
            addSFSymbolLayer(symbolName: "lock.shield.fill", weight: .bold, color: .white)
        default:
            setDocumentFill(.linearGradient(IconColor.srgb(0.07, 0.38, 0.92), IconColor.srgb(0.16, 0.76, 0.96), orientation: nil))
            addShapeLayer(.concentricRings)
            setLayerScale(0.85); setLayerOpacity(0.22)
            selectedGroup = 1
            addSFSymbolLayer(symbolName: "swift", weight: .bold, color: .white)
        }
        statusMessage = "Applied '\(template)' template"
    }

    public func removeSelected() {
        guard document.groups.indices.contains(selectedGroup) else { return }
        if let l = selectedLayer {
            guard document.groups[selectedGroup].layers.indices.contains(l) else { return }
            document.groups[selectedGroup].layers.remove(at: l)
            selectedLayer = nil
        } else {
            document.groups.remove(at: selectedGroup)
            clampSelection()
        }
        changed()
        save()
    }

    public func moveSelectedLayer(by delta: Int) {
        guard let l = selectedLayer, document.groups.indices.contains(selectedGroup) else { return }
        var layers = document.groups[selectedGroup].layers
        let target = l + delta
        guard layers.indices.contains(target) else { return }
        layers.swapAt(l, target)
        document.groups[selectedGroup].layers = layers
        selectedLayer = target
        changed()
        save()
    }

    public func moveSelectedGroup(by delta: Int) {
        guard document.groups.indices.contains(selectedGroup) else { return }
        let target = selectedGroup + delta
        guard document.groups.indices.contains(target) else { return }
        document.groups.swapAt(selectedGroup, target)
        selectedGroup = target
        clampSelection()
        changed()
        save()
    }

    public func ensureGroup() {
        if document.groups.isEmpty {
            document.groups.append(IconGroup(name: "Artwork"))
            selectedGroup = 0
        }
        clampSelection()
    }

    public func updateSelectedLayer(_ body: (inout IconLayer) -> Void) {
        guard let l = selectedLayer, document.groups.indices.contains(selectedGroup),
              document.groups[selectedGroup].layers.indices.contains(l) else { return }
        body(&document.groups[selectedGroup].layers[l])
        changed()
    }

    public func updateSelectedGroup(_ body: (inout IconGroup) -> Void) {
        guard document.groups.indices.contains(selectedGroup) else { return }
        body(&document.groups[selectedGroup])
        changed()
    }

    public func setDocumentFill(_ fill: IconFill) {
        document.fill = IconSpecialized(fill)
        changed()
        save()
    }

    public func setGroupName(_ name: String) {
        updateSelectedGroup { $0.name = name.isEmpty ? nil : name }
        save()
    }

    public func setLayerName(_ name: String) {
        updateSelectedLayer { $0.name = name.isEmpty ? nil : name }
        save()
    }

    public func layerOpacity(_ l: IconLayer) -> Double { l.opacity.resolve(selectedAppearance, selectedPlatform) ?? 1 }
    public func layerScale(_ l: IconLayer) -> Double { l.position.resolve(selectedAppearance, selectedPlatform)?.scale ?? 1 }
    public func layerTranslation(_ l: IconLayer) -> IconPoint {
        l.position.resolve(selectedAppearance, selectedPlatform)?.translation ?? IconPoint(x: 0, y: 0)
    }
    public func layerRotation(_ l: IconLayer) -> Double {
        l.position.resolve(selectedAppearance, selectedPlatform)?.extra[IconComposerRenderer.rotationKey]?.numberValue ?? 0
    }
    public func layerBlur(_ l: IconLayer) -> Double { l.extra[IconComposerRenderer.blurKey]?.numberValue ?? 0 }
    public func layerGlass(_ l: IconLayer) -> Bool { l.glass.resolve(selectedAppearance, selectedPlatform) ?? true }
    public func layerHidden(_ l: IconLayer) -> Bool { l.hidden.resolve(selectedAppearance, selectedPlatform) ?? false }
    public func layerBlendMode(_ l: IconLayer) -> IconBlendMode { l.blendMode.resolve(selectedAppearance, selectedPlatform) ?? .normal }
    public func layerFill(_ l: IconLayer) -> IconFill { l.fill.resolve(selectedAppearance, selectedPlatform) ?? .automatic }

    public func setLayerOpacity(_ v: Double) { updateSelectedLayer { setBase(&$0.opacity, v) }; save() }
    public func setLayerScale(_ v: Double) {
        updateSelectedLayer {
            var p = $0.position.value ?? .identity
            p.scale = v
            $0.position.value = p
            $0.position.specializations = nil
        }
        save()
    }
    public func setLayerTranslation(x: Double, y: Double) {
        updateSelectedLayer {
            var p = $0.position.value ?? .identity
            p.translation = IconPoint(x: x, y: y)
            $0.position.value = p
        }
        save()
    }
    public func setLayerRotation(_ v: Double) {
        updateSelectedLayer {
            var p = $0.position.value ?? .identity
            p.extra[IconComposerRenderer.rotationKey] = .number(v)
            $0.position.value = p
        }
        save()
    }
    public func setLayerBlur(_ v: Double) {
        updateSelectedLayer { $0.extra[IconComposerRenderer.blurKey] = .number(v) }
        save()
    }
    public func setLayerGlass(_ v: Bool) { updateSelectedLayer { $0.glass.value = v }; save() }
    public func setLayerHidden(_ v: Bool) { updateSelectedLayer { setBase(&$0.hidden, v) }; save() }
    public func setLayerBlendMode(_ v: IconBlendMode) { updateSelectedLayer { setBase(&$0.blendMode, v) }; save() }
    public func setLayerFill(_ v: IconFill) { updateSelectedLayer { setBase(&$0.fill, v) }; save() }

    public func groupOpacity(_ g: IconGroup) -> Double { g.opacity.resolve(selectedAppearance, selectedPlatform) ?? 1 }
    public func groupHidden(_ g: IconGroup) -> Bool { g.hidden.resolve(selectedAppearance, selectedPlatform) ?? false }
    public func groupScale(_ g: IconGroup) -> Double { g.position.resolve(selectedAppearance, selectedPlatform)?.scale ?? 1 }
    public func groupTranslation(_ g: IconGroup) -> IconPoint {
        g.position.resolve(selectedAppearance, selectedPlatform)?.translation ?? IconPoint(x: 0, y: 0)
    }
    public func groupBlurMaterial(_ g: IconGroup) -> Double { g.blurMaterial.resolve(selectedAppearance, selectedPlatform)?.effectiveValue ?? 0 }
    public func groupShadowOpacity(_ g: IconGroup) -> Double { g.shadow.resolve(selectedAppearance, selectedPlatform)?.opacity ?? 0.5 }

    public func setGroupOpacity(_ v: Double) { updateSelectedGroup { setBase(&$0.opacity, v) }; save() }
    public func setGroupHidden(_ v: Bool) { updateSelectedGroup { setBase(&$0.hidden, v) }; save() }
    public func setGroupScale(_ v: Double) {
        updateSelectedGroup {
            var p = $0.position.value ?? .identity
            p.scale = v
            $0.position.value = p
        }
        save()
    }
    public func setGroupTranslation(x: Double, y: Double) {
        updateSelectedGroup {
            var p = $0.position.value ?? .identity
            p.translation = IconPoint(x: x, y: y)
            $0.position.value = p
        }
        save()
    }
    public func setGroupBlurMaterial(_ v: Double) { updateSelectedGroup { $0.blurMaterial.value = IconBlurMaterial(v) }; save() }
    public func setGroupShadowOpacity(_ v: Double) {
        updateSelectedGroup {
            var s = $0.shadow.value ?? .default
            s.opacity = v
            $0.shadow.value = s
        }
        save()
    }

    func setBase<V: IconValue>(_ field: inout IconSpecialized<V>, _ v: V) {
        field.value = v
        field.specializations = nil
    }

    public func exportToAppIconSet() -> [URL] {
        guard let setURL = appIconSetURL else {
            statusMessage = "No app icon set attached"
            return []
        }
        let set = AssetCatalog.AssetSet(name: setURL.deletingPathExtension().lastPathComponent,
                                        kind: .appIconSet, url: setURL, group: "")
        do {
            let files = try IconComposerExporter.export(package: package, to: set)
            statusMessage = "Exported \(files.count) icon images to \(set.name).appiconset"
            return files
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
            return []
        }
    }

    public func chooseAppIconSet() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowedContentTypes = [.folder]
        panel.prompt = "Choose"
        panel.message = "Choose an .appiconset folder to export into"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    public func render(pixels: Int) -> CGImage? {
        IconComposerRenderer.render(package: package, appearance: selectedAppearance, platform: selectedPlatform, pixels: pixels)
    }
}
