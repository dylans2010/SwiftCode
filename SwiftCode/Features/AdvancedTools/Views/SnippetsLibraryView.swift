import SwiftUI

struct SnippetsLibraryView: View {
    @State private var snippets: [CodeSnippet] = CodeSnippet.defaults
    @State private var selectedCategory: SnippetCategory = .swiftUIViews
    @State private var draft = CodeSnippet.empty

    var filtered: [CodeSnippet] { snippets.filter { $0.category == selectedCategory } }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(SnippetCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                List(filtered) { snippet in
                    VStack(alignment: .leading) {
                        Text(snippet.title).font(.headline)
                        Text(snippet.code).font(.caption).lineLimit(2)
                        Button("Insert into Editor") {
                            ProjectManager.shared.activeFileContent += "\n\n" + snippet.code
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Form {
                    TextField("Snippet name", text: $draft.title)
                    TextField("Snippet code", text: $draft.code, axis: .vertical)
                    Button("Save Snippet") {
                        draft.category = selectedCategory
                        snippets.append(draft)
                        draft = .empty
                    }
                }
            }
            .padding()
            .navigationTitle("Snippets Library")
        }
    }
}

private struct CodeSnippet: Identifiable {
    let id = UUID()
    var title: String
    var code: String
    var category: SnippetCategory

    static let empty = CodeSnippet(title: "", code: "", category: .utilities)
    static let defaults: [CodeSnippet] = [
        .init(title: "Basic SwiftUI View", code: "struct ContentView: View { var body: some View { Text(\"Hello\") } }", category: .swiftUIViews),
        .init(title: "Async network call", code: "let (data, _) = try await URLSession.shared.data(from: url)", category: .networking)
    ]
}

private enum SnippetCategory: String, CaseIterable, Identifiable {
    case swiftUIViews = "SwiftUI Views"
    case networking = "Networking"
    case asyncTasks = "Async Tasks"
    case dataModels = "Data Models"
    case utilities = "Utilities"
    var id: String { rawValue }
}
