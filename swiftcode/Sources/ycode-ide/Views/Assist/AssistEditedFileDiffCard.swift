import SwiftUI
import YcodeAssistant

public struct AssistEditedFileDiffItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var filename: String
    public var path: String
    public var addedLines: Int
    public var deletedLines: Int
    public var changeKind: ChangeKind
    public var abstract: String?
    public var previewContent: String?

    public enum ChangeKind: String, Sendable {
        case added = "A"
        case modified = "M"
        case deleted = "D"
        case renamed = "R"

        public var color: Color {
            switch self {
            case .added: return .green
            case .modified: return .blue
            case .deleted: return .red
            case .renamed: return .purple
            }
        }
    }

    public init(
        id: UUID = UUID(),
        filename: String,
        path: String,
        addedLines: Int = 0,
        deletedLines: Int = 0,
        changeKind: ChangeKind = .modified,
        abstract: String? = nil,
        previewContent: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.path = path
        self.addedLines = addedLines
        self.deletedLines = deletedLines
        self.changeKind = changeKind
        self.abstract = abstract
        self.previewContent = previewContent
    }

    public var badgeText: String {
        if addedLines > 0 && deletedLines > 0 {
            return "+\(addedLines) -\(deletedLines) \(changeKind.rawValue)"
        } else if addedLines > 0 {
            return "+\(addedLines) \(changeKind.rawValue)"
        } else if deletedLines > 0 {
            return "-\(deletedLines) \(changeKind.rawValue)"
        } else {
            return changeKind.rawValue
        }
    }
}

public struct AssistEditedFileDiffCard: View {
    public let item: AssistEditedFileDiffItem
    @State private var isExpanded: Bool = false

    public init(item: AssistEditedFileDiffItem) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: "swift")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.orange)

                    Text(item.filename)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 4)

                    Text(item.badgeText)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(item.changeKind.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.changeKind.color.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let abstract = item.abstract, !abstract.isEmpty {
                Text(abstract)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 6)
            }

            if isExpanded, let preview = item.previewContent, !preview.isEmpty {
                Divider().opacity(0.3)
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(preview)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.9))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.black.opacity(0.18))
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
