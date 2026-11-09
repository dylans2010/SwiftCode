import YcodeIDECore
import YcodeSubprocess
import SwiftUI

@MainActor
public struct CodeSearchView: View {
    @Environment(ProjectSessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    
    @State private var searchQuery = ""
    @State private var replaceQuery = ""
    @State private var isReplaceMode = false

    
    @State private var caseSensitive = false
    @State private var useRegex = false
    @State private var wholeWord = false
    @State private var fileFilter = ""
    @State private var selectedScope: CodeSearchScope = .entireProject
    @State private var showOptionsDrawer = false

    
    @State private var fileGroups: [CodeSearchFileGroup] = []
    @State private var isSearching = false
    @State private var isReplacing = false
    @State private var searchHistory: [String] = []
    @State private var currentSearchTask: Task<Void, Never>?
    @State private var debounceTask: Task<Void, Never>?

    
    @State private var previewGroup: CodeSearchFileGroup?
    @State private var diffPreviewData: (original: String, modified: String, diffLines: [(type: CodeSearchEngine.DiffLineType, text: String)])?
    @State private var showDiffPreviewSheet = false

    
    @State private var notificationMessage: String?
    @State private var showNotification = false
    @FocusState private var searchFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            
            VStack(spacing: 10) {
                
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    TextField("Search your workspace codebase...", text: $searchQuery)
                        .font(.system(.title3, design: .rounded))
                        .autocorrectionDisabled()
                        .focused($searchFocused)
                        .onSubmit { triggerImmediateSearch() }
                        .onChange(of: searchQuery) { _, _ in scheduleSearch() }
                        .textFieldStyle(.plain)

                    if isSearching {
                        ProgressView().controlSize(.small)
                    }

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            fileGroups = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    
                    HStack(spacing: 4) {
                        toggleChip(title: "Aa", tooltip: "Match Case", isOn: $caseSensitive)
                        toggleChip(title: "\\b", tooltip: "Whole Word", isOn: $wholeWord)
                        toggleChip(title: ".*", tooltip: "Regular Expression", isOn: $useRegex)
                    }

                    Divider().frame(height: 18)

                    Button {
                        withAnimation { isReplaceMode.toggle() }
                    } label: {
                        Image(systemName: "arrow.right.arrow.left.circle")
                            .font(.title3)
                            .foregroundStyle(isReplaceMode ? Color.orange : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Replace in Files mode")

                    Button {
                        withAnimation { showOptionsDrawer.toggle() }
                    } label: {
                        Image(systemName: showOptionsDrawer ? "slider.horizontal.2.square.on.square" : "slider.horizontal.3")
                            .font(.title3)
                            .foregroundStyle(showOptionsDrawer || !fileFilter.isEmpty || selectedScope != .entireProject ? Color.orange : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Search scope and filters")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                
                if isReplaceMode {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.arrow.left")
                            .font(.body)
                            .foregroundStyle(.orange)

                        TextField("Replace with...", text: $replaceQuery)
                            .font(.body)
                            .autocorrectionDisabled()
                            .textFieldStyle(.plain)

                        Spacer()

                        if !replaceQuery.isEmpty && totalMatchCount > 0 {
                            Button {
                                performReplaceAllInProject()
                            } label: {
                                Label("Replace All (\(totalMatchCount))", systemImage: "arrow.right.arrow.left")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                            .disabled(isReplacing)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                
                if showOptionsDrawer {
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Text("Scope:")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Picker("", selection: $selectedScope) {
                                Text("Entire Project").tag(CodeSearchScope.entireProject)
                                Text("Open Files").tag(CodeSearchScope.openFiles)
                            }
                            .pickerStyle(.menu)
                            .controlSize(.small)
                            .onChange(of: selectedScope) { _, _ in scheduleSearch() }
                        }

                        HStack(spacing: 6) {
                            Text("Filters:")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("*.swift, !*.generated.swift, *.json", text: $fileFilter)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                                .frame(minWidth: 220)
                                .onChange(of: fileFilter) { _, _ in scheduleSearch() }

                            if !fileFilter.isEmpty {
                                Button("Clear") { fileFilter = ""; scheduleSearch() }
                                    .buttonStyle(.plain)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
                    .transition(.opacity)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)

            Divider()

            
            if totalMatchCount > 0 {
                HStack {
                    Text("\(totalMatchCount) match\(totalMatchCount == 1 ? "" : "es") across \(fileGroups.count) file\(fileGroups.count == 1 ? "" : "s")")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(allExpanded ? "Collapse All" : "Expand All") {
                        let target = !allExpanded
                        for i in fileGroups.indices {
                            fileGroups[i].isExpanded = target
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()
            }

            
            if !searchHistory.isEmpty && searchQuery.isEmpty && fileGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                        ForEach(searchHistory, id: \.self) { past in
                            Button(past) {
                                searchQuery = past
                                triggerImmediateSearch()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.secondary)
                        }
                        Button("Clear") { searchHistory = [] }
                            .buttonStyle(.plain)
                            .controlSize(.small)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                Divider()
            }

            
            Group {
                if isSearching {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Searching workspace codebase...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if fileGroups.isEmpty && !searchQuery.isEmpty {
                    ContentUnavailableView {
                        Label("No Matches Found", systemImage: "magnifyingglass")
                    } description: {
                        Text("No occurrences of '\(searchQuery)' found matching your criteria.")
                    }
                } else if fileGroups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("Global Code Search & Replace")
                            .font(.headline)
                        Text("Instantly search and replace code, symbols, and files across your entire project.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach($fileGroups) { $group in
                            Section {
                                if group.isExpanded {
                                    ForEach(group.matches) { match in
                                        matchRow(match: match, group: group)
                                    }
                                }
                            } header: {
                                fileGroupHeader(group: $group)
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
        }
        .frame(minWidth: 620, minHeight: 480)
        .sheet(isPresented: $showDiffPreviewSheet) {
            if let preview = diffPreviewData, let group = previewGroup {
                diffPreviewSheet(group: group, preview: preview)
            }
        }
        .alert("Search & Replace", isPresented: $showNotification, presenting: notificationMessage) { _ in
            Button("OK") {}
        } message: { msg in
            Text(msg)
        }
        .onAppear {
            searchFocused = true
        }
    }

    private var totalMatchCount: Int {
        fileGroups.reduce(0) { $0 + $1.matches.count }
    }

    private var allExpanded: Bool {
        fileGroups.allSatisfy(\.isExpanded)
    }

    private func toggleChip(title: String, tooltip: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            scheduleSearch()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(isOn.wrappedValue ? Color.orange.opacity(0.2) : Color.clear)
                .foregroundStyle(isOn.wrappedValue ? Color.orange : Color.secondary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isOn.wrappedValue ? Color.orange : Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func fileGroupHeader(group: Binding<CodeSearchFileGroup>) -> some View {
        HStack(spacing: 6) {
            Button {
                group.wrappedValue.isExpanded.toggle()
            } label: {
                Image(systemName: group.wrappedValue.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: group.wrappedValue.fileIcon)
                .foregroundStyle(.orange)
                .font(.caption)

            Text(group.wrappedValue.fileName)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text("(\(group.wrappedValue.matches.count))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(group.wrappedValue.filePath)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)

            if isReplaceMode && !replaceQuery.isEmpty {
                Button {
                    openDiffPreview(for: group.wrappedValue)
                } label: {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Preview replacement diff")

                Button {
                    performReplaceInFile(group: group.wrappedValue)
                } label: {
                    Text("Replace in File")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func matchRow(match: CodeSearchMatch, group: CodeSearchFileGroup) -> some View {
        Button {
            openResult(match)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(":\(match.lineNumber)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundStyle(.secondary)
                    .cornerRadius(4)

                highlightedSnippet(match.lineContent, query: searchQuery)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isReplaceMode && !replaceQuery.isEmpty {
                    Button {
                        performReplaceSingle(match: match)
                    } label: {
                        Image(systemName: "arrow.right.arrow.left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Replace this match")
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }

    private func highlightedSnippet(_ snippet: String, query: String) -> Text {
        guard !query.isEmpty else {
            return Text(snippet).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
        }

        let options: NSString.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        if let range = snippet.range(of: query, options: options) {
            let prefix = String(snippet[..<range.lowerBound])
            let match = String(snippet[range])
            let suffix = String(snippet[range.upperBound...])

            var prefixAttr = AttributedString(prefix)
            prefixAttr.font = .system(.caption, design: .monospaced)
            prefixAttr.foregroundColor = .secondary

            var matchAttr = AttributedString(match)
            matchAttr.font = .system(.caption, design: .monospaced).bold()
            matchAttr.foregroundColor = .orange
            matchAttr.backgroundColor = Color.orange.opacity(0.2)

            var suffixAttr = AttributedString(suffix)
            suffixAttr.font = .system(.caption, design: .monospaced)
            suffixAttr.foregroundColor = .secondary

            var combined = prefixAttr
            combined.append(matchAttr)
            combined.append(suffixAttr)

            return Text(combined)
        }

        return Text(snippet).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if !Task.isCancelled {
                triggerImmediateSearch()
            }
        }
    }

    private func triggerImmediateSearch() {
        currentSearchTask?.cancel()
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let project = sessionStore.activeProject else {
            fileGroups = []
            return
        }

        noteHistory(searchQuery)
        isSearching = true
        let query = searchQuery
        let root = project.directoryURL
        let options = CodeSearchOptions(
            caseSensitive: caseSensitive,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilter,
            scope: selectedScope,
            replacementText: replaceQuery
        )

        currentSearchTask = Task {
            let results = await CodeSearchEngine.search(
                query: query,
                rootURL: root,
                openFileURLs: [],
                options: options
            )
            if !Task.isCancelled {
                self.fileGroups = results
                self.isSearching = false
            }
        }
    }

    private func noteHistory(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchHistory.removeAll { $0 == trimmed }
        searchHistory.insert(trimmed, at: 0)
        searchHistory = Array(searchHistory.prefix(10))
    }

    private func performReplaceSingle(match: CodeSearchMatch) {
        let options = CodeSearchOptions(
            caseSensitive: caseSensitive,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilter,
            scope: selectedScope,
            replacementText: replaceQuery
        )
        Task {
            do {
                try await CodeSearchEngine.replace(match: match, with: replaceQuery, options: options)
                triggerImmediateSearch()
            } catch {
                notificationMessage = "Replace failed: \(error.localizedDescription)"
                showNotification = true
            }
        }
    }

    private func performReplaceInFile(group: CodeSearchFileGroup) {
        let options = CodeSearchOptions(
            caseSensitive: caseSensitive,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilter,
            scope: selectedScope,
            replacementText: replaceQuery
        )
        Task {
            do {
                let count = try await CodeSearchEngine.replaceAll(in: group, query: searchQuery, replacement: replaceQuery, options: options)
                notificationMessage = "Replaced \(count) occurrence\(count == 1 ? "" : "s") in \(group.fileName)."
                showNotification = true
                triggerImmediateSearch()
            } catch {
                notificationMessage = "Replace failed: \(error.localizedDescription)"
                showNotification = true
            }
        }
    }

    private func performReplaceAllInProject() {
        let options = CodeSearchOptions(
            caseSensitive: caseSensitive,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilter,
            scope: selectedScope,
            replacementText: replaceQuery
        )
        let groups = fileGroups
        isReplacing = true
        Task {
            do {
                let (files, replacements) = try await CodeSearchEngine.replaceAll(in: groups, query: searchQuery, replacement: replaceQuery, options: options)
                isReplacing = false
                notificationMessage = "Successfully replaced \(replacements) occurrence\(replacements == 1 ? "" : "s") across \(files) file\(files == 1 ? "" : "s")."
                showNotification = true
                triggerImmediateSearch()
            } catch {
                isReplacing = false
                notificationMessage = "Replace failed: \(error.localizedDescription)"
                showNotification = true
            }
        }
    }

    private func openDiffPreview(for group: CodeSearchFileGroup) {
        let options = CodeSearchOptions(
            caseSensitive: caseSensitive,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilter,
            scope: selectedScope,
            replacementText: replaceQuery
        )
        if let preview = CodeSearchEngine.diffPreview(for: group.fullURL, query: searchQuery, replacement: replaceQuery, options: options) {
            previewGroup = group
            diffPreviewData = preview
            showDiffPreviewSheet = true
        }
    }

    private func diffPreviewSheet(group: CodeSearchFileGroup, preview: (original: String, modified: String, diffLines: [(type: CodeSearchEngine.DiffLineType, text: String)])) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interactive Diff Preview: \(group.fileName)")
                        .font(.headline)
                    Text(group.filePath)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    showDiffPreviewSheet = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(preview.diffLines.enumerated()), id: \.offset) { _, diff in
                        Text(diff.text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(diffColor(diff.type))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .background(diffBackground(diff.type))
                    }
                }
                .padding(8)
            }
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    showDiffPreviewSheet = false
                }
                Button("Apply Replacement to File") {
                    showDiffPreviewSheet = false
                    performReplaceInFile(group: group)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 640, minHeight: 440)
    }

    private func diffColor(_ t: CodeSearchEngine.DiffLineType) -> Color {
        switch t {
        case .same: return .secondary
        case .added: return .green
        case .removed: return .red
        }
    }

    private func diffBackground(_ t: CodeSearchEngine.DiffLineType) -> Color {
        switch t {
        case .same: return .clear
        case .added: return Color.green.opacity(0.12)
        case .removed: return Color.red.opacity(0.12)
        }
    }

    private func openResult(_ match: CodeSearchMatch) {
        let node = FileNode(name: match.fileName, path: match.filePath, isDirectory: false)
        sessionStore.openFile(node)
        dismiss()
    }
}
