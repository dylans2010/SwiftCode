import SwiftUI

struct CrashLogAnalyzerView: View {
    @State private var crashLog = ""

    var parsed: CrashAnalysis {
        CrashAnalysis.parse(log: crashLog)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Paste crash log", text: $crashLog, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                GroupBox("Failing Function") { Text(parsed.failingFunction) }
                GroupBox("Likely Cause") { Text(parsed.likelyCause) }
                GroupBox("Relevant Locations") { Text(parsed.fileHints.joined(separator: "\n")) }
                Spacer()
            }
            .padding()
            .navigationTitle("Crash Log Analyzer")
        }
    }
}

private struct CrashAnalysis {
    let failingFunction: String
    let likelyCause: String
    let fileHints: [String]

    static func parse(log: String) -> Self {
        let lines = log.split(separator: "\n").map(String.init)
        let frame = lines.first(where: { $0.contains(" 0 ") || $0.localizedCaseInsensitiveContains("fatal error") || $0.localizedCaseInsensitiveContains("terminating app") }) ?? "Unknown function"
        let reason = lines.first(where: { $0.localizedCaseInsensitiveContains("reason:") || $0.localizedCaseInsensitiveContains("fatal error") }) ?? "Cause not found in log."
        let fileRefs = lines.filter { $0.contains(".swift") }.prefix(8)

        return .init(
            failingFunction: frame,
            likelyCause: reason,
            fileHints: Array(fileRefs)
        )
    }
}
