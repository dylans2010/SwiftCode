import AppKit

final class ActivityCardView: NSView {
    private static let maxVisibleLines = 8

    init(lines: [String]) {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.edgeInsets = NSEdgeInsets(top: 7, left: 9, bottom: 7, right: 9)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let visible = Array(lines.suffix(Self.maxVisibleLines))
        let hidden = max(0, lines.count - visible.count)
        if hidden > 0 {
            stack.addArrangedSubview(Self.row(symbol: "ellipsis", text: "\(hidden) earlier event\(hidden == 1 ? "" : "s")",
                                              secondary: true))
        }
        for line in visible {
            stack.addArrangedSubview(Self.row(symbol: Self.symbol(for: line), text: line, secondary: false))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private static func symbol(for line: String) -> String {
        let l = line.lowercased()
        if l.contains("run") || l.contains("command") || l.contains("bash") || l.contains("shell") || l.contains("terminal") {
            return "terminal"
        }
        if l.contains("search") || l.contains("grep") || l.contains("find") || l.contains("query") {
            return "magnifyingglass"
        }
        if l.contains("read") || l.contains("view") || l.contains("file") || l.contains("open") {
            return "doc.text"
        }
        if l.contains("write") || l.contains("edit") || l.contains("replace") || l.contains("creat") || l.contains("patch") {
            return "pencil"
        }
        if l.contains("error") || l.contains("fail") || l.contains("warn") {
            return "exclamationmark.triangle"
        }
        return "wrench.and.screwdriver"
    }

    private static func row(symbol: String, text: String, secondary: Bool) -> NSView {
        let isSearch = text.lowercased().contains("search") || symbol == "magnifyingglass"
        let isCompleted = text.hasPrefix("✓") || text.lowercased().contains("complete")
        let isInProgress = text.hasPrefix("→") || text.lowercased().contains("progress") || text.lowercased().contains("running")

        let iconName: String
        let tintColor: NSColor
        if isCompleted {
            iconName = "checkmark.circle.fill"
            tintColor = .systemGreen
        } else if isInProgress {
            iconName = "arrow.right.circle.fill"
            tintColor = .systemBlue
        } else if isSearch {
            iconName = "magnifyingglass"
            tintColor = .systemCyan
        } else {
            iconName = symbol
            tintColor = .tertiaryLabelColor
        }

        let icon = NSImageView(image: NSImage(systemSymbolName: iconName, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 10, weight: .semibold)
        icon.contentTintColor = tintColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),
        ])

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: isInProgress ? .semibold : .regular)
        label.textColor = secondary ? .tertiaryLabelColor : (isInProgress ? .labelColor : .secondaryLabelColor)
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [icon, label])
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY

        
        if text.contains("+") || text.contains("-") {
            let parts = text.components(separatedBy: " ")
            if let badgePart = parts.first(where: { $0.hasPrefix("+") || $0.hasPrefix("-") }) {
                let badgeLabel = NSTextField(labelWithString: badgePart)
                badgeLabel.font = .monospacedSystemFont(ofSize: 9.5, weight: .bold)
                badgeLabel.textColor = badgePart.hasPrefix("+") ? .systemGreen : .systemRed
                row.addArrangedSubview(badgeLabel)
            }
        }

        return row
    }
}
