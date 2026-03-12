import SwiftUI

struct CodeIntelligenceView: View {
    @StateObject private var engine = CodeIntelligenceEngine.shared
    @EnvironmentObject private var projectManager: ProjectManager

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Button("Refresh Intelligence") {
                    engine.index(content: projectManager.activeFileContent)
                }
                .buttonStyle(.borderedProminent)

                GroupBox("Autocomplete Suggestions") {
                    ForEach(engine.completions, id: \.self) { Text($0) }
                }
                GroupBox("Detected Symbols") {
                    ForEach(engine.symbols, id: \.self) { symbol in
                        VStack(alignment: .leading) {
                            Text(symbol).font(.caption.monospaced())
                            Text(engine.quickDoc(for: symbol)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Code Intelligence")
        }
    }
}
