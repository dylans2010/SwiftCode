import SwiftUI

struct CodeSearchView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var indexService = CodeIndexService.shared

    @State private var searchQuery = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var caseSensitive = false
    @State private var useRegex = false
    @State private var selectedFileExtension: String? = nil
    @FocusState private var searchFocused: Bool

    private let fileExtensions = ["All", "swift", "json", "plist", "yml", "yaml", "md", "txt", "xml", "html", "css", "js", "ts", "py", "kt", "go", "rs"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search entire codebase…", text: $searchQuery)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($searchFocused)
                        .onSubmit { performSearch() }
                        .onChange(of: searchQuery) { _, newValue in
                            if newValue.isEmpty { results = [] }
                        }
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

                // Search options
                searchOptionsBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                Divider().opacity(0.3).padding(.top, 8)

                // Results header
                if !results.isEmpty {
                    HStack {
                        Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Search") { performSearch() }
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                // Results
                if results.isEmpty && !searchQuery.isEmpty && !isSearching {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No Results Found")
                            .foregroundStyle(.secondary)
                        Text("No matches for "\(searchQuery)" in the codebase.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("Search your entire codebase")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Text("Searches all text files including Swift, JSON, YAML, Markdown, and more.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    resultsList
                }
            }
            .background(Color(red: 0.10, green: 0.10, blue: 0.14))
            .navigationTitle("Code Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        performSearch()
                    } label: {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                }
            }
            .onAppear { searchFocused = true }
        }
    }

    // MARK: - Search Options Bar

    private var searchOptionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Case sensitive
                optionChip(label: "Aa", selected: caseSensitive) {
                    caseSensitive.toggle()
                    if !searchQuery.isEmpty { performSearch() }
                }
                .help("Case Sensitive")

                // Regex
                optionChip(label: ".*", selected: useRegex) {
                    useRegex.toggle()
                    if !searchQuery.isEmpty { performSearch() }
                }
                .help("Regular Expression")

                Divider().frame(height: 20).opacity(0.4)

                // File type filter
                ForEach(fileExtensions, id: \.self) { ext in
                    let isSelected = (ext == "All" && selectedFileExtension == nil) ||
                                     (ext != "All" && selectedFileExtension == ext)
                    optionChip(label: ext == "All" ? "All Files" : ".\(ext)", selected: isSelected) {
                        selectedFileExtension = (ext == "All") ? nil : ext
                        if !searchQuery.isEmpty { performSearch() }
                    }
                }
            }
        }
    }

    private func optionChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selected ? Color.orange.opacity(0.25) : Color.white.opacity(0.07), in: Capsule())
                .foregroundStyle(selected ? .orange : .secondary)
                .overlay(Capsule().stroke(selected ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results List

    private var resultsList: some View {
        List(results) { result in
            Button {
                openResult(result)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: fileIcon(result.fileName))
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.8))
                        Text(result.fileName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)
                        Text(":\(result.lineNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(result.filePath.components(separatedBy: "/").dropLast().joined(separator: "/"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Text(result.snippet)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty,
              let project = projectManager.activeProject else { return }
        isSearching = true
        let dirURL = project.directoryURL
        let query = searchQuery
        let caseFlag = caseSensitive
        let regexFlag = useRegex
        let extFilter = selectedFileExtension
        Task {
            let searchResults = await indexService.searchProject(
                query: query,
                at: dirURL,
                caseSensitive: caseFlag,
                useRegex: regexFlag,
                fileExtension: extFilter
            )
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

    private func fileIcon(_ fileName: String) -> String {
        switch fileName.components(separatedBy: ".").last?.lowercased() ?? "" {
        case "swift": return "swift"
        case "json": return "curlybraces"
        case "md": return "doc.text"
        case "yml", "yaml": return "list.dash"
        case "html", "css", "js", "ts": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.fill"
        }
    }
}
