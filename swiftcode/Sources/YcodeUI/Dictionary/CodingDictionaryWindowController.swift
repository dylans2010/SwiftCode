import AppKit
import Foundation

public enum CodingDictionaryEntryText {
    public static func attributedString(for result: CodingDictionaryResult) -> NSAttributedString {
        let out = NSMutableAttributedString()
        func heading(_ text: String) {
            out.append(NSAttributedString(
                string: "\n\(text)\n",
                attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                             .foregroundColor: NSColor.labelColor]
            ))
        }
        func body(_ text: String) {
            guard !text.isEmpty else { return }
            out.append(NSAttributedString(
                string: "\(text)\n",
                attributes: [.font: NSFont.systemFont(ofSize: 13),
                             .foregroundColor: NSColor.labelColor]
            ))
        }
        func bullet(_ text: String) {
            guard !text.isEmpty else { return }
            out.append(NSAttributedString(
                string: "•  \(text)\n",
                attributes: [.font: NSFont.systemFont(ofSize: 13),
                             .foregroundColor: NSColor.labelColor]
            ))
        }
        func code(_ text: String) {
            guard !text.isEmpty else { return }
            out.append(NSAttributedString(
                string: "\(text)\n",
                attributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                             .foregroundColor: NSColor.labelColor]
            ))
        }
        func list(_ title: String, _ items: [String]) {
            guard !items.isEmpty else { return }
            heading(title)
            for item in items { bullet(item) }
        }

        out.append(NSAttributedString(
            string: "\(result.title)\n",
            attributes: [.font: NSFont.systemFont(ofSize: 20, weight: .bold),
                         .foregroundColor: NSColor.labelColor]
        ))
        if !result.subtitle.isEmpty {
            out.append(NSAttributedString(
                string: "\(result.subtitle)\n",
                attributes: [.font: NSFont.systemFont(ofSize: 13),
                             .foregroundColor: NSColor.secondaryLabelColor]
            ))
        }
        let meta = [result.kind, result.category, result.difficulty].filter { !$0.isEmpty }.joined(separator: "  ·  ")
        if !meta.isEmpty {
            out.append(NSAttributedString(
                string: "\(meta)\n",
                attributes: [.font: NSFont.systemFont(ofSize: 12),
                             .foregroundColor: NSColor.secondaryLabelColor]
            ))
        }
        if result.confidence < 100 {
            out.append(NSAttributedString(
                string: "Confidence: \(result.confidence)% — the model was unsure about part of this entry.\n",
                attributes: [.font: NSFont.systemFont(ofSize: 12),
                             .foregroundColor: NSColor.secondaryLabelColor]
            ))
        }
        heading("Overview")
        body(result.overview)
        heading("Definition")
        body(result.definition)
        if !result.summary.isEmpty {
            heading("Summary")
            body(result.summary)
        }
        if !result.syntax.isEmpty {
            heading("Syntax")
            code(result.syntax)
        }
        if !result.parameters.isEmpty {
            heading("Parameters")
            for p in result.parameters {
                bullet("\(p.name) (\(p.type)) — \(p.description)")
            }
        }
        if !result.returnValue.type.isEmpty || !result.returnValue.description.isEmpty {
            heading("Return Value")
            body("\(result.returnValue.type) — \(result.returnValue.description)")
        }
        if !result.examples.isEmpty {
            heading("Examples")
            for example in result.examples {
                if !example.title.isEmpty {
                    out.append(NSAttributedString(
                        string: "\(example.title)\n",
                        attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium),
                                     .foregroundColor: NSColor.labelColor]
                    ))
                }
                code(example.code)
            }
        }
        if !result.commonMistakes.isEmpty {
            heading("Common Mistakes")
            for mistake in result.commonMistakes {
                bullet("\(mistake.description) — \(mistake.explanation) Fix: \(mistake.fix)")
            }
        }
        list("Best Practices", result.bestPractices)
        if !result.performanceNotes.isEmpty { heading("Performance"); body(result.performanceNotes) }
        if !result.threadSafety.isEmpty { heading("Thread Safety"); body(result.threadSafety) }
        if !result.securityNotes.isEmpty { heading("Security"); body(result.securityNotes) }
        if !result.complexity.isEmpty { heading("Complexity"); body(result.complexity) }
        if !result.memoryConsiderations.isEmpty { heading("Memory"); body(result.memoryConsiderations) }
        if !result.codeSnippet.isEmpty { heading("Code Snippet"); code(result.codeSnippet) }
        if !result.appleDocsSummary.isEmpty { heading("Apple Documentation"); body(result.appleDocsSummary) }
        if !result.swiftVersion.isEmpty { heading("Swift Version"); body(result.swiftVersion) }
        list("Availability", result.availability)
        list("Alternative APIs", result.alternativeAPIs)
        list("Related Concepts", result.relatedConcepts)
        list("Aliases", result.aliases)
        list("Keywords", result.keywords)
        list("Warnings", result.warnings)
        list("Notes", result.notes)
        list("See Also", result.seeAlso)
        list("References", result.references)
        return out
    }
}

@MainActor
public final class CodingDictionaryWindowManager: NSObject, NSWindowDelegate {
    public static let shared = CodingDictionaryWindowManager()
    private var windowController: CodingDictionaryWindowController?

    private override init() {}

    public func showWindow() {
        if let existing = windowController {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        let wc = CodingDictionaryWindowController()
        wc.window?.delegate = self
        self.windowController = wc
        wc.window?.makeKeyAndOrderFront(nil)
    }

    public func closeWindow() {
        windowController?.close()
        windowController = nil
    }

    public func windowWillClose(_ notification: Notification) {
        windowController = nil
    }
}

@MainActor
public final class CodingDictionaryWindowController: NSWindowController {
    public init() {
        let window = CodingDictionaryWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Coding Dictionary"
        window.minSize = NSSize(width: 850, height: 600)
        window.maxSize = NSSize(width: 850, height: 600)

        window.collectionBehavior = []

        window.standardWindowButton(.closeButton)?.isEnabled = true
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = true

        window.standardWindowButton(.zoomButton)?.isEnabled = false

        super.init(window: window)

        if !window.setFrameAutosaveName("CodingDictionaryMainWindow") {
            window.center()
        }

        let splitVC = CodingDictionarySplitViewController()
        window.contentViewController = splitVC

        setupToolbar(window: window)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupToolbar(window: NSWindow) {
        let toolbar = NSToolbar(identifier: "CodingDictionaryToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
    }
}
