import AppKit
import SwiftUI

public struct VisualUIAuditFinding: Identifiable {
    public enum Severity: String { case error = "Critical", warning = "Warning", pass = "Info" }
    public let id = UUID()
    public let nodeID: UUID
    public let nodeName: String
    public let severity: Severity
    public let title: String
    public let detail: String
    public let fixTitle: String?
    public let applyFix: (@MainActor () -> Void)?
}

@MainActor
public enum VisualUIAccessibilityAuditor {
    public static func relativeLuminance(hex: String) -> Double? {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let val = UInt64(clean, radix: 16) else { return nil }
        func channel(_ c: UInt64) -> Double {
            let s = Double(c) / 255.0
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        let r = channel((val >> 16) & 0xFF)
        let g = channel((val >> 8) & 0xFF)
        let b = channel(val & 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    public static func contrastRatio(_ hexA: String, _ hexB: String) -> Double? {
        guard let l1 = relativeLuminance(hex: hexA), let l2 = relativeLuminance(hex: hexB) else { return nil }
        let lighter = max(l1, l2), darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public static func audit(document: VisualUIDocument, isDarkMode: Bool) -> [VisualUIAuditFinding] {
        guard let artboard = document.scene.artboards.first(where: { $0.id == document.scene.activeArtboardID })
                ?? document.scene.artboards.first else { return [] }
        let fallbackBG = isDarkMode ? "#1C1C1E" : "#FFFFFF"
        var findings: [VisualUIAuditFinding] = []

        func walk(_ node: VisualComponentNode, inheritedBG: String, depth: Int) {
            guard !node.isHidden else { return }
            let bg = node.properties["backgroundColor"] ?? inheritedBG

            if let fg = node.properties["foregroundColor"], let ratio = contrastRatio(fg, bg), ratio < 4.5 {
                let targetHex = (relativeLuminance(hex: bg) ?? 1.0) > 0.45 ? "#111827" : "#F9FAFB"
                findings.append(VisualUIAuditFinding(
                    nodeID: node.id, nodeName: node.name,
                    severity: ratio < 3.0 ? .error : .warning,
                    title: String(format: "Low Contrast %.2f:1 (WCAG AA requires 4.5:1)", ratio),
                    detail: "Foreground \(fg) against \(bg) is difficult to read.",
                    fixTitle: "Fix Contrast",
                    applyFix: {
                        document.checkpoint()
                        node.properties["foregroundColor"] = targetHex
                    }
                ))
            }

            let interactive: Set<VisualComponentType> = [.button, .toggle, .slider, .stepper, .picker, .shareLink]
            if interactive.contains(node.type) {
                let w = node.properties["width"].flatMap(Double.init)
                let h = node.properties["height"].flatMap(Double.init)
                if (w != nil && w! < 44) || (h != nil && h! < 44) {
                    findings.append(VisualUIAuditFinding(
                        nodeID: node.id, nodeName: node.name,
                        severity: .warning,
                        title: "Hit Target Smaller Than 44×44 pt",
                        detail: "Apple Human Interface Guidelines recommend at least 44×44 pt for touch and pointer targets.",
                        fixTitle: "Expand to 44pt",
                        applyFix: {
                            document.checkpoint()
                            if let w, w < 44 { node.properties["width"] = "44" }
                            if let h, h < 44 { node.properties["height"] = "44" }
                        }
                    ))
                }
            }

            let needsLabel: Set<VisualComponentType> = [.image, .asyncImage, .sfSymbol, .button]
            if needsLabel.contains(node.type),
               (node.properties["accessibilityLabel"] ?? "").isEmpty,
               (node.properties["textValue"] ?? "").isEmpty {
                findings.append(VisualUIAuditFinding(
                    nodeID: node.id, nodeName: node.name,
                    severity: .warning,
                    title: "Missing VoiceOver Accessibility Label",
                    detail: "\(node.type.rawValue) '\(node.name)' has no text or accessibilityLabel.",
                    fixTitle: "Set Label",
                    applyFix: {
                        document.checkpoint()
                        node.properties["accessibilityLabel"] = node.name
                    }
                ))
            }

            if depth > 7 {
                findings.append(VisualUIAuditFinding(
                    nodeID: node.id, nodeName: node.name,
                    severity: .pass,
                    title: "Deep View Nesting (Depth \(depth))",
                    detail: "Consider extracting subviews to keep layout passes fast.",
                    fixTitle: nil, applyFix: nil
                ))
            }

            for child in node.children { walk(child, inheritedBG: bg, depth: depth + 1) }
        }

        walk(artboard.rootNode, inheritedBG: fallbackBG, depth: 0)
        return findings
    }
}

public struct VisualUIAccessibilityAuditView: View {
    @Bindable var document: VisualUIDocument
    @State private var settings = VisualUISettings.shared

    public init(document: VisualUIDocument) {
        self.document = document
    }

    public var body: some View {
        let findings = VisualUIAccessibilityAuditor.audit(document: document, isDarkMode: settings.isDarkMode)
        let score = max(0, 100 - findings.reduce(0) { $0 + ($1.severity == .error ? 20 : ($1.severity == .warning ? 10 : 3)) })

        VStack(spacing: 0) {
            HStack {
                Label("Accessibility & HIG Audit", systemImage: "figure.roll")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Score \(score)/100")
                    .font(.caption.monospacedDigit().bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((score >= 85 ? Color.green : Color.orange).opacity(0.16), in: Capsule())
                    .foregroundStyle(score >= 85 ? .green : .orange)
            }
            .padding(10)

            Divider()

            if findings.isEmpty {
                ContentUnavailableView(
                    "All Checks Passed",
                    systemImage: "checkmark.seal.fill",
                    description: Text("Contrast ratios, 44pt hit targets, and VoiceOver labels meet HIG recommendations.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        let fixable = findings.filter { $0.applyFix != nil }
                        if !fixable.isEmpty {
                            Button {
                                for f in fixable { f.applyFix?() }
                            } label: {
                                Label("Auto-Fix All (\(fixable.count))", systemImage: "wand.and.stars")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        ForEach(findings) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: item.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(item.severity == .error ? .red : .orange)
                                    Text(item.title)
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                }
                                Text("\(item.nodeName) — \(item.detail)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Button("Select") {
                                        document.scene.selectedNodeIDs = [item.nodeID]
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)

                                    if let fixTitle = item.fixTitle, let fix = item.applyFix {
                                        Button(fixTitle) { fix() }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.mini)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(10)
                }
            }
        }
    }
}

@MainActor
public enum VisualUISceneMutator {
    public static func parent(of targetID: UUID, in root: VisualComponentNode) -> VisualComponentNode? {
        for child in root.children {
            if child.id == targetID { return root }
            if let found = parent(of: targetID, in: child) { return found }
        }
        return nil
    }

    public static func activeRoot(in document: VisualUIDocument) -> VisualComponentNode? {
        (document.scene.artboards.first { $0.id == document.scene.activeArtboardID } ?? document.scene.artboards.first)?.rootNode
    }

    public static func wrapSelected(in containerType: VisualComponentType, document: VisualUIDocument) {
        guard let selectedID = document.scene.selectedNodeIDs.first,
              let root = activeRoot(in: document),
              let parentNode = parent(of: selectedID, in: root),
              let idx = parentNode.children.firstIndex(where: { $0.id == selectedID }) else { return }
        document.checkpoint()
        let child = parentNode.children[idx]
        let wrapper = VisualComponentNode(type: containerType, name: containerType.rawValue, children: [child], properties: ["spacing": "8", "padding": "8"])
        parentNode.children[idx] = wrapper
        document.scene.selectedNodeIDs = [wrapper.id]
    }

    public static func duplicateSelected(document: VisualUIDocument) {
        guard let selectedID = document.scene.selectedNodeIDs.first,
              let root = activeRoot(in: document),
              let parentNode = parent(of: selectedID, in: root),
              let idx = parentNode.children.firstIndex(where: { $0.id == selectedID }) else { return }
        document.checkpoint()
        let clone = deepClone(parentNode.children[idx])
        clone.name += " Copy"
        parentNode.children.insert(clone, at: idx + 1)
        document.scene.selectedNodeIDs = [clone.id]
    }

    public static func moveSelected(delta: Int, document: VisualUIDocument) {
        guard let selectedID = document.scene.selectedNodeIDs.first,
              let root = activeRoot(in: document),
              let parentNode = parent(of: selectedID, in: root),
              let idx = parentNode.children.firstIndex(where: { $0.id == selectedID }) else { return }
        let target = idx + delta
        guard parentNode.children.indices.contains(target) else { return }
        document.checkpoint()
        parentNode.children.swapAt(idx, target)
    }

    public static func deleteSelected(document: VisualUIDocument) {
        guard let selectedID = document.scene.selectedNodeIDs.first,
              let root = activeRoot(in: document),
              let parentNode = parent(of: selectedID, in: root) else { return }
        document.checkpoint()
        parentNode.children.removeAll { $0.id == selectedID }
        document.scene.selectedNodeIDs.removeAll()
    }

    public static func applyStylePreset(_ preset: String, to node: VisualComponentNode, document: VisualUIDocument) {
        document.checkpoint()
        switch preset {
        case "Glass Card":
            node.properties["padding"] = "16"
            node.properties["cornerRadius"] = "16"
            node.properties["materialTheme"] = "Regular"
            node.properties["shadowRadius"] = "8"
            node.properties["borderWidth"] = "1"
        case "Primary Button":
            node.properties["padding"] = "12"
            node.properties["cornerRadius"] = "12"
            node.properties["backgroundColor"] = "#007AFF"
            node.properties["foregroundColor"] = "#FFFFFF"
            node.properties["fontPreset"] = "Headline"
        case "Hero Title":
            node.properties["fontPreset"] = "Large Title"
            node.properties["padding"] = "8"
        case "Subtle Pill":
            node.properties["padding"] = "6"
            node.properties["cornerRadius"] = "99"
            node.properties["backgroundColor"] = "#E5E7EB"
            node.properties["foregroundColor"] = "#1F2937"
            node.properties["fontPreset"] = "Footnote"
        case "Surface Box":
            node.properties["padding"] = "14"
            node.properties["cornerRadius"] = "12"
            node.properties["backgroundColor"] = "#F3F4F6"
            node.properties["borderWidth"] = "1"
        default: break
        }
    }

    private static func deepClone(_ node: VisualComponentNode) -> VisualComponentNode {
        VisualComponentNode(
            type: node.type,
            name: node.name,
            children: node.children.map(deepClone),
            properties: node.properties,
            isLocked: node.isLocked,
            isHidden: node.isHidden
        )
    }
}

public struct VisualUICanvasQuickToolsBar: View {
    @Bindable var document: VisualUIDocument
    @Bindable var settings: VisualUISettings

    public init(document: VisualUIDocument, settings: VisualUISettings) {
        self.document = document
        self.settings = settings
    }

    public var body: some View {
        let selectedNode = document.scene.selectedNodeIDs.first.flatMap { document.scene.findNode(byID: $0) }

        HStack(spacing: 8) {
            Menu {
                ForEach([VisualComponentType.text, .button, .label, .sfSymbol, .textField, .toggle, .slider, .vStack, .hStack, .zStack, .groupBox, .divider, .spacer], id: \.self) { t in
                    Button {
                        insertComponent(t)
                    } label: {
                        Label(t.rawValue, systemImage: t.systemIcon)
                    }
                }
            } label: {
                Label("Insert", systemImage: "plus.square.on.square")
                    .font(.caption.weight(.medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Divider().frame(height: 14)

            if let node = selectedNode {
                Menu {
                    Button("Wrap in VStack") { VisualUISceneMutator.wrapSelected(in: .vStack, document: document) }
                    Button("Wrap in HStack") { VisualUISceneMutator.wrapSelected(in: .hStack, document: document) }
                    Button("Wrap in ZStack") { VisualUISceneMutator.wrapSelected(in: .zStack, document: document) }
                    Button("Wrap in ScrollView") { VisualUISceneMutator.wrapSelected(in: .scrollView, document: document) }
                    Button("Wrap in GroupBox") { VisualUISceneMutator.wrapSelected(in: .groupBox, document: document) }
                } label: {
                    Label("Embed", systemImage: "square.on.square.dashed")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Menu {
                    ForEach(["Glass Card", "Primary Button", "Hero Title", "Subtle Pill", "Surface Box"], id: \.self) { p in
                        Button(p) { VisualUISceneMutator.applyStylePreset(p, to: node, document: document) }
                    }
                } label: {
                    Label("Preset", systemImage: "paintbrush")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button { VisualUISceneMutator.moveSelected(delta: -1, document: document) } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.plain)
                .help("Move Earlier in Parent")

                Button { VisualUISceneMutator.moveSelected(delta: 1, document: document) } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.plain)
                .help("Move Later in Parent")

                Button { VisualUISceneMutator.duplicateSelected(document: document) } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Duplicate Selected Node")

                Button {
                    document.checkpoint()
                    node.isHidden.toggle()
                } label: {
                    Image(systemName: node.isHidden ? "eye.slash.fill" : "eye")
                }
                .buttonStyle(.plain)
                .help("Toggle Visibility")

                Button { VisualUISceneMutator.deleteSelected(document: document) } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Delete Node")

                Divider().frame(height: 14)
            }

            Button {
                settings.showWireframeBounds.toggle()
            } label: {
                Image(systemName: "square.dashed")
                    .foregroundStyle(settings.showWireframeBounds ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Wireframe X-Ray Outlines")

            Button {
                settings.showRulers.toggle()
            } label: {
                Image(systemName: "ruler")
                    .foregroundStyle(settings.showRulers ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Canvas Rulers")

            Button {
                settings.showLiveCodeSplit.toggle()
            } label: {
                Image(systemName: "curlybraces.square")
                    .foregroundStyle(settings.showLiveCodeSplit ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Live Generated Code Dock")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
    }

    private func insertComponent(_ type: VisualComponentType) {
        guard let root = VisualUISceneMutator.activeRoot(in: document) else { return }
        document.checkpoint()
        var props: [String: String] = ["padding": "6"]
        if type == .text || type == .button || type == .label || type == .toggle || type == .textField {
            props["textValue"] = type.rawValue
        }
        if type == .sfSymbol || type == .label {
            props["sfSymbolName"] = "star.fill"
        }
        let newNode = VisualComponentNode(type: type, properties: props)
        if let selectedID = document.scene.selectedNodeIDs.first,
           let selected = document.scene.findNode(byID: selectedID),
           [.vStack, .hStack, .zStack, .scrollView, .groupBox, .list, .form].contains(selected.type) {
            selected.children.append(newNode)
        } else {
            root.children.append(newNode)
        }
        document.scene.selectedNodeIDs = [newNode.id]
        settings.addToRecentlyUsed(type)
    }
}

public struct VisualUICanvasRulersOverlay: View {
    let scale: Double

    public init(scale: Double) {
        self.scale = scale
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    let step = max(25.0, 50.0 * scale)
                    var x = 20.0
                    while x < size.width {
                        var tick = Path()
                        tick.move(to: CGPoint(x: x, y: 0))
                        tick.addLine(to: CGPoint(x: x, y: Int(x) % 100 == 0 ? 14 : 7))
                        context.stroke(tick, with: .color(.secondary.opacity(0.45)), lineWidth: 1)
                        x += step
                    }
                    var y = 20.0
                    while y < size.height {
                        var tick = Path()
                        tick.move(to: CGPoint(x: 0, y: y))
                        tick.addLine(to: CGPoint(x: Int(y) % 100 == 0 ? 14 : 7, y: y))
                        context.stroke(tick, with: .color(.secondary.opacity(0.45)), lineWidth: 1)
                        y += step
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}

public struct VisualUIResponsiveMatrixView: View {
    @Bindable var document: VisualUIDocument
    @Bindable var settings: VisualUISettings
    @State private var dynamicScale: DynamicTypeSize = .large

    private struct ViewportSpec: Identifiable {
        var id: String { title }
        let title: String
        let width: CGFloat
        let height: CGFloat
        let dark: Bool
    }

    private let viewports: [ViewportSpec] = [
        .init(title: "iPhone SE · Light", width: 320, height: 568, dark: false),
        .init(title: "iPhone 16 Pro · Light", width: 393, height: 760, dark: false),
        .init(title: "iPhone 16 Pro · Dark", width: 393, height: 760, dark: true),
        .init(title: "iPad Compact · Split", width: 520, height: 720, dark: false),
        .init(title: "Apple Watch · Dark", width: 210, height: 252, dark: true),
    ]

    public init(document: VisualUIDocument, settings: VisualUISettings) {
        self.document = document
        self.settings = settings
    }

    public var body: some View {
        let artboard = document.scene.artboards.first { $0.id == document.scene.activeArtboardID } ?? document.scene.artboards.first

        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Label("Responsive Multi-Device Matrix", systemImage: "rectangle.3.group")
                    .font(.subheadline.weight(.semibold))

                Picker("Pseudo-Locale", selection: $settings.pseudoLocaleMode) {
                    Text("Standard").tag("Standard")
                    Text("Expanded (+35%)").tag("Expanded")
                    Text("Accented").tag("Accented")
                    Text("UPPERCASE").tag("UPPERCASE")
                }
                .controlSize(.small)
                .frame(width: 210)

                Picker("Dynamic Type", selection: $dynamicScale) {
                    Text("Small").tag(DynamicTypeSize.small)
                    Text("Default").tag(DynamicTypeSize.large)
                    Text("XXLarge").tag(DynamicTypeSize.xxLarge)
                    Text("AX2").tag(DynamicTypeSize.accessibility2)
                }
                .controlSize(.small)
                .frame(width: 185)

                Spacer()

                Button("Return to Canvas") {
                    settings.showResponsiveMatrix = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView([.horizontal, .vertical]) {
                if let artboard {
                    HStack(alignment: .top, spacing: 28) {
                        ForEach(viewports) { vp in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(vp.title)
                                        .font(.caption.weight(.semibold))
                                    Spacer()
                                    Text("\(Int(vp.width))×\(Int(vp.height))")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                VisualUIRenderer(rootNode: pseudoLocalizedRoot(artboard.rootNode), document: document)
                                    .environment(\.colorScheme, vp.dark ? .dark : .light)
                                    .environment(\.dynamicTypeSize, dynamicScale)
                                    .frame(width: vp.width, height: vp.height)
                                    .background(vp.dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.secondary.opacity(0.28), lineWidth: 1.5))
                                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                            }
                        }
                    }
                    .padding(28)
                }
            }
        }
    }

    private func pseudoLocalizedRoot(_ node: VisualComponentNode) -> VisualComponentNode {
        guard settings.pseudoLocaleMode != "Standard" else { return node }
        var props = node.properties
        if let text = props["textValue"], !text.isEmpty {
            switch settings.pseudoLocaleMode {
            case "Expanded": props["textValue"] = "[\(text) — erweiterte Zeichenkette]"
            case "Accented":
                let map: [Character: Character] = ["a": "å", "e": "ë", "i": "ï", "o": "ø", "u": "ü", "A": "Å", "E": "Ë"]
                props["textValue"] = String(text.map { map[$0] ?? $0 })
            case "UPPERCASE": props["textValue"] = text.uppercased()
            default: break
            }
        }
        return VisualComponentNode(id: node.id, type: node.type, name: node.name,
                                   children: node.children.map(pseudoLocalizedRoot),
                                   properties: props, isLocked: node.isLocked, isHidden: node.isHidden)
    }
}

public struct VisualUIPrototypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var document: VisualUIDocument
    @State private var isLandscape = false
    @State private var dark = false
    @State private var statusText = ""

    public init(document: VisualUIDocument) {
        self.document = document
    }

    public var body: some View {
        let artboard = document.scene.artboards.first { $0.id == document.scene.activeArtboardID } ?? document.scene.artboards.first
        let w: CGFloat = isLandscape ? 680 : 375
        let h: CGFloat = isLandscape ? 360 : 660

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("Interactive Prototype Player", systemImage: "play.rectangle.fill")
                    .font(.headline)
                Spacer()
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button { isLandscape.toggle() } label: {
                    Label("Rotate", systemImage: "rotate.right")
                }
                .controlSize(.small)
                Toggle("Dark", isOn: $dark)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Button {
                    if let artboard { exportPNG(artboard: artboard, size: CGSize(width: w, height: h)) }
                } label: {
                    Label("Save PNG…", systemImage: "camera")
                }
                .controlSize(.small)
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ZStack {
                Color.black.opacity(0.05)
                if let artboard {
                    VisualUIRenderer(rootNode: artboard.rootNode, document: document)
                        .environment(\.colorScheme, dark ? .dark : .light)
                        .frame(width: w, height: h)
                        .background(dark ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 34))
                        .overlay(RoundedRectangle(cornerRadius: 34).stroke(Color.primary.opacity(0.25), lineWidth: 4))
                        .shadow(radius: 18)
                        .padding(24)
                }
            }
        }
        .frame(width: 820, height: 780)
    }

    @MainActor
    private func exportPNG(artboard: VisualUIArtboard, size: CGSize) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(artboard.name.replacingOccurrences(of: " ", with: "-")).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let view = VisualUIRenderer(rootNode: artboard.rootNode, document: document)
            .environment(\.colorScheme, dark ? .dark : .light)
            .frame(width: size.width, height: size.height)
            .background(dark ? Color.black : Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        if let nsImage = renderer.nsImage,
           let tiff = nsImage.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
            statusText = "Saved \(url.lastPathComponent)"
        }
    }
}
