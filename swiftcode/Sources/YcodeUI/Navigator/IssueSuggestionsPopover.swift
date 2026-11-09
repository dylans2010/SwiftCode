import AppKit
import YcodeBuild
import YcodeIDECore

@MainActor
final class IssueSuggestionsViewController: NSViewController {
    private let diagnostic: Diagnostic

    init(diagnostic: Diagnostic) {
        self.diagnostic = diagnostic
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let root = NSView()

        let header = NSTextField(wrappingLabelWithString: headerText)
        header.font = .boldSystemFont(ofSize: 12)
        header.textColor = .labelColor

        var body = "How to fix this issue:\n\n"
        for (i, s) in IssueFixSuggestions.suggestions(for: diagnostic).enumerated() {
            body += "\(i + 1). \(s)\n\n"
        }
        let text = NSTextView()
        text.isEditable = false
        text.isSelectable = true
        text.isRichText = false
        text.font = .systemFont(ofSize: 12)
        text.textColor = .labelColor
        text.string = body
        text.textContainerInset = NSSize(width: 4, height: 4)
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.documentView = text

        for v in [header, scroll] { v.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(v) }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
            scroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            scroll.heightAnchor.constraint(lessThanOrEqualToConstant: 420),
        ])
        preferredContentSize = NSSize(width: 380, height: 300)
        view = root
    }

    private var headerText: String {
        var s = diagnostic.severity.rawValue.capitalized + ": " + diagnostic.message
        if let l = diagnostic.location {
            s += "\n" + URL(fileURLWithPath: l.file).lastPathComponent + ":\(l.line)" + (l.column > 0 ? ":\(l.column)" : "")
        }
        return s
    }
}

@MainActor
final class IssueSuggestionsPresenter: NSObject, NSPopoverDelegate {
    private var popover: NSPopover?

    func show(for diagnostic: Diagnostic, from anchor: NSView) {
        popover?.close()
        let controller = IssueSuggestionsViewController(diagnostic: diagnostic)
        let p = NSPopover()
        p.contentViewController = controller
        p.behavior = .transient
        p.animates = true
        p.delegate = self
        popover = p
        p.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxX)
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated { popover = nil }
    }
}
