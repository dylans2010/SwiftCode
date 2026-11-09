import Foundation
import SwiftUI
import YcodeBuild
import YcodeIDECore

struct IssueSuggestionsSheet: View {
    var row: IssueRow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = ShellColors(scheme)
        let diagnostic = row.diagnostic
        let suggestions = diagnostic.map { IssueFixSuggestions.suggestions(for: $0) } ?? []
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(diagnostic?.severity.rawValue.capitalized ?? "Issue")
                    .font(.headline)
                Text(row.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let loc = diagnostic?.location {
                    Text("\((loc.file as NSString).lastPathComponent):\(loc.line)" + (loc.column > 0 ? ":\(loc.column)" : ""))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to fix this issue:")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { pair in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(pair.offset + 1).")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(c.secondaryLabel)
                            Text(pair.element)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 380, idealWidth: 420, minHeight: 280, idealHeight: 360)
    }
}
