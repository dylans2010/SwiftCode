import AppKit
import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers
import YcodeIDECore
import YcodeIcon

@MainActor
public final class IconComposerPreviewStore: ObservableObject {
    @Published public private(set) var images: [Int: CGImage] = [:]
    private var task: Task<Void, Never>?
    private var generation = 0

    public struct Size: Hashable, Sendable {
        public var pt: Int
        public var pixels: Int
    }

    nonisolated public static let previewSizes: [Size] = [
        Size(pt: 20, pixels: 60), Size(pt: 29, pixels: 87), Size(pt: 40, pixels: 120), Size(pt: 60, pixels: 120),
        Size(pt: 76, pixels: 152), Size(pt: 120, pixels: 360), Size(pt: 152, pixels: 456), Size(pt: 167, pixels: 501),
        Size(pt: 180, pixels: 540), Size(pt: 1024, pixels: 1024),
    ]

    public func schedule(document: IconDocument, package: IconPackage, appearance: IconAppearance,
                         platform: IconPlatform) {
        generation &+= 1
        let gen = generation
        task?.cancel()
        task = Task.detached(priority: .userInitiated) {
            var rendered: [Int: CGImage] = [:]
            for size in Self.previewSizes {
                if Task.isCancelled { return }
                if let image = IconComposerRenderer.render(document: document, package: package,
                                                           appearance: appearance, platform: platform,
                                                           pixels: size.pixels) {
                    rendered[size.pixels] = image
                }
            }
            await MainActor.run {
                guard gen == self.generation else { return }
                self.images = rendered
            }
        }
    }
}

public struct IconComposerStandaloneView: View {
    @StateObject private var model = IconComposerModel()

    public init() {}

    public var body: some View {
        IconComposerView(model: model)
    }
}

public struct IconComposerView: View {
    @ObservedObject public var model: IconComposerModel
    @StateObject private var previews = IconComposerPreviewStore()
    @State private var exportError: String?
    @State private var showingSymbolSheet = false
    @State private var showingMonogramSheet = false
    @State private var customStartColor = Color(red: 0.08, green: 0.36, blue: 0.90)
    @State private var customEndColor = Color(red: 0.45, green: 0.20, blue: 0.92)
    @AppStorage("iconComposer.showGrid") private var showGrid = true
    @AppStorage("iconComposer.showKeylines") private var showKeylines = true
    @AppStorage("iconComposer.maskSquircle") private var maskSquircle = true

    public init(model: IconComposerModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HSplitView {
                layersPanel
                    .frame(minWidth: 220, idealWidth: 240, maxWidth: 320)
                canvasPanel
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                inspectorPanel
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 340)
            }
        }
        .frame(minWidth: 1000, minHeight: 640)
        .onAppear { scheduleRender() }
        .onChange(of: model.revision) { _, _ in scheduleRender() }
        .onChange(of: model.selectedAppearance) { _, _ in scheduleRender() }
        .onChange(of: model.selectedPlatform) { _, _ in scheduleRender() }
        .alert("Export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .sheet(isPresented: $showingSymbolSheet) {
            IconSymbolLayerSheet(model: model)
        }
        .sheet(isPresented: $showingMonogramSheet) {
            IconMonogramLayerSheet(model: model)
        }
    }

    var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "app.badge")
                .font(.title3)
            Text(model.package.name).font(.headline)

            HStack(spacing: 2) {
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!model.canUndo)
                    .help("Undo")
                Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!model.canRedo)
                    .help("Redo")
            }
            .controlSize(.small)

            Menu("Templates") {
                ForEach(["Swift Prism", "Developer Terminal", "AI Sparkle Glass", "Shield Security"], id: \.self) { t in
                    Button(t) { model.applyStarterTemplate(t) }
                }
            }
            .controlSize(.small)
            .fixedSize()

            Spacer()
            Picker("Platform", selection: $model.selectedPlatform) {
                Text("iOS").tag(IconPlatform.iOS)
                Text("macOS").tag(IconPlatform.macOS)
                Text("watchOS").tag(IconPlatform.watchOS)
            }
            .pickerStyle(.segmented)
            .frame(width: 175)
            Picker("Appearance", selection: $model.selectedAppearance) {
                Text("Light").tag(IconAppearance.light)
                Text("Dark").tag(IconAppearance.dark)
                Text("Tinted").tag(IconAppearance.tinted)
            }
            .pickerStyle(.segmented)
            .frame(width: 175)

            Menu("Export") {
                Button("Export to .appiconset") { export() }
                    .disabled(model.appIconSetURL == nil)
                Divider()
                Button("Export 1024×1024 PNG…") { exportStandalonePNG() }
                Button("Export macOS .icns…") { exportStandaloneICNS() }
                Divider()
                Button("Save .icon Package") { model.save() }
            }
            .buttonStyle(.borderedProminent)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    var layersPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Layers").font(.headline)
                Spacer()
                Button { showingSymbolSheet = true } label: {
                    Image(systemName: "sparkles")
                }
                .buttonStyle(.borderless)
                .help("Add SF Symbol Layer")

                Button { showingMonogramSheet = true } label: {
                    Image(systemName: "textformat")
                }
                .buttonStyle(.borderless)
                .help("Add Monogram / Text Layer")

                Menu {
                    Button("Add SF Symbol Layer…") { showingSymbolSheet = true }
                    Button("Add Monogram / Badge…") { showingMonogramSheet = true }
                    Button("Add Image Layer…") { chooseImages() }
                    Menu("Add Vector Shape") {
                        ForEach(IconComposerShapes.Shape.allCases, id: \.self) { s in
                            Button(s.rawValue.replacingOccurrences(of: "-", with: " ").capitalized) {
                                model.addShapeLayer(s)
                            }
                        }
                    }
                    Divider()
                    Button("Duplicate Selected Layer") { model.duplicateSelectedLayer() }
                        .disabled(model.selectedLayer == nil)
                    Button("Add Group") { model.addGroup() }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if model.document.groups.isEmpty {
                        Text("No groups").foregroundStyle(.secondary).padding()
                    }
                    ForEach(Array(model.document.groups.enumerated()), id: \.offset) { gi, group in
                        groupRow(gi, group)
                    }
                }
                .padding(.vertical, 6)
            }
            Divider()
            HStack {
                Text(model.appIconSetURL?.lastPathComponent ?? "No export target").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Button("Choose Set…") { chooseAppIconSet() }
                    .controlSize(.small)
            }
            .padding(8)
        }
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 320)
    }

    func groupRow(_ gi: Int, _ group: IconGroup) -> some View {
        let isGroupSelected = model.selectedLayer == nil && model.selectedGroup == gi
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: model.groupHidden(group) ? "eye.slash" : "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        model.select(group: gi)
                        model.setGroupHidden(!model.groupHidden(group))
                    }
                Text(group.name ?? "Group")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if isGroupSelected {
                    Button { model.moveSelectedGroup(by: -1) } label: { Image(systemName: "chevron.up") }
                        .controlSize(.mini).disabled(gi == 0)
                    Button { model.moveSelectedGroup(by: 1) } label: { Image(systemName: "chevron.down") }
                        .controlSize(.mini).disabled(gi == model.document.groups.count - 1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isGroupSelected ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
            .onTapGesture { model.select(group: gi) }
            .contextMenu {
                Button("Move Up") { model.select(group: gi); model.moveSelectedGroup(by: -1) }.disabled(gi == 0)
                Button("Move Down") { model.select(group: gi); model.moveSelectedGroup(by: 1) }.disabled(gi == model.document.groups.count - 1)
                Divider()
                Button("Delete Group", role: .destructive) { model.select(group: gi); model.removeSelected() }
            }
            ForEach(Array(group.layers.enumerated()), id: \.offset) { li, layer in
                layerRow(gi, li, layer)
            }
        }
    }

    func layerRow(_ gi: Int, _ li: Int, _ layer: IconLayer) -> some View {
        let selected = model.selectedGroup == gi && model.selectedLayer == li
        let name = layer.name ?? layer.imageName.value ?? "Layer \(li + 1)"
        return HStack(spacing: 6) {
            Image(systemName: model.layerHidden(layer) ? "eye.slash" : "eye")
                .font(.caption)
                .foregroundStyle(.secondary)
                .onTapGesture {
                    model.select(group: gi, layer: li)
                    model.setLayerHidden(!model.layerHidden(layer))
                }
            Image(systemName: "square.stack.3d.up.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(name).font(.callout).lineLimit(1)
            Spacer()
            Text("\(Int((model.layerOpacity(layer) * 100).rounded()))%")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.leading, 26)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(selected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onTapGesture { model.select(group: gi, layer: li) }
        .contextMenu {
            Button("Move Up") { model.select(group: gi, layer: li); model.moveSelectedLayer(by: -1) }
            Button("Move Down") { model.select(group: gi, layer: li); model.moveSelectedLayer(by: 1) }
            Divider()
            Button("Delete Layer", role: .destructive) { model.select(group: gi, layer: li); model.removeSelected() }
        }
    }

    var canvasPanel: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 24) {
                heroPreview
                IconContextPreviewStrip(model: model)
                sizesGrid
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    var heroPreview: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Spacer()
                Toggle("Grid", isOn: $showGrid).controlSize(.small).toggleStyle(.checkbox)
                Toggle("Keylines", isOn: $showKeylines).controlSize(.small).toggleStyle(.checkbox)
                Toggle("Squircle Mask", isOn: $maskSquircle).controlSize(.small).toggleStyle(.checkbox)
            }
            ZStack {
                IconCanvasDragView(model: model, image: previews.images[1024], showGrid: showGrid)
                    .frame(width: 320, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: maskSquircle ? 71.5 : 8, style: .continuous))
                if showKeylines {
                    ZStack {
                        Circle().stroke(Color.cyan.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .frame(width: 268, height: 268)
                        RoundedRectangle(cornerRadius: 56).stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                            .frame(width: 256, height: 256)
                    }
                    .allowsHitTesting(false)
                }
            }
            if let msg = model.statusMessage {
                Text(msg).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("1024 × 1024 · Drag canvas to position selected layer").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    var sizesGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon Sizes").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 14)], spacing: 14) {
                ForEach(IconComposerPreviewStore.previewSizes, id: \.pixels) { size in
                    VStack(spacing: 4) {
                        sizeThumb(size.pixels)
                        Text("\(size.pt)pt").font(.caption2).foregroundStyle(.secondary)
                        Text("\(size.pixels)px").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    func sizeThumb(_ pixels: Int) -> some View {
        Group {
            if let cg = previews.images[pixels] {
                Image(nsImage: NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)))
                    .interpolation(.high)
                    .resizable()
                    .frame(width: 56, height: 56)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1))
                    .frame(width: 56, height: 56)
                    .overlay(ProgressView().controlSize(.small))
            }
        }
    }

    @ViewBuilder
    var inspectorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if model.selectedLayer != nil {
                    layerInspector
                } else {
                    groupInspector
                }
                Divider()
                backgroundSection
            }
            .padding(14)
        }
    }

    var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Canvas Background").font(.headline)
            Picker("Preset", selection: Binding(
                get: { backgroundPreset(for: model.document.fill.resolve(model.selectedAppearance, model.selectedPlatform) ?? .automatic) },
                set: { model.setDocumentFill($0) }
            )) {
                ForEach(Self.backgroundPresets.indices, id: \.self) { i in
                    Text(Self.backgroundPresets[i].name).tag(Self.backgroundPresets[i].fill)
                }
            }
            HStack {
                ColorPicker("Start", selection: $customStartColor)
                ColorPicker("End", selection: $customEndColor)
                Button("Apply") {
                    let s = Self.iconColor(from: customStartColor)
                    let e = Self.iconColor(from: customEndColor)
                    model.recordUndo()
                    model.setDocumentFill(.linearGradient(s, e, orientation: nil))
                }
                .controlSize(.small)
            }
        }
    }

    var layerInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layer").font(.headline)
            if let gi = Optional(model.selectedGroup), let li = model.selectedLayer,
               model.document.groups.indices.contains(gi),
               model.document.groups[gi].layers.indices.contains(li) {
                let layer = model.document.groups[gi].layers[li]
                TextField("Name", text: Binding(
                    get: { layer.name ?? "" },
                    set: { model.setLayerName($0) }
                ))
                .textFieldStyle(.roundedBorder)
                inspectorRow("Opacity") {
                    Slider(value: Binding(get: { model.layerOpacity(layer) }, set: { model.setLayerOpacity($0) }), in: 0...1)
                }
                inspectorRow("Scale") {
                    Slider(value: Binding(get: { model.layerScale(layer) }, set: { model.setLayerScale($0) }), in: 0.05...3)
                }
                inspectorRow("Rotation") {
                    Slider(value: Binding(get: { model.layerRotation(layer) }, set: { model.setLayerRotation($0) }), in: -180...180)
                }
                inspectorRow("Offset X") {
                    stepperField(value: model.layerTranslation(layer).x) { model.setLayerTranslation(x: $0, y: model.layerTranslation(layer).y) }
                }
                inspectorRow("Offset Y") {
                    stepperField(value: model.layerTranslation(layer).y) { model.setLayerTranslation(x: model.layerTranslation(layer).x, y: $0) }
                }
                inspectorRow("Blur") {
                    Slider(value: Binding(get: { model.layerBlur(layer) }, set: { model.setLayerBlur($0) }), in: 0...40)
                }
                inspectorRow("Drop Shadow") {
                    Slider(value: Binding(get: { model.layerShadowRadius(layer) }, set: { model.setLayerShadowRadius($0) }), in: 0...40)
                }
                HStack {
                    Button("Center & Reset") { model.resetSelectedTransform() }
                        .controlSize(.small)
                    Button("Duplicate") { model.duplicateSelectedLayer() }
                        .controlSize(.small)
                }
                Toggle("Glass", isOn: Binding(get: { model.layerGlass(layer) }, set: { model.setLayerGlass($0) }))
                Toggle("Hidden", isOn: Binding(get: { model.layerHidden(layer) }, set: { model.setLayerHidden($0) }))
                Picker("Blend", selection: Binding(get: { model.layerBlendMode(layer) }, set: { model.setLayerBlendMode($0) })) {
                    ForEach(IconBlendMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                Picker("Fill", selection: Binding(get: { model.layerFill(layer) }, set: { model.setLayerFill($0) })) {
                    ForEach(Self.layerFillPresets.indices, id: \.self) { i in
                        Text(Self.layerFillPresets[i].name).tag(Self.layerFillPresets[i].fill)
                    }
                }
            }
        }
    }

    var groupInspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group").font(.headline)
            if model.document.groups.indices.contains(model.selectedGroup) {
                let group = model.document.groups[model.selectedGroup]
                TextField("Name", text: Binding(
                    get: { group.name ?? "" },
                    set: { model.setGroupName($0) }
                ))
                .textFieldStyle(.roundedBorder)
                inspectorRow("Opacity") {
                    Slider(value: Binding(get: { model.groupOpacity(group) }, set: { model.setGroupOpacity($0) }), in: 0...1)
                }
                inspectorRow("Scale") {
                    Slider(value: Binding(get: { model.groupScale(group) }, set: { model.setGroupScale($0) }), in: 0.05...3)
                }
                inspectorRow("Offset X") {
                    stepperField(value: model.groupTranslation(group).x) { model.setGroupTranslation(x: $0, y: model.groupTranslation(group).y) }
                }
                inspectorRow("Offset Y") {
                    stepperField(value: model.groupTranslation(group).y) { model.setGroupTranslation(x: model.groupTranslation(group).x, y: $0) }
                }
                inspectorRow("Blur Material") {
                    Slider(value: Binding(get: { model.groupBlurMaterial(group) }, set: { model.setGroupBlurMaterial($0) }), in: 0...1)
                }
                inspectorRow("Shadow") {
                    Slider(value: Binding(get: { model.groupShadowOpacity(group) }, set: { model.setGroupShadowOpacity($0) }), in: 0...1)
                }
                Toggle("Hidden", isOn: Binding(get: { model.groupHidden(group) }, set: { model.setGroupHidden($0) }))
            } else {
                Text("Select a group or layer").foregroundStyle(.secondary)
            }
        }
    }

    func inspectorRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    func stepperField(value: Double, set: @escaping (Double) -> Void) -> some View {
        HStack {
            TextField("", value: Binding(get: { value }, set: set), format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
            Slider(value: Binding(get: { value }, set: set), in: -1024...1024)
        }
    }

    static let backgroundPresets: [(name: String, fill: IconFill)] = [
        ("Automatic", .automatic),
        ("Light", .systemLight),
        ("Dark", .systemDark),
        ("White", .solid(IconColor.srgb(1, 1, 1))),
        ("Graphite", .solid(IconColor.srgb(0.16, 0.16, 0.18))),
        ("Ocean", .linearGradient(IconColor.srgb(0.05, 0.35, 0.85), IconColor.srgb(0.15, 0.75, 0.95), orientation: nil)),
        ("Sunset", .linearGradient(IconColor.srgb(0.95, 0.35, 0.25), IconColor.srgb(0.95, 0.75, 0.25), orientation: nil)),
        ("Iris", .linearGradient(IconColor.srgb(0.35, 0.2, 0.85), IconColor.srgb(0.85, 0.35, 0.75), orientation: nil)),
    ]

    static let layerFillPresets: [(name: String, fill: IconFill)] = [
        ("Artwork", .automatic),
        ("None", .none),
        ("White", .solid(IconColor.srgb(1, 1, 1))),
        ("Black", .solid(IconColor.srgb(0.05, 0.05, 0.06))),
        ("Accent", .solid(IconColor.srgb(0.1, 0.45, 0.95))),
        ("Ocean Gradient", .linearGradient(IconColor.srgb(0.05, 0.35, 0.85), IconColor.srgb(0.15, 0.75, 0.95), orientation: nil)),
    ]

    func backgroundPreset(for fill: IconFill) -> IconFill {
        for p in Self.backgroundPresets where p.fill == fill { return p.fill }
        return .automatic
    }

    func chooseImages() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { model.addImageLayer(url) }
    }

    func chooseAppIconSet() {
        guard let url = model.chooseAppIconSet() else { return }
        model.attach(appIconSet: url)
    }

    static func iconColor(from color: Color) -> IconColor {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return IconColor.srgb(Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent))
    }

    func exportStandalonePNG() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(model.package.name)-1024.png"
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let cg = IconComposerRenderer.render(
            document: model.document, package: model.package,
            appearance: model.selectedAppearance, platform: model.selectedPlatform,
            pixels: 1024, mask: maskSquircle ? .squircle : .none
        ), let data = IconComposerRenderer.pngData(cg) {
            try? data.write(to: url)
        }
    }

    func exportStandaloneICNS() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(model.package.name).icns"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try IconComposerAssetGenerator.exportICNS(model: model, destination: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    func export() {
        let files = model.exportToAppIconSet()
        if files.isEmpty, model.statusMessage?.hasPrefix("Export") != true {
            exportError = model.statusMessage ?? "Export produced no files"
        }
    }

    func scheduleRender() {
        previews.schedule(document: model.document, package: model.package,
                          appearance: model.selectedAppearance, platform: model.selectedPlatform)
    }
}

struct IconCanvasDragView: NSViewRepresentable {
    var model: IconComposerModel
    var image: CGImage?
    var showGrid: Bool = true

    func makeNSView(context: Context) -> IconCanvasNSView {
        let v = IconCanvasNSView()
        v.model = model
        return v
    }

    func updateNSView(_ nsView: IconCanvasNSView, context: Context) {
        nsView.model = model
        nsView.image = image
        nsView.showGrid = showGrid
        nsView.needsDisplay = true
    }
}

final class IconCanvasNSView: NSView {
    var model: IconComposerModel?
    var image: CGImage?
    var showGrid = true
    private var dragStart: CGPoint?
    private var translationStart = IconPoint(x: 0, y: 0)

    override var isFlipped: Bool { true }

    var imageRect: CGRect {
        guard let image, image.width > 0, image.height > 0, bounds.width > 0 else { return .zero }
        let scale = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
        let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
        return CGRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        guard let image else {
            let p = NSBezierPath(roundedRect: imageRect.isEmpty ? bounds.insetBy(dx: 8, dy: 8) : imageRect,
                                 xRadius: 12, yRadius: 12)
            p.setLineDash([5, 4], count: 2, phase: 0)
            NSColor.tertiaryLabelColor.setStroke()
            p.stroke()
            return
        }
        let rect = imageRect
        if showGrid {
            NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
            let path = NSBezierPath()
            for i in 1..<4 {
                let x = rect.minX + rect.width * CGFloat(i) / 4
                let y = rect.minY + rect.height * CGFloat(i) / 4
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.line(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.line(to: CGPoint(x: rect.maxX, y: y))
            }
            path.lineWidth = 0.5
            path.stroke()
        }
        if let cg = NSGraphicsContext.current?.cgContext {
            cg.saveGState()
            cg.clip(to: rect)
            cg.translateBy(x: rect.midX, y: rect.midY)
            cg.scaleBy(x: 1, y: -1)
            cg.interpolationQuality = .high
            cg.draw(image, in: CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height))
            cg.restoreGState()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard model?.selectedLayer != nil else { return }
        dragStart = convert(event.locationInWindow, from: nil)
        if let m = model, let li = m.selectedLayer {
            let gi = m.selectedGroup
            guard m.document.groups.indices.contains(gi), m.document.groups[gi].layers.indices.contains(li) else { return }
            translationStart = m.layerTranslation(m.document.groups[gi].layers[li])
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let model else { return }
        let rect = imageRect
        guard rect.width > 0 else { return }
        let current = convert(event.locationInWindow, from: nil)
        let scale = rect.width / 1024
        let dx = Double((current.x - start.x) / scale)
        let dy = Double((current.y - start.y) / scale)
        model.setLayerTranslation(x: translationStart.x + dx, y: translationStart.y + dy)
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }
}
