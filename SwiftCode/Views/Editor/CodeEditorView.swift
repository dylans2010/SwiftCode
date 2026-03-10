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

    var body: some View {
        VStack(spacing: 0) {
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
                    searchQuery: showSearchBar ? searchQuery : ""
                )
                .background(Color(red: 0.11, green: 0.11, blue: 0.14))
            } else {
                editorPlaceholder
            }
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
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

// MARK: - UITextView Representable

struct TextEditorRepresentable: UIViewRepresentable {
    @Binding var text: String
    var wordWrap: Bool
    var searchQuery: String

    // Returns a UIScrollView (the generic UIView type parameter) to support
    // synchronized horizontal scrolling and line numbers side by side.
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1)
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true

        let container = UIView()
        container.backgroundColor = .clear
        scrollView.addSubview(container)

        let lineNumbers = LineNumberView()
        lineNumbers.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.lineNumberView = lineNumbers

        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.textColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        textView.font = UIFont(name: "Menlo", size: 14) ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.isEditable = true
        textView.isScrollEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 12)

        container.addSubview(lineNumbers)
        container.addSubview(textView)

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.containerView = container

        scrollView.delegate = context.coordinator

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        let highlighted = SyntaxHighlighter.shared.highlight(text)

        if textView.attributedText.string != text {
            let selectedRange = textView.selectedRange
            textView.attributedText = highlighted
            textView.selectedRange = selectedRange
        }

        // Apply word wrap
        if wordWrap {
            textView.textContainer.lineBreakMode = .byWordWrapping
            textView.textContainer.widthTracksTextView = true
        } else {
            textView.textContainer.lineBreakMode = .byClipping
            textView.textContainer.widthTracksTextView = false
        }

        context.coordinator.updateLayout()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        var text: Binding<String>
        weak var textView: UITextView?
        weak var scrollView: UIScrollView?
        weak var containerView: UIView?
        weak var lineNumberView: LineNumberView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            updateLayout()
        }

        func updateLayout() {
            guard let textView, let scrollView, let container, let lineNumbers = lineNumberView else { return }

            let lineNumberWidth: CGFloat = 44
            let textSize = textView.sizeThatFits(CGSize(
                width: max(scrollView.bounds.width - lineNumberWidth, 200),
                height: .greatestFiniteMagnitude
            ))

            let contentWidth = max(textSize.width + lineNumberWidth, scrollView.bounds.width)
            let contentHeight = max(textSize.height, scrollView.bounds.height)

            container.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
            scrollView.contentSize = container.frame.size

            lineNumbers.frame = CGRect(x: 0, y: 0, width: lineNumberWidth, height: contentHeight)
            textView.frame = CGRect(x: lineNumberWidth, y: 0, width: contentWidth - lineNumberWidth, height: contentHeight)

            lineNumbers.lineCount = textView.text.components(separatedBy: "\n").count
            lineNumbers.setNeedsDisplay()
        }

        private var container: UIView? { containerView }
    }
}

// MARK: - Line Number View

final class LineNumberView: UIView {
    var lineCount: Int = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.17, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.gray.withAlphaComponent(0.6)
        ]
        let lineHeight: CGFloat = 17.5
        for i in 1...max(1, lineCount) {
            let label = "\(i)"
            let size = label.size(withAttributes: attributes)
            let x = bounds.width - size.width - 6
            let y = CGFloat(i - 1) * lineHeight + 13
            label.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
        }
    }
}
