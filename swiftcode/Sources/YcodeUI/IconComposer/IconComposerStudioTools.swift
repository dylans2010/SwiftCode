import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import YcodeIcon

@MainActor
public enum IconComposerAssetGenerator {
    public static func renderSFSymbol(
        symbolName: String,
        weight: NSFont.Weight = .semibold,
        color: NSColor = .white,
        pixels: Int = 768
    ) -> CGImage? {
        let config = NSImage.SymbolConfiguration(pointSize: CGFloat(pixels) * 0.58, weight: weight)
        guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let size = base.size
        let scale = min(CGFloat(pixels) * 0.78 / max(size.width, 1), CGFloat(pixels) * 0.78 / max(size.height, 1))
        let drawW = size.width * scale
        let drawH = size.height * scale
        let drawRect = NSRect(x: (CGFloat(pixels) - drawW) / 2, y: (CGFloat(pixels) - drawH) / 2, width: drawW, height: drawH)
        base.draw(in: drawRect)
        color.set()
        NSRect(x: 0, y: 0, width: pixels, height: pixels).fill(using: .sourceIn)
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    public static func renderMonogram(
        text: String,
        design: NSFontDescriptor.SystemDesign = .rounded,
        weight: NSFont.Weight = .bold,
        color: NSColor = .white,
        pixels: Int = 768
    ) -> CGImage? {
        let trimmed = String(text.prefix(4))
        guard !trimmed.isEmpty else { return nil }
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ptSize = CGFloat(pixels) * (trimmed.count == 1 ? 0.54 : (trimmed.count == 2 ? 0.42 : 0.30))
        let sysFont = NSFont.systemFont(ofSize: ptSize, weight: weight)
        let font = sysFont.fontDescriptor.withDesign(design).flatMap { NSFont(descriptor: $0, size: ptSize) } ?? sysFont
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let str = NSAttributedString(string: trimmed, attributes: attrs)
        let sz = str.size()
        let origin = NSPoint(x: (CGFloat(pixels) - sz.width) / 2, y: (CGFloat(pixels) - sz.height) / 2)
        str.draw(at: origin)
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    public static func exportICNS(model: IconComposerModel, destination: URL) throws {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("swiftcode-icns-\(UUID().uuidString)", isDirectory: true)
        let iconset = tempRoot.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let specs: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]
        for (filename, px) in specs {
            if let cg = IconComposerRenderer.render(
                document: model.document,
                package: model.package,
                appearance: model.selectedAppearance,
                platform: .macOS,
                pixels: px,
                mask: .squircle
            ), let data = IconComposerRenderer.pngData(cg) {
                try data.write(to: iconset.appendingPathComponent(filename))
            }
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        proc.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            throw NSError(domain: "IconComposer", code: Int(proc.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "iconutil exited with status \(proc.terminationStatus)"])
        }
    }
}

public struct IconSymbolLayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: IconComposerModel
    @State private var symbolName = "sparkles"
    @State private var color = Color.white
    @State private var weightIndex = 5

    private let curatedSymbols = [
        "sparkles", "swift", "terminal.fill", "hammer.fill", "bolt.fill", "cube.transparent.fill",
        "cpu.fill", "wand.and.stars", "shield.lefthalf.filled", "paintbrush.pointed.fill",
        "curlybraces", "waveform.path.ecg", "globe.americas.fill", "camera.aperture",
        "brain.head.profile", "gamecontroller.fill", "paperplane.fill", "flame.fill",
        "lock.shield.fill", "chart.bar.xaxis", "music.quarternote.3", "atom",
    ]
    private let weights: [(String, NSFont.Weight)] = [
        ("Light", .light), ("Regular", .regular), ("Medium", .medium),
        ("Semibold", .semibold), ("Bold", .bold), ("Heavy", .heavy),
    ]

    public init(model: IconComposerModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Add SF Symbol Layer", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }

            HStack(spacing: 10) {
                TextField("SF Symbol name (e.g. terminal.fill)…", text: $symbolName)
                    .textFieldStyle(.roundedBorder)
                Picker("Weight", selection: $weightIndex) {
                    ForEach(weights.indices, id: \.self) { i in
                        Text(weights[i].0).tag(i)
                    }
                }
                .frame(width: 140)
                ColorPicker("Tint", selection: $color)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                ForEach(curatedSymbols, id: \.self) { sym in
                    Button {
                        symbolName = sym
                    } label: {
                        Image(systemName: sym)
                            .font(.system(size: 18))
                            .frame(width: 40, height: 40)
                            .background(symbolName == sym ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Add Symbol Layer") {
                    model.addSFSymbolLayer(
                        symbolName: symbolName.trimmingCharacters(in: .whitespaces),
                        weight: weights[min(max(0, weightIndex), weights.count - 1)].1,
                        color: NSColor(color)
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 500)
    }
}

public struct IconMonogramLayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: IconComposerModel
    @State private var text = "SC"
    @State private var designIndex = 1
    @State private var color = Color.white

    private let designs: [(String, NSFontDescriptor.SystemDesign)] = [
        ("Default", .default),
        ("Rounded", .rounded),
        ("Monospaced", .monospaced),
        ("Serif", .serif),
    ]

    public init(model: IconComposerModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Add Monogram / Badge Layer", systemImage: "textformat")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            HStack(spacing: 10) {
                TextField("1–4 characters (e.g. SC, { }, ⌘)…", text: $text)
                    .textFieldStyle(.roundedBorder)
                Picker("Font", selection: $designIndex) {
                    ForEach(designs.indices, id: \.self) { i in
                        Text(designs[i].0).tag(i)
                    }
                }
                .frame(width: 150)
                ColorPicker("Color", selection: $color)
            }
            HStack {
                Spacer()
                Button("Add Monogram Layer") {
                    model.addMonogramLayer(
                        text: text,
                        design: designs[min(max(0, designIndex), designs.count - 1)].1,
                        color: NSColor(color)
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 460)
    }
}

public struct IconContextPreviewStrip: View {
    @ObservedObject var model: IconComposerModel
    @State private var lightCG: CGImage?
    @State private var darkCG: CGImage?
    @State private var tintedCG: CGImage?
    @State private var watchCG: CGImage?

    public init(model: IconComposerModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance & Platform Contexts").font(.headline)
            HStack(spacing: 18) {
                contextCard("Light Squircle", cg: lightCG, bg: Color.white.opacity(0.85))
                contextCard("Dark Squircle", cg: darkCG, bg: Color(red: 0.11, green: 0.11, blue: 0.13))
                contextCard("Tinted Glass", cg: tintedCG, bg: Color(red: 0.14, green: 0.16, blue: 0.24))
                contextCard("watchOS / Spatial", cg: watchCG, bg: Color.black)
            }
        }
        .onAppear { refresh() }
        .onChange(of: model.revision) { _, _ in refresh() }
    }

    private func contextCard(_ title: String, cg: CGImage?, bg: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(bg)
                    .frame(width: 96, height: 96)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                if let cg {
                    Image(nsImage: NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 68, height: 68)
                        .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
                }
            }
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func refresh() {
        let doc = model.document
        let pkg = model.package
        Task.detached(priority: .utility) {
            let l = IconComposerRenderer.render(document: doc, package: pkg, appearance: .light, platform: .iOS, pixels: 192, mask: .squircle)
            let d = IconComposerRenderer.render(document: doc, package: pkg, appearance: .dark, platform: .iOS, pixels: 192, mask: .squircle)
            let t = IconComposerRenderer.render(document: doc, package: pkg, appearance: .tinted, platform: .iOS, pixels: 192, mask: .squircle)
            let w = IconComposerRenderer.render(document: doc, package: pkg, appearance: .dark, platform: .watchOS, pixels: 192, mask: .circle)
            await MainActor.run {
                lightCG = l; darkCG = d; tintedCG = t; watchCG = w
            }
        }
    }
}
