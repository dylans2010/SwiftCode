import Foundation
import SwiftUI
import YcodeEditorKit
import YcodeIDECore
import YcodeIDEShell
import YcodeSyntax

struct EditorArea: View {
    var model: WorkspaceShellModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if model.sourceControl.pane != nil {
            SourceControlPaneView(model: model)
        } else if model.testing.shownReport != nil {
            ReportPaneView(model: model)
        } else {
            sourceEditor
        }
    }

    @ViewBuilder var sourceEditor: some View {
        let prefs = ShellPreferences.shared.revision
        let palette = SourcePalette.forAppearance(dark: colorScheme == .dark, theme: Preferences.shared.theme)
        let c = ShellColors(colorScheme)
        VStack(spacing: 0) {
            EditorTabBarView(model: model)
            Hairline(color: c.separator)
            JumpBar(model: model)
            Hairline(color: c.separator)
            if model.findBar.isShown, model.editor != nil {
                EditorFindBarView(bar: model.findBar, model: model)
                Hairline(color: c.separator)
            }
            if let editor = model.editor {
                EditorBanner(model: model, document: editor)
            }
            Group {
                if let doc = model.document {
                    if let s = model.structuredEditor, s.path == doc.path {
                        StructuredEditorView(model: model, editor: s)
                    } else if let message = doc.message {
                        Text(verbatim: message).font(Font.system(size: 15)).foregroundStyle(c.secondaryLabel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let editor = model.editor {
                        let controller = SourceEditorController.of(editor)
                        PreviewEditorSplit(canvas: model.previewCanvas) {
                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    SourceEditorView(controller: controller, model: model, palette: palette, preferences: prefs)
                                        .id(editor.path)
                                    Hairline(color: c.separator, vertical: true)
                                    Minimap(controller: controller, colors: c, width: Minimap.width(forPane: geo.size.width))
                                }
                            }
                            .overlay { QuickHelpPopoverLayer(model: model, controller: controller) }
                        }
                    }
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .shellTarget("no selection")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background.color)
            .overlay { LanguageNotice(model: model) }
            .overlay { DebugEditorOverlay(model: model) }
            DebugBar(model: model)
        }
        .shellTarget("editor")
    }
}

struct EditorTabBarView: View {
    @Bindable var model: WorkspaceShellModel
    @Environment(\.colorScheme) private var scheme
    @State private var hoveredTab: String?

    var body: some View {
        let c = ShellColors(scheme)
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    let tabs = model.openTabs.isEmpty ? (model.document.map { [$0.path] } ?? []) : model.openTabs
                    ForEach(Array(tabs.enumerated()), id: \.element) { index, path in
                        let isActive = model.document?.path == path
                        let fileName = (path as NSString).lastPathComponent
                        let isHovered = hoveredTab == path
                        let ext = (path as NSString).pathExtension
                        let icon = FileSymbolsShow.symbol(forPathExtension: ext, isFolder: false)
                        let color = FileSymbolsShow.color(forPathExtension: ext, isFolder: false)
                        let isDirty = model.editedPaths.contains(path)

                        Button {
                            model.open(path)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(isActive ? color : color.opacity(0.75))
                                Text(verbatim: fileName + (isDirty ? " •" : ""))
                                    .font(ShellFonts.small.weight(isActive ? .medium : .regular))
                                    .foregroundStyle(isActive ? c.label : c.secondaryLabel)
                                    .lineLimit(1)
                                if isHovered || isActive {
                                    Button {
                                        model.closeTab(at: index)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(c.secondaryLabel)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Close \(fileName)")
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                if isActive {
                                    Capsule(style: .continuous)
                                        .fill(Color(white: scheme == .dark ? 0.16 : 0.88).opacity(0.85))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(scheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(scheme == .dark ? 0.35 : 0.08), radius: 2, y: 1)
                                } else if isHovered {
                                    Capsule(style: .continuous)
                                        .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 0.5)
                                        )
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            hoveredTab = h ? path : nil
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Spacer(minLength: 8)

            Button {
                NotificationCenter.default.post(name: NSNotification.Name("com.swiftcode.showStartPage"), object: nil)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.inset.filled")
                        .font(.system(size: 11))
                    Text("Start Page")
                        .font(ShellFonts.small)
                }
                .foregroundStyle(c.secondaryLabel)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help("Open Start Page")
            .padding(.trailing, 8)
        }
        .frame(height: 34)
        .background(c.content.opacity(0.95))
    }
}

struct JumpBar: View {
    var model: WorkspaceShellModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = ShellColors(scheme)
        HStack(spacing: 4) {
            Image(systemName: "square.grid.2x2").font(.system(size: 11)).foregroundStyle(c.secondaryLabel)
                .help("Navigate to Related Items")

            HStack(spacing: 2) {
                Button {
                    model.perform(.goBack)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(model.canGoBack ? c.label : c.secondaryLabel.opacity(0.4))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .disabled(!model.canGoBack)
                .help("Go Back (⌃⌘←)")

                Button {
                    model.perform(.goForward)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(model.canGoForward ? c.label : c.secondaryLabel.opacity(0.4))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .disabled(!model.canGoForward)
                .help("Go Forward (⌃⌘→)")
            }
            .padding(.horizontal, 2)

            Rectangle().fill(c.separator).frame(width: 1, height: 12).padding(.horizontal, 2)
            if model.document != nil {
                let pathList = model.jumpPath
                ForEach(Array(pathList.enumerated()), id: \.offset) { pair in
                    if pair.offset > 0 { chevron(c) }
                    let isFirst = pair.offset == 0
                    let isLast = pair.offset == pathList.count - 1
                    let (symbol, tint): (String, Color) = {
                        if isFirst {
                            return ("hammer.fill", Color.blue)
                        } else if isLast {
                            let ext = (pair.element.title as NSString).pathExtension
                            let sym = FileSymbolsShow.symbol(forPathExtension: ext, isFolder: false)
                            let col = FileSymbolsShow.color(forPathExtension: ext, isFolder: false)
                            return (sym == "doc" ? pair.element.symbol : sym, col)
                        } else {
                            return ("folder.fill", c.secondaryLabel)
                        }
                    }()
                    HStack(spacing: 3) {
                        Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(tint)
                        Text(verbatim: pair.element.title).font(ShellFonts.small.weight(.medium)).foregroundStyle(c.label).lineLimit(1)
                    }
                }
                if let path = model.document?.path, model.editedPaths.contains(path) {
                    Circle().fill(c.secondaryLabel).frame(width: 6, height: 6)
                        .help("Unsaved changes")
                        .shellTarget("edited mark")
                }
                chevron(c)
                DocumentItemsMenu(model: model)
            } else {
                Text("No Selection").font(ShellFonts.small).tracking(ShellFonts.smallTracking).foregroundStyle(c.secondaryLabel)
            }
            Spacer(minLength: 0)
            if let path = model.document?.path, StructuredEditor.hasSourceView(path) { OpenAsSwitch(model: model) }
            if model.issueCounts.errors + model.issueCounts.warnings > 0 {
                HStack(spacing: 8) {
                    Button { model.perform(.previousIssue) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 11)).foregroundStyle(c.secondaryLabel)
                    }
                    .buttonStyle(.plain).help("Jump to Previous Issue")
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(c.label)
                    Button { model.perform(.nextIssue) } label: {
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(c.secondaryLabel)
                    }
                    .buttonStyle(.plain).help("Jump to Next Issue")
                }
                .padding(.trailing, 6)
            }

            HStack(spacing: 6) {
                Button {
                    model.assistant.isShown.toggle()
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 11))
                        .foregroundStyle(model.assistant.isShown ? Color.accentColor : c.secondaryLabel)
                        .padding(2)
                }
                .buttonStyle(.plain)
                .help("Toggle Assistant Editor (Counterpart)")

                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("com.swiftcode.addEditorPane"), object: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(c.secondaryLabel)
                        .padding(2)
                }
                .buttonStyle(.plain)
                .help("Add Editor Pane")
            }
        }
        .padding(.horizontal, 6)
        .frame(height: CGFloat(WorkspaceChrome.jumpBarBandHeight))
        .overlay(alignment: .top) { Hairline(color: c.separator) }
        .shellTarget("jump bar")
    }

    func chevron(_ c: ShellColors) -> some View {
        Image(systemName: "chevron.right").font(.system(size: 7, weight: .semibold)).foregroundStyle(c.tertiaryLabel)
    }
}

struct DebugBar: View {
    var model: WorkspaceShellModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = ShellColors(scheme)
        VStack(spacing: 0) {
            Hairline(color: c.separator)
            HStack(spacing: 10) {
                DebugBarItems(model: model)
                Spacer()
                if let branch = model.currentBranch {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch").font(.system(size: 11))
                        Text(verbatim: branch).font(ShellFonts.small).tracking(ShellFonts.smallTracking).lineLimit(1)
                    }
                    .foregroundStyle(c.secondaryLabel)
                    .help("The current branch")
                    .shellTarget("debug bar branch")
                }
                if let editor = model.editor, model.sourceControl.pane == nil {
                    CaretPositionLabel(controller: SourceEditorController.of(editor), color: c.label)
                        .shellTarget("caret position")
                }
                Button { model.perform(.toggleDebugArea) } label: {
                    Image(systemName: "rectangle.bottomthird.inset.filled").font(.system(size: 13))
                        .foregroundStyle(model.isDebugAreaShown ? c.accent : c.secondaryLabel)
                }
                .buttonStyle(.plain)
                .help(model.isDebugAreaShown ? "Hide the Debug Area" : "Show the Debug Area")
                .shellTarget("debug toggle")
            }
            .padding(.leading, 9)
            .padding(.trailing, 10)
            .frame(height: CGFloat(WorkspaceChrome.debugBarHeight) - 1)
        }
        .background(c.content)
        .shellTarget("debug bar")
    }
}

struct Minimap: View {
    let controller: SourceEditorController
    let colors: ShellColors
    var width: CGFloat = 112

    static func width(forPane pane: CGFloat) -> CGFloat { CGFloat(EditorMetrics.minimapWidth(editorWidth: Double(pane))) }

    static let pitch: CGFloat = 1.6
    static let cell: CGFloat = 0.8

    var body: some View {
        let c = controller
        #if !os(Linux)
        let _ = c.redraw.tick
        #endif
        GeometryReader { geo in
            Canvas { ctx, size in
                let top = c.top, viewport = c.viewport, content = c.contentHeight
                let doc = c.buffer.document
                let u = doc.units
                let (first, count) = window(height: size.height, top: top)
                var y: CGFloat = 4
                for n in first..<min(doc.lineCount, first + count) {
                    let r = doc.lineRange(n)
                    var a = r.lowerBound, z = r.upperBound
                    var lead = 0
                    while a < z, u[a] == 32 || u[a] == 9 {
                        lead += u[a] == 9 ? 4 : 1
                        a += 1
                    }
                    while z > a, u[z - 1] == 32 || u[z - 1] == 9 { z -= 1 }
                    if z > a {
                        let rect = CGRect(x: 6 + CGFloat(lead) * Self.cell, y: y, width: min(CGFloat(z - a) * Self.cell, size.width), height: 1)
                        ctx.fill(Path(rect), with: .color(colors.minimapText))
                    }
                    y += Self.pitch
                }
                if content > viewport.height {
                    let lh = c.lineHeight
                    let bandTop = 4 + (top / lh - CGFloat(first)) * Self.pitch
                    let bandHeight = viewport.height / lh * Self.pitch
                    ctx.fill(Path(CGRect(x: 0, y: bandTop, width: size.width, height: bandHeight)), with: .color(colors.minimapText.opacity(0.22)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local).onChanged { v in
                let (first, _) = window(height: geo.size.height, top: c.top)
                let line = CGFloat(first) + (v.location.y - 4) / Self.pitch
                c.scroll(x: c.left, y: line * c.lineHeight - c.viewport.height / 2)
            })
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .shellTarget("minimap")
    }

    private func window(height: CGFloat, top: CGFloat) -> (first: Int, count: Int) {
        let c = controller
        let count = Int(max(0, height - 8) / Self.pitch) + 1
        let lines = c.buffer.lineCount
        guard lines > count else { return (0, count) }
        let scrollable = max(1, c.contentHeight - c.viewport.height)
        return (Int(CGFloat(lines - count) * min(1, top / scrollable)), count)
    }
}

struct CaretPositionLabel: View {
    let controller: SourceEditorController
    let color: Color

    var body: some View {
        let c = controller
        #if !os(Linux)
        let _ = c.redraw.tick
        #endif
        return Canvas { ctx, size in
            let b = c.buffer
            let t = Text(verbatim: "Line: \(b.caretLine + 1)  Col: \(b.caretColumn + 1)")
                .font(ShellFonts.small).tracking(ShellFonts.smallTracking).foregroundStyle(color)
            ctx.draw(t, at: CGPoint(x: size.width, y: size.height / 2), anchor: .trailing)
        }
        .frame(width: 130, height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Insertion Point")
    }
}
