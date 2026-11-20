import AppKit
import SwiftUI

@MainActor
public enum VisualUICodeGenerator {
    public static func generate(document: VisualUIDocument, framework: VisualUIFramework? = nil) -> String {
        let target = framework ?? document.scene.currentFramework
        let artboard = document.scene.artboards.first { $0.id == document.scene.activeArtboardID }
            ?? document.scene.artboards.first
        guard let artboard else {
            return "import SwiftUI\n\nstruct GeneratedView: View {\n    var body: some View {\n        EmptyView()\n    }\n}\n"
        }
        let typeName = sanitizedTypeName(artboard.name)
        switch target {
        case .swiftUI:
            return generateSwiftUI(artboard: artboard, typeName: typeName)
        case .appKit:
            return generateAppKit(artboard: artboard, typeName: typeName)
        case .uiKit:
            return generateUIKit(artboard: artboard, typeName: typeName)
        case .widgetKit:
            return generateWidgetKit(artboard: artboard, typeName: typeName)
        case .visionOS:
            return generateVisionOS(artboard: artboard, typeName: typeName)
        case .watchOS:
            return generateWatchOS(artboard: artboard, typeName: typeName)
        }
    }

    public static func sanitizedTypeName(_ raw: String) -> String {
        let parts = raw.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let joined = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        if joined.isEmpty { return "CanvasScreen" }
        let clean = joined.first?.isNumber == true ? "Screen" + joined : joined
        return clean.hasSuffix("View") ? String(clean.dropLast(4)) : clean
    }

    private static func stateDeclarations(root: VisualComponentNode, indent: String = "    ") -> [String] {
        var lines: [String] = []
        if let raw = root.properties["declaredStates"], !raw.isEmpty {
            for entry in raw.components(separatedBy: ";") where !entry.isEmpty {
                let parts = entry.components(separatedBy: " : ")
                let name = (parts.first ?? "value").trimmingCharacters(in: .whitespaces)
                let kind = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "String"
                let def = kind == "Bool" ? "false" : (kind == "Int" ? "0" : (kind == "Double" ? "0.5" : "\"\""))
                lines.append("\(indent)@State private var \(name): \(kind) = \(def)")
            }
        }
        var autoIndex = 1
        func scan(_ node: VisualComponentNode) {
            switch node.type {
            case .toggle where node.properties["boundStateVar"] == nil:
                lines.append("\(indent)@State private var toggle\(autoIndex) = true")
                autoIndex += 1
            case .slider where node.properties["boundStateVar"] == nil:
                lines.append("\(indent)@State private var slider\(autoIndex) = 0.5")
                autoIndex += 1
            case .textField, .secureField:
                if node.properties["boundStateVar"] == nil {
                    lines.append("\(indent)@State private var input\(autoIndex) = \"\"")
                    autoIndex += 1
                }
            default: break
            }
            node.children.forEach(scan)
        }
        scan(root)
        return lines
    }

    private static func generateSwiftUI(artboard: VisualUIArtboard, typeName: String) -> String {
        var out: [String] = ["import SwiftUI"]
        if containsType(artboard.rootNode, .charts) { out.append("import Charts") }
        if containsType(artboard.rootNode, .map) { out.append("import MapKit") }
        out.append("")
        out.append("struct \(typeName)View: View {")
        let states = stateDeclarations(root: artboard.rootNode)
        if !states.isEmpty {
            out.append(contentsOf: states)
            out.append("")
        }
        out.append("    var body: some View {")
        var autoCounter = 1
        let bodyLines = emitSwiftUINode(artboard.rootNode, depth: 2, autoCounter: &autoCounter)
        out.append(contentsOf: bodyLines)
        out.append("    }")
        out.append("}")
        out.append("")
        out.append("#Preview(\"\(escape(artboard.name))\") {")
        out.append("    \(typeName)View()")
        if artboard.appearance?.lowercased().contains("dark") == true {
            out.append("        .preferredColorScheme(.dark)")
        }
        out.append("}")
        return out.joined(separator: "\n")
    }

    private static func containsType(_ node: VisualComponentNode, _ type: VisualComponentType) -> Bool {
        node.type == type || node.children.contains { containsType($0, type) }
    }

    private static func emitSwiftUINode(_ node: VisualComponentNode, depth: Int, autoCounter: inout Int) -> [String] {
        if node.isHidden { return [] }
        let pad = String(repeating: "    ", count: depth)
        var lines: [String] = []
        let text = escape(node.properties["textValue"] ?? node.name)
        let symbol = escape(node.properties["sfSymbolName"] ?? "sparkles")
        let spacing = node.properties["spacing"]
        let align = node.properties["alignment"]

        switch node.type {
        case .vStack:
            var args: [String] = []
            if let align, align != "Center" { args.append("alignment: .\(align.lowercased())") }
            if let spacing, !spacing.isEmpty { args.append("spacing: \(spacing)") }
            lines.append("\(pad)VStack(\(args.joined(separator: ", "))) {")
            lines.append(contentsOf: emitChildren(node, depth: depth + 1, autoCounter: &autoCounter))
            lines.append("\(pad)}")
        case .hStack:
            var args: [String] = []
            if let spacing, !spacing.isEmpty { args.append("spacing: \(spacing)") }
            lines.append("\(pad)HStack(\(args.joined(separator: ", "))) {")
            lines.append(contentsOf: emitChildren(node, depth: depth + 1, autoCounter: &autoCounter))
            lines.append("\(pad)}")
        case .zStack:
            lines.append("\(pad)ZStack {")
            lines.append(contentsOf: emitChildren(node, depth: depth + 1, autoCounter: &autoCounter))
            lines.append("\(pad)}")
        case .scrollView:
            lines.append("\(pad)ScrollView {")
            lines.append(contentsOf: emitChildren(node, depth: depth + 1, autoCounter: &autoCounter))
            lines.append("\(pad)}")
        case .list:
            lines.append("\(pad)List {")
            lines.append(contentsOf: emitChildren(node, depth: depth + 1, autoCounter: &autoCounter))
            lines.append("\(pad)}")
        case .form:
            lines.append("\(pad)Form {")
            lines.append(contentsOf: emitChildren(node, depth: depth + 1, autoCounter: &autoCounter))
            lines.append("\(pad)}")
        case .groupBox:
            lines.append("\(pad)GroupBox(\"\(escape(node.name))\") {")
            lines.append(contentsOf: emitChildren(node, depth: depth + 1, autoCounter: &autoCounter))
            lines.append("\(pad)}")
        case .navigationStack:
            lines.append("\(pad)NavigationStack {")
            lines.append(contentsOf: emitChildren(node, depth: depth + 1, autoCounter: &autoCounter))
            lines.append("\(pad)}")
        case .tabView:
            lines.append("\(pad)TabView {")
            for child in node.children where !child.isHidden {
                lines.append(contentsOf: emitSwiftUINode(child, depth: depth + 1, autoCounter: &autoCounter))
                lines.append("\(pad)        .tabItem { Label(\"\(escape(child.name))\", systemImage: \"star\") }")
            }
            lines.append("\(pad)}")
        case .text:
            lines.append("\(pad)Text(\"\(text)\")")
        case .label:
            lines.append("\(pad)Label(\"\(text)\", systemImage: \"\(symbol)\")")
        case .sfSymbol, .image:
            lines.append("\(pad)Image(systemName: \"\(symbol)\")")
        case .asyncImage:
            let url = escape(node.properties["url"] ?? "https://example.com/image.png")
            lines.append("\(pad)AsyncImage(url: URL(string: \"\(url)\"))")
        case .button:
            lines.append("\(pad)Button(\"\(text)\") {")
            lines.append("\(pad)    // Action")
            lines.append("\(pad)}")
        case .toggle:
            let binding = node.properties["boundStateVar"].map { "$\($0)" } ?? { defer { autoCounter += 1 }; return "$toggle\(autoCounter)" }()
            lines.append("\(pad)Toggle(\"\(text)\", isOn: \(binding))")
        case .slider:
            let binding = node.properties["boundStateVar"].map { "$\($0)" } ?? { defer { autoCounter += 1 }; return "$slider\(autoCounter)" }()
            lines.append("\(pad)Slider(value: \(binding), in: 0...1)")
        case .textField:
            let binding = node.properties["boundStateVar"].map { "$\($0)" } ?? { defer { autoCounter += 1 }; return "$input\(autoCounter)" }()
            lines.append("\(pad)TextField(\"\(text)\", text: \(binding))")
            lines.append("\(pad)    .textFieldStyle(.roundedBorder)")
        case .secureField:
            let binding = node.properties["boundStateVar"].map { "$\($0)" } ?? { defer { autoCounter += 1 }; return "$input\(autoCounter)" }()
            lines.append("\(pad)SecureField(\"\(text)\", text: \(binding))")
            lines.append("\(pad)    .textFieldStyle(.roundedBorder)")
        case .progressView:
            lines.append("\(pad)ProgressView(value: \(node.properties["value"] ?? "0.65"))")
        case .gauge:
            lines.append("\(pad)Gauge(value: \(node.properties["value"] ?? "0.72")) { Text(\"\(text)\") }")
        case .divider:
            lines.append("\(pad)Divider()")
        case .spacer:
            lines.append("\(pad)Spacer()")
        case .contentUnavailableView:
            lines.append("\(pad)ContentUnavailableView(\"\(text)\", systemImage: \"\(symbol)\")")
        default:
            if !node.children.isEmpty {
                lines.append("\(pad)VStack {")
                lines.append(contentsOf: emitChildren(node, depth: depth + 1, autoCounter: &autoCounter))
                lines.append("\(pad)}")
            } else {
                lines.append("\(pad)Text(\"\(text)\")")
            }
        }

        lines.append(contentsOf: emitModifiers(node, pad: pad + "    "))
        return lines
    }

    private static func emitChildren(_ node: VisualComponentNode, depth: Int, autoCounter: inout Int) -> [String] {
        let visible = node.children.filter { !$0.isHidden }
        if visible.isEmpty {
            return [String(repeating: "    ", count: depth) + "EmptyView()"]
        }
        return visible.flatMap { emitSwiftUINode($0, depth: depth, autoCounter: &autoCounter) }
    }

    private static func emitModifiers(_ node: VisualComponentNode, pad: String) -> [String] {
        var m: [String] = []
        if let preset = node.properties["fontPreset"], !preset.isEmpty, preset != "Body" {
            let swiftFont: String = switch preset {
            case "Large Title": ".largeTitle.bold()"
            case "Title 1": ".title.weight(.semibold)"
            case "Headline": ".headline"
            case "Subhead": ".subheadline"
            case "Footnote": ".footnote"
            default: ".body"
            }
            m.append("\(pad).font(\(swiftFont))")
        }
        let w = node.properties["width"].flatMap { Double($0) }
        let h = node.properties["height"].flatMap { Double($0) }
        if w != nil || h != nil {
            var parts: [String] = []
            if let w { parts.append("width: \(Int(w))") }
            if let h { parts.append("height: \(Int(h))") }
            m.append("\(pad).frame(\(parts.joined(separator: ", ")))")
        }
        if let p = node.properties["padding"], let v = Double(p), v > 0 {
            m.append("\(pad).padding(\(Int(v)))")
        }
        if let fg = node.properties["foregroundColor"], !fg.isEmpty {
            m.append("\(pad).foregroundStyle(\(swiftColorExpr(fg)))")
        }
        if let mat = node.properties["materialTheme"], mat != "None", !mat.isEmpty {
            let matExpr = ".\(mat.prefix(1).lowercased() + mat.dropFirst())Material"
            let r = Int(Double(node.properties["cornerRadius"] ?? "12") ?? 12)
            m.append("\(pad).background(\(matExpr), in: RoundedRectangle(cornerRadius: \(r)))")
        } else if let bg = node.properties["backgroundColor"], !bg.isEmpty {
            let r = Int(Double(node.properties["cornerRadius"] ?? "0") ?? 0)
            if r > 0 {
                m.append("\(pad).background(\(swiftColorExpr(bg)), in: RoundedRectangle(cornerRadius: \(r)))")
            } else {
                m.append("\(pad).background(\(swiftColorExpr(bg)))")
            }
        } else if let cr = node.properties["cornerRadius"], let r = Double(cr), r > 0 {
            m.append("\(pad).clipShape(RoundedRectangle(cornerRadius: \(Int(r))))")
        }
        if let bw = node.properties["borderWidth"], let b = Double(bw), b > 0 {
            let r = Int(Double(node.properties["cornerRadius"] ?? "8") ?? 8)
            let bc = node.properties["borderColor"].map(swiftColorExpr) ?? "Color.secondary.opacity(0.3)"
            m.append("\(pad).overlay(RoundedRectangle(cornerRadius: \(r)).stroke(\(bc), lineWidth: \(Int(b))))")
        }
        if let sh = node.properties["shadowRadius"], let s = Double(sh), s > 0 {
            m.append("\(pad).shadow(radius: \(Int(s)))")
        }
        if let op = node.properties["opacity"], let o = Double(op), o < 1.0 {
            m.append(String(format: "%@.opacity(%.2f)", pad, o))
        }
        if let rot = node.properties["rotation"], let deg = Double(rot), deg != 0 {
            m.append("\(pad).rotationEffect(.degrees(\(Int(deg))))")
        }
        if let label = node.properties["accessibilityLabel"], !label.isEmpty {
            m.append("\(pad).accessibilityLabel(\"\(escape(label))\")")
        }
        if let hint = node.properties["accessibilityHint"], !hint.isEmpty {
            m.append("\(pad).accessibilityHint(\"\(escape(hint))\")")
        }
        return m
    }

    private static func swiftColorExpr(_ hex: String) -> String {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let val = UInt64(clean, radix: 16) else { return ".accentColor" }
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return String(format: "Color(red: %.2f, green: %.2f, blue: %.2f)", r, g, b)
    }

    private static func generateAppKit(artboard: VisualUIArtboard, typeName: String) -> String {
        var lines = [
            "import AppKit",
            "",
            "@MainActor",
            "final class \(typeName)ViewController: NSViewController {",
            "    override func loadView() {",
            "        let root = NSView()",
            "        let stack = NSStackView()",
            "        stack.orientation = \(artboard.rootNode.type == .hStack ? ".horizontal" : ".vertical")",
            "        stack.spacing = \(artboard.rootNode.properties["spacing"] ?? "12")",
            "        stack.translatesAutoresizingMaskIntoConstraints = false",
        ]
        for (i, child) in artboard.rootNode.children.filter({ !$0.isHidden }).enumerated() {
            let v = "item\(i + 1)"
            let t = escape(child.properties["textValue"] ?? child.name)
            switch child.type {
            case .button:
                lines.append("        let \(v) = NSButton(title: \"\(t)\", target: nil, action: nil)")
                lines.append("        \(v).bezelStyle = .rounded")
            case .toggle:
                lines.append("        let \(v) = NSButton(checkboxWithTitle: \"\(t)\", target: nil, action: nil)")
            case .textField:
                lines.append("        let \(v) = NSTextField(string: \"\")")
                lines.append("        \(v).placeholderString = \"\(t)\"")
            case .divider:
                lines.append("        let \(v) = NSBox(); \(v).boxType = .separator")
            default:
                lines.append("        let \(v) = NSTextField(labelWithString: \"\(t)\")")
            }
            lines.append("        stack.addArrangedSubview(\(v))")
        }
        lines += [
            "        root.addSubview(stack)",
            "        NSLayoutConstraint.activate([",
            "            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),",
            "            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),",
            "            stack.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 20),",
            "        ])",
            "        self.view = root",
            "    }",
            "}",
        ]
        return lines.joined(separator: "\n")
    }

    private static func generateUIKit(artboard: VisualUIArtboard, typeName: String) -> String {
        var lines = [
            "import UIKit",
            "",
            "final class \(typeName)ViewController: UIViewController {",
            "    override func viewDidLoad() {",
            "        super.viewDidLoad()",
            "        view.backgroundColor = .systemBackground",
            "        let stack = UIStackView()",
            "        stack.axis = \(artboard.rootNode.type == .hStack ? ".horizontal" : ".vertical")",
            "        stack.spacing = \(artboard.rootNode.properties["spacing"] ?? "12")",
            "        stack.translatesAutoresizingMaskIntoConstraints = false",
        ]
        for (i, child) in artboard.rootNode.children.filter({ !$0.isHidden }).enumerated() {
            let v = "item\(i + 1)"
            let t = escape(child.properties["textValue"] ?? child.name)
            switch child.type {
            case .button:
                lines.append("        var cfg\(i) = UIButton.Configuration.filled()")
                lines.append("        cfg\(i).title = \"\(t)\"")
                lines.append("        let \(v) = UIButton(configuration: cfg\(i))")
            case .textField:
                lines.append("        let \(v) = UITextField(); \(v).placeholder = \"\(t)\"; \(v).borderStyle = .roundedRect")
            default:
                lines.append("        let \(v) = UILabel(); \(v).text = \"\(t)\"")
            }
            lines.append("        stack.addArrangedSubview(\(v))")
        }
        lines += [
            "        view.addSubview(stack)",
            "        NSLayoutConstraint.activate([",
            "            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),",
            "            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),",
            "            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),",
            "        ])",
            "    }",
            "}",
        ]
        return lines.joined(separator: "\n")
    }

    private static func generateWidgetKit(artboard: VisualUIArtboard, typeName: String) -> String {
        var auto = 1
        let body = emitSwiftUINode(artboard.rootNode, depth: 2, autoCounter: &auto).joined(separator: "\n")
        return """
        import SwiftUI
        import WidgetKit

        struct \(typeName)Entry: TimelineEntry {
            let date: Date
        }

        struct \(typeName)WidgetView: View {
            var entry: \(typeName)Entry

            var body: some View {
        \(body)
                    .containerBackground(.fill.tertiary, for: .widget)
            }
        }
        """
    }

    private static func generateVisionOS(artboard: VisualUIArtboard, typeName: String) -> String {
        var auto = 1
        let body = emitSwiftUINode(artboard.rootNode, depth: 2, autoCounter: &auto).joined(separator: "\n")
        return """
        import SwiftUI

        struct \(typeName)SpatialView: View {
            var body: some View {
        \(body)
                    .padding(32)
                    .glassBackgroundEffect()
            }
        }
        """
    }

    private static func generateWatchOS(artboard: VisualUIArtboard, typeName: String) -> String {
        var auto = 1
        let body = emitSwiftUINode(artboard.rootNode, depth: 3, autoCounter: &auto).joined(separator: "\n")
        return """
        import SwiftUI

        struct \(typeName)WatchView: View {
            var body: some View {
                ScrollView {
        \(body)
                }
            }
        }
        """
    }

    public static func applySwiftUISource(_ source: String, to artboard: VisualUIArtboard) {
        let lines = source.components(separatedBy: .newlines)
        var stack: [VisualComponentNode] = []
        let root = VisualComponentNode(type: .vStack, name: "VStack")
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("VStack") && line.contains("{") {
                let n = VisualComponentNode(type: .vStack)
                (stack.last ?? root).children.append(n); stack.append(n)
            } else if line.hasPrefix("HStack") && line.contains("{") {
                let n = VisualComponentNode(type: .hStack)
                (stack.last ?? root).children.append(n); stack.append(n)
            } else if line.hasPrefix("ZStack") && line.contains("{") {
                let n = VisualComponentNode(type: .zStack)
                (stack.last ?? root).children.append(n); stack.append(n)
            } else if line.hasPrefix("ScrollView") && line.contains("{") {
                let n = VisualComponentNode(type: .scrollView)
                (stack.last ?? root).children.append(n); stack.append(n)
            } else if let text = firstQuoted(in: line), line.hasPrefix("Text(") {
                (stack.last ?? root).children.append(VisualComponentNode(type: .text, name: text, properties: ["textValue": text]))
            } else if let text = firstQuoted(in: line), line.hasPrefix("Button(") {
                (stack.last ?? root).children.append(VisualComponentNode(type: .button, name: text, properties: ["textValue": text]))
            } else if let text = firstQuoted(in: line), line.hasPrefix("Toggle(") {
                (stack.last ?? root).children.append(VisualComponentNode(type: .toggle, name: text, properties: ["textValue": text]))
            } else if let text = firstQuoted(in: line), line.hasPrefix("TextField(") {
                (stack.last ?? root).children.append(VisualComponentNode(type: .textField, name: text, properties: ["textValue": text]))
            } else if let sym = firstQuoted(in: line), line.hasPrefix("Image(systemName:") {
                (stack.last ?? root).children.append(VisualComponentNode(type: .sfSymbol, name: sym, properties: ["sfSymbolName": sym]))
            } else if line.hasPrefix("Divider()") {
                (stack.last ?? root).children.append(VisualComponentNode(type: .divider))
            } else if line.hasPrefix("Spacer()") {
                (stack.last ?? root).children.append(VisualComponentNode(type: .spacer))
            } else if line == "}" && !stack.isEmpty {
                stack.removeLast()
            }
        }
        if let first = root.children.first, root.children.count == 1,
           first.type == .vStack || first.type == .hStack || first.type == .zStack {
            artboard.rootNode = first
        } else if !root.children.isEmpty {
            artboard.rootNode = root
        }
    }

    private static func firstQuoted(in line: String) -> String? {
        guard let first = line.firstIndex(of: "\"") else { return nil }
        let rest = line[line.index(after: first)...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
