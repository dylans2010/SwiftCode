import SwiftUI

struct SnippetsLibraryView: View {
    @State private var snippets: [CodeSnippet] = CodeSnippetStore.load()
    @State private var selectedCategory: SnippetCategory = .swiftUIViews
    @State private var draft = CodeSnippet.empty

    private var filtered: [CodeSnippet] { snippets.filter { $0.category == selectedCategory } }

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
                        HStack {
                            Button("Insert into Editor") {
                                ProjectManager.shared.activeFileContent += "\n\n" + snippet.code
                            }
                            .buttonStyle(.bordered)
                            Button("Delete", role: .destructive) {
                                snippets.removeAll { $0.id == snippet.id }
                                CodeSnippetStore.save(snippets)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Form {
                    TextField("Snippet name", text: $draft.title)
                    TextField("Snippet code", text: $draft.code, axis: .vertical)
                    Button("Save Snippet") {
                        draft.category = selectedCategory
                        snippets.append(draft)
                        CodeSnippetStore.save(snippets)
                        draft = .empty
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Snippets Library")
        }
    }
}

private struct CodeSnippet: Identifiable, Codable {
    let id: UUID
    var title: String
    var code: String
    var category: SnippetCategory

    static let empty = CodeSnippet(id: UUID(), title: "", code: "", category: .utilities)
}

private enum SnippetCategory: String, CaseIterable, Identifiable, Codable {
    case swiftUIViews = "SwiftUI Views"
    case networking = "Networking"
    case asyncTasks = "Async Tasks"
    case dataModels = "Data Models"
    case utilities = "Utilities"
    var id: String { rawValue }
}

private enum CodeSnippetStore {
    private static let key = "com.swiftcode.snippets"

    static func load() -> [CodeSnippet] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CodeSnippet].self, from: data) else {
            return []
        }
        return decoded
    }

    static func save(_ snippets: [CodeSnippet]) {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
