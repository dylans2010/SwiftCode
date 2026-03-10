import SwiftUI

struct CodeSearchView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var indexService = CodeIndexService.shared

    @State private var searchQuery = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search Functions, Variables, Files...", text: $searchQuery)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { performSearch() }
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    if !searchQuery.isEmpty {
                        Button { searchQuery = ""; results = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Divider().opacity(0.3).padding(.top, 8)

                // Results
                if results.isEmpty && !searchQuery.isEmpty && !isSearching {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No Results Found")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("Search across your entire project.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { result in
                        Button {
                            openResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(result.fileName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.orange)
                                    Text(":\(result.lineNumber)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                Text(result.snippet)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
            .navigationTitle("Code Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty,
              let project = projectManager.activeProject else { return }
        isSearching = true
        let dirURL = project.directoryURL
        let query = searchQuery
        Task {
            let searchResults = await indexService.searchProject(query: query, at: dirURL)
            await MainActor.run {
                results = searchResults
                isSearching = false
            }
        }
    }

    private func openResult(_ result: SearchResult) {
        guard projectManager.activeProject != nil else { return }
        let node = FileNode(name: result.fileName, path: result.filePath, isDirectory: false)
        projectManager.openFile(node)
        dismiss()
    }
}
