import SwiftUI

struct DiffLine: Identifiable {
    let id = UUID()
    let type: LineType
    let text: String

    enum LineType {
        case addition, deletion, context
    }
}

struct DiffViewerView: View {
    let filePath: String
    let diff: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "doc.text")
                Text(filePath)
                    .font(.caption.bold())
                Spacer()
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if lines.isEmpty {
                        Text("No changes detected.")
                            .padding()
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(lines) { line in
                            lineView(for: line)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private var lines: [DiffLine] {
        diff.components(separatedBy: .newlines).compactMap { line in
            if line.hasPrefix("+") {
                return DiffLine(type: .addition, text: line)
            } else if line.hasPrefix("-") {
                return DiffLine(type: .deletion, text: line)
            } else if !line.isEmpty {
                return DiffLine(type: .context, text: line)
            }
            return nil
        }
    }

    @ViewBuilder
    private func lineView(for line: DiffLine) -> some View {
        HStack(spacing: 8) {
            Text(prefix(for: line.type))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(line.text.dropFirst())
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(textColor(for: line.type))

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(backgroundColor(for: line.type))
    }

    private func prefix(for type: DiffLine.LineType) -> String {
        switch type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        }
    }

    private func backgroundColor(for type: DiffLine.LineType) -> Color {
        switch type {
        case .addition: return Color.green.opacity(0.1)
        case .deletion: return Color.red.opacity(0.1)
        case .context: return Color.clear
        }
    }

    private func textColor(for type: DiffLine.LineType) -> Color {
        switch type {
        case .addition: return Color.green
        case .deletion: return Color.red
        case .context: return Color.primary
        }
    }
}
