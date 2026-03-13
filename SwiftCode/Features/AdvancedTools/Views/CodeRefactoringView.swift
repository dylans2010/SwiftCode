import SwiftUI

struct CodeRefactoringView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var fromText = ""
    @State private var toText = ""
    @State private var preview = ""

    var body: some View {
        AdvancedToolScreen(title: "Code Refactoring") {
            AdvancedToolCard(title: "Global Rename") {
                TextField("Old symbol", text: $fromText).textFieldStyle(.roundedBorder)
                TextField("New symbol", text: $toText).textFieldStyle(.roundedBorder)
                HStack {
                    Button("Preview Rename") { preview = projectManager.activeFileContent.replacingOccurrences(of: fromText, with: toText) }
                    Button("Apply Rename") { projectManager.activeFileContent = preview }
                }
                .buttonStyle(.bordered)
            }

            AdvancedToolCard(title: "Transformations") {
                HStack {
                    Button("Extract to Function") { preview = projectManager.activeFileContent + "\n\nfunc extractedFunction() {\n    // Extracted code\n}" }
                    Button("To async/await") { preview = projectManager.activeFileContent.replacingOccurrences(of: "completion:", with: "async") }
                    Button("Run Formatter") { preview = projectManager.activeFileContent.replacingOccurrences(of: "\t", with: "    ") }
                }
                .buttonStyle(.bordered)
            }

            AdvancedToolCard(title: "Preview") {
                ScrollView { Text(preview).frame(maxWidth: .infinity, alignment: .leading).font(.caption.monospaced()) }
                    .frame(minHeight: 180)
                Button("Confirm All Changes") { projectManager.activeFileContent = preview }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
