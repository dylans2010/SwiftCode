import SwiftUI
import UIKit

// MARK: - Code Editor View (SwiftUI wrapper)

struct CodeEditorView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var settings: AppSettings
    @State private var showSearchBar = false
    @State private var searchQuery = ""
    @State private var replaceText = ""
    @State private var wordWrap = true
    @State private var showFileLoadError = false
    @AppStorage("minimapEnabled") private var minimapEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            // File Tabs
            if !projectManager.openFileTabs.isEmpty {
                fileTabsBar
            }

            // Path Bar (breadcrumb)
            if projectManager.activeFileNode != nil {
                pathBar
            }

            // Header
            editorHeader

            Divider().opacity(0.3)

            // Search bar
            if showSearchBar {
                searchBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Editor or placeholder
            if projectManager.activeFileNode != nil {
                HStack(spacing: 0) {
                    TextEditorRepresentable(
                        text: Binding(
                            get: { projectManager.activeFileContent },
                            set: { newValue in
                                projectManager.activeFileContent = newValue
                                if settings.autoSave {
                                    scheduleAutoSave(content: newValue)
                                }
                            }
                        ),
                        wordWrap: wordWrap,
                        searchQuery: showSearchBar ? searchQuery : "",
                        fileExtension: projectManager.activeFileNode?.name.components(separatedBy: ".").last ?? "swift"
                    )
                    .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                    .id(projectManager.activeFileNode?.id)

                    // Minimap
                    if minimapEnabled {
                        MinimapView(content: projectManager.activeFileContent)
                    }
                }
            } else {
                editorPlaceholder
            }
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
        .sheet(isPresented: $showFileLoadError) {
            fileLoadErrorSheet
        }
        .onChange(of: projectManager.fileLoadError) {
            if projectManager.fileLoadError != nil {
                showFileLoadError = true
            }
        }
    }

    // MARK: - File Tabs Bar

    private var fileTabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(projectManager.openFileTabs) { tab in
                    fileTab(tab)
                }
            }
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.12))
    }

    private func fileTab(_ node: FileNode) -> some View {
        let isActive = projectManager.activeFileNode?.id == node.id
        return HStack(spacing: 4) {
            Image(systemName: node.icon)
                .font(.system(size: 9))
                .foregroundStyle(node.iconColor)
            Text(node.name)
                .font(.caption2)
                .foregroundStyle(isActive ? .white : .secondary)
                .lineLimit(1)
            Button {
                projectManager.closeTab(node)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isActive ? Color.white.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            projectManager.openFile(node)
        }
    }

    // MARK: - Path Bar (Breadcrumb)

    private var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                if let project = projectManager.activeProject {
                    Text(project.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let node = projectManager.activeFileNode {
                    let components = node.path.components(separatedBy: "/")
                    ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                        Text(component)
                            .font(.caption2)
                            .foregroundStyle(index == components.count - 1 ? .orange : .secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }

    // MARK: - Subviews

    private var editorHeader: some View {
        HStack(spacing: 12) {
            if let node = projectManager.activeFileNode {
                Image(systemName: node.icon)
                    .foregroundStyle(node.iconColor)
                    .font(.caption)
                Text(node.name)
                    .font(.caption)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    projectManager.saveCurrentFile(content: projectManager.activeFileContent)
                } label: {
                    Label("Save", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("s", modifiers: .command)
            } else {
                Text("No File Selected")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            // Word wrap toggle
            Button {
                wordWrap.toggle()
            } label: {
                Image(systemName: wordWrap ? "text.word.spacing" : "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(wordWrap ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            // Search toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSearchBar.toggle()
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(showSearchBar ? .orange : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                TextField("Find", text: $searchQuery)
                    .font(.caption)
                    .autocorrectionDisabled()
                Button("Done") {
                    withAnimation { showSearchBar = false }
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary).font(.caption)
                TextField("Replace", text: $replaceText)
                    .font(.caption)
                    .autocorrectionDisabled()
                Button("Replace All") {
                    replaceAll()
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(red: 0.13, green: 0.13, blue: 0.17))
    }

    private var editorPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Select a file to edit")
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileLoadErrorSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text("File Load Error")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(projectManager.fileLoadError ?? "Unknown error")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Spacer()
            }
            .padding(.top, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dismiss") {
                        projectManager.fileLoadError = nil
                        showFileLoadError = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    @State private var pendingSaveTask: Task<Void, Never>?

    private func scheduleAutoSave(content: String) {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                projectManager.saveCurrentFile(content: content)
            }
        }
    }

    private func replaceAll() {
        guard !searchQuery.isEmpty else { return }
        let updated = projectManager.activeFileContent.replacingOccurrences(of: searchQuery, with: replaceText)
        projectManager.saveCurrentFile(content: updated)
    }
}

// MARK: - Minimap View

struct MinimapView: View {
    let content: String
    @AppStorage("minimapWidth") private var minimapWidth: Double = 60
    @AppStorage("minimapOpacity") private var minimapOpacity: Double = 0.6

    var body: some View {
        GeometryReader { geo in
            let lines = content.components(separatedBy: "\n")
            let lineHeight: CGFloat = 2
            let totalHeight = CGFloat(lines.count) * lineHeight

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.prefix(2000).enumerated()), id: \.offset) { _, line in
                        let width = min(CGFloat(line.count) * 0.5, minimapWidth - 4)
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(minimapColor(for: line))
                            .frame(width: max(width, 0), height: lineHeight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
                .frame(height: max(totalHeight, geo.size.height))
            }
        }
        .frame(width: minimapWidth)
        .background(Color(red: 0.13, green: 0.13, blue: 0.17))
        .opacity(minimapOpacity)
    }

    private func minimapColor(for line: String) -> Color {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
            return .green.opacity(0.4)
        }
        if trimmed.hasPrefix("import ") {
            return .purple.opacity(0.4)
        }
        if trimmed.hasPrefix("func ") || trimmed.hasPrefix("struct ") || trimmed.hasPrefix("class ") {
            return .blue.opacity(0.5)
        }
        if trimmed.isEmpty {
            return .clear
        }
        return .white.opacity(0.25)
    }
}

// MARK: - UITextView Representable

struct TextEditorRepresentable: UIViewRepresentable {
    @Binding var text: String
    var wordWrap: Bool
    var searchQuery: String
    var fileExtension: String = "swift"

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1)
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true

        let container = UIView()
        container.backgroundColor = .clear
        scrollView.addSubview(container)

        let lineNumbers = LineNumberView()
        context.coordinator.lineNumberView = lineNumbers

        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.textColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        textView.font = TextLayoutEngine.editorFont()
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.isEditable = true
        textView.isScrollEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = context.coordinator
        // Inset: left padding keeps code clear of the gutter boundary
        textView.textContainerInset = TextLayoutEngine.textContainerInset()
        // No exclusion paths needed; the text view starts after the gutter in the layout

        container.addSubview(lineNumbers)
        container.addSubview(textView)

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = container
        context.coordinator.fileExtension = fileExtension

        scrollView.delegate = context.coordinator

        // Load initial text with syntax highlighting
        let highlighted = SyntaxHighlighter.shared.highlight(text, fileExtension: fileExtension)
        textView.attributedText = highlighted

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        context.coordinator.fileExtension = fileExtension

        // Apply syntax highlighting when text changes
        if textView.attributedText.string != text {
            let highlighted = SyntaxHighlighter.shared.highlight(text, fileExtension: fileExtension)
            let savedRange = textView.selectedRange
            textView.attributedText = highlighted
            let clampedLocation = min(savedRange.location, max(0, text.count))
            textView.selectedRange = NSRange(location: clampedLocation, length: 0)
        }

        // Apply word wrap
        if wordWrap {
            textView.textContainer.lineBreakMode = .byWordWrapping
            textView.textContainer.widthTracksTextView = true
            // Ensure lines wrap within the code column only; never bleed into gutter
            textView.textContainer.size = CGSize(
                width: TextLayoutEngine.codeColumnWidth(totalWidth: scrollView.bounds.width),
                height: .greatestFiniteMagnitude
            )
        } else {
            textView.textContainer.lineBreakMode = .byClipping
            textView.textContainer.widthTracksTextView = false
            textView.textContainer.size = CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: .greatestFiniteMagnitude
            )
        }

        context.coordinator.updateLayout()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        var text: Binding<String>
        var fileExtension: String = "swift"
        weak var textView: UITextView?
        weak var scrollView: UIScrollView?
        weak var containerView: UIView?
        weak var lineNumberView: LineNumberView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            // Re-apply syntax highlighting after edit
            let highlighted = SyntaxHighlighter.shared.highlight(textView.text, fileExtension: fileExtension)
            let savedRange = textView.selectedRange
            textView.attributedText = highlighted
            let clampedLocation = min(savedRange.location, max(0, textView.text.count))
            textView.selectedRange = NSRange(location: clampedLocation, length: 0)
            updateLayout()
        }

        func updateLayout() {
            guard let textView, let scrollView, let container = containerView,
                  let lineNumbers = lineNumberView else { return }

            let gutterWidth = TextLayoutEngine.lineNumberColumnWidth
            let availableWidth = TextLayoutEngine.codeColumnWidth(totalWidth: scrollView.bounds.width)

            let textSize = textView.sizeThatFits(CGSize(
                width: availableWidth,
                height: .greatestFiniteMagnitude
            ))

            let contentWidth = max(textSize.width + gutterWidth, scrollView.bounds.width)
            let contentHeight = max(textSize.height, scrollView.bounds.height)

            container.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
            scrollView.contentSize = container.frame.size

            // Line number gutter: fixed width, full content height
            lineNumbers.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: contentHeight)
            // Code region starts immediately after the gutter
            textView.frame = CGRect(x: gutterWidth, y: 0,
                                    width: contentWidth - gutterWidth,
                                    height: contentHeight)

            // Pass layout metrics to the line number view so it draws at exact positions
            let font = textView.font ?? TextLayoutEngine.editorFont()
            lineNumbers.lineHeight = font.lineHeight
            lineNumbers.topInset = textView.textContainerInset.top
            lineNumbers.lineCount = textView.text.components(separatedBy: "\n").count
            lineNumbers.setNeedsDisplay()
        }
    }
}

// MARK: - Line Number View

/// Read-only gutter that renders 1-based line numbers aligned with the code editor.
/// The `lineHeight` and `topInset` properties must be set from the UITextView's
/// font metrics to guarantee vertical alignment with the code text.
final class LineNumberView: UIView {
    var lineCount: Int = 1
    /// Must match the editor font's lineHeight.
    var lineHeight: CGFloat = TextLayoutEngine.lineHeight()
    /// Must match UITextView.textContainerInset.top.
    var topInset: CGFloat = TextLayoutEngine.textContainerInset().top

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.17, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray.withAlphaComponent(0.6)
        ]

        // Draw a subtle right-edge separator line
        let separatorX = bounds.width - 1
        UIColor.white.withAlphaComponent(0.07).setFill()
        UIRectFill(CGRect(x: separatorX, y: 0, width: 1, height: bounds.height))

        let count = max(1, lineCount)
        for i in 1...count {
            let label = "\(i)"
            let labelSize = label.size(withAttributes: attributes)
            // Right-align the number with 8pt right padding
            let x = bounds.width - labelSize.width - 8
            // Align baseline with the code line: topInset + (line-1) * lineHeight
            // Drawing with `draw(at:)` places top-left of the glyph at the given point.
            // Shift down by (lineHeight - labelSize.height) / 2 to vertically centre.
            let codeLine_y = topInset + CGFloat(i - 1) * lineHeight
            let y = codeLine_y + (lineHeight - labelSize.height) / 2
            label.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
        }
    }
}
