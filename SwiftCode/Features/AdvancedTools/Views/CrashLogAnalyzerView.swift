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
        let line = log.split(separator: "\n").first(where: { $0.contains("0 ") || $0.contains("fatal error") })
        return .init(
            failingFunction: line.map(String.init) ?? "Unknown function",
            likelyCause: "Potential nil access, index out of range, or force-unwrap in hot path.",
            fileHints: log.split(separator: "\n").filter { $0.contains(".swift") }.prefix(8).map(String.init)
        )
    }
}
