import SwiftUI
import SwiftCodeSDK

@MainActor
public struct GitFileRowView: View {
    public let file: GitFileStatus

    public init(file: GitFileStatus) {
        self.file = file
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(file.status.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: file.path).lastPathComponent)
                    .font(.body.bold())
                Text(file.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .liquidGlass(style: .subtle, cornerRadius: 6)
        .sourceControlEmbedded()
    }
}
