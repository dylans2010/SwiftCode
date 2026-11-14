import SwiftUI
import YcodeAssistant

public struct AssistToolSummaryItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var type: Kind
    public var title: String
    public var summary: String
    public var details: String?
    public var isSuccess: Bool
    public var duration: TimeInterval?

    public enum Kind: String, Sendable, CaseIterable {
        case search
        case terminal
        case fileEdit
        case fileRead
        case build
        case test
        case generic

        public var iconName: String {
            switch self {
            case .search: return "magnifyingglass"
            case .terminal: return "terminal.fill"
            case .fileEdit: return "pencil.line"
            case .fileRead: return "doc.text.fill"
            case .build: return "hammer.fill"
            case .test: return "checkmark.diamond.fill"
            case .generic: return "wrench.and.screwdriver.fill"
            }
        }

        public var badgeText: String {
            switch self {
            case .search: return "Search"
            case .terminal: return "Terminal"
            case .fileEdit: return "Edit"
            case .fileRead: return "Read"
            case .build: return "Build"
            case .test: return "Test"
            case .generic: return "Tool"
            }
        }

        public var tintColor: Color {
            switch self {
            case .search: return .cyan
            case .terminal: return .orange
            case .fileEdit: return .green
            case .fileRead: return .blue
            case .build: return .yellow
            case .test: return .purple
            case .generic: return .accentColor
            }
        }
    }

    public init(
        id: UUID = UUID(),
        type: Kind,
        title: String,
        summary: String,
        details: String? = nil,
        isSuccess: Bool = true,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.summary = summary
        self.details = details
        self.isSuccess = isSuccess
        self.duration = duration
    }
}

public struct AssistToolSummaryCard: View {
    public let item: AssistToolSummaryItem
    @State private var isExpanded: Bool = false

    public init(item: AssistToolSummaryItem) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if item.details != nil {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(item.type.tintColor)

                        Text(item.type.badgeText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(item.type.tintColor)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(item.type.tintColor.opacity(0.12), in: Capsule())

                    Text(item.summary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 4)

                    if let duration = item.duration {
                        Text(String(format: "%.1fs", duration))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    if item.details != nil {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded, let details = item.details {
                Divider().opacity(0.3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(details)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.15))
            }
        }
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
        )
    }
}
