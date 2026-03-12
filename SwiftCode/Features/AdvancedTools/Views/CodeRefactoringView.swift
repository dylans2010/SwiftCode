import SwiftUI

struct CodeRefactoringView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var fromText = ""
    @State private var toText = ""
    @State private var preview = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Global Rename") {
                    TextField("Old symbol", text: $fromText)
                    TextField("New symbol", text: $toText)
                    Button("Preview Rename") {
                        preview = projectManager.activeFileContent.replacingOccurrences(of: fromText, with: toText)
                    }
                    Button("Apply Rename") { projectManager.activeFileContent = preview }
                }

                Section("Transformations") {
                    Button("Extract Selection to Function") {
                        preview = projectManager.activeFileContent + "\n\nfunc extractedFunction() {\n    // Extracted code\n}"
                    }
                    Button("Convert callback to async/await") {
                        preview = projectManager.activeFileContent.replacingOccurrences(of: "completion:", with: "async")
                    }
                    Button("Run Formatter") {
                        preview = projectManager.activeFileContent.replacingOccurrences(of: "\t", with: "    ")
                    }
                }

                Section("Preview") {
                    ScrollView { Text(preview).frame(maxWidth: .infinity, alignment: .leading).font(.caption.monospaced()) }
                    Button("Confirm All Changes") { projectManager.activeFileContent = preview }
                        .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Code Refactoring")
        }
    }
}
