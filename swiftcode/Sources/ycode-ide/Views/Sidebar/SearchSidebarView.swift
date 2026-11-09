import SwiftUI
import YcodeIDECore
import YcodeIDEShell

struct SearchSidebarView: View {
    @Environment(WorkspaceViewModel.self) var workspaceVM

    
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var isReplaceMode = false

    
    @State private var matchCase = false
    @State private var wholeWord = false
    @State private var useRegex = false
    @State private var fileFilters = ""
    @State private var selectedScope: CodeSearchScope = .entireProject
    @State private var showOptions = false

    
    @State private var fileGroups: [CodeSearchFileGroup] = []
    @State private var isSearching = false
    @State private var currentSearchTask: Task<Void, Never>?
    @State private var searchDebounceTask: Task<Void, Never>?

    
    @State private var previewGroup: CodeSearchFileGroup?
    @State private var diffPreviewData: (original: String, modified: String, diffLines: [(type: CodeSearchEngine.DiffLineType, text: String)])?
    @State private var showDiffPreview = false

    
    @State private var statusAlertMessage: String?
    @State private var showStatusAlert = false

    var body: some View {
        VStack(spacing: 0) {
            
            VStack(spacing: 8) {
                HStack {
                    Picker("", selection: $isReplaceMode) {
                        Text("Find").tag(false)
                        Text("Replace").tag(true)
                    }
                    .pickerStyle(.segmented)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showOptions.toggle()
                        }
                    } label: {
                        Image(systemName: showOptions ? "slider.horizontal.2.square.on.square" : "slider.horizontal.3")
                            .foregroundStyle(showOptions || !fileFilters.isEmpty || selectedScope != .entireProject ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Search options and scope")
                }

                
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search in workspace...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onChange(of: searchText) { _, _ in
                            scheduleSearch()
                        }
                        .onSubmit {
                            triggerImmediateSearch()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            fileGroups = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    
                    HStack(spacing: 2) {
                        toggleButton(title: "Aa", isOn: $matchCase, tooltip: "Match Case")
                        toggleButton(title: "\\b", isOn: $wholeWord, tooltip: "Match Whole Word")
                        toggleButton(title: ".*", isOn: $useRegex, tooltip: "Regular Expression")
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                
                if isReplaceMode {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.arrow.left")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        TextField("Replace with...", text: $replaceText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()

                        if !replaceText.isEmpty {
                            Button {
                                replaceText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        if totalMatchCount > 0 && !searchText.isEmpty {
                            Button {
                                performReplaceAllInProject()
                            } label: {
                                Text("All")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("Replace all matches across project")
                        }
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                
                if showOptions {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Scope:")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Picker("", selection: $selectedScope) {
                                Text("Entire Project").tag(CodeSearchScope.entireProject)
                                Text("Open Files").tag(CodeSearchScope.openFiles)
                            }
                            .pickerStyle(.menu)
                            .controlSize(.small)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("File Filters (e.g. *.swift, !*.generated.swift):")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            HStack {
                                TextField("include/exclude filters...", text: $fileFilters)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                    .onChange(of: fileFilters) { _, _ in scheduleSearch() }

                                if !fileFilters.isEmpty {
                                    Button("Clear") { fileFilters = ""; scheduleSearch() }
                                        .buttonStyle(.plain)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .transition(.opacity)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            Divider()

            
            if totalMatchCount > 0 {
                HStack {
                    Text(stats.summaryText)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()
            }

            
            if isSearching {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Searching workspace...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if fileGroups.isEmpty && !searchText.isEmpty {
                ContentUnavailableView("No matches found", systemImage: "magnifyingglass", description: Text("No occurrences found matching your query and filter criteria."))
            } else if fileGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Find & Replace in Files")
                        .font(.headline)
                    Text("Search across code, assets, and project files with regex, case, and scope filters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
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
                .listStyle(.sidebar)
            }
        }
        .sheet(isPresented: $showDiffPreview) {
            if let preview = diffPreviewData, let group = previewGroup {
                diffPreviewSheet(group: group, preview: preview)
            }
        }
        .alert("Replace in Files", isPresented: $showStatusAlert) {
            Button("OK") {}
        } message: {
            Text(statusAlertMessage ?? "")
        }
    }

    private var stats: CodeSearchStats {
        CodeSearchStats(totalMatches: totalMatchCount, totalFiles: fileGroups.count)
    }

    private var totalMatchCount: Int {
        fileGroups.reduce(0) { $0 + $1.matches.count }
    }

    private var allExpanded: Bool {
        fileGroups.allSatisfy(\.isExpanded)
    }

    private func toggleButton(title: String, isOn: Binding<Bool>, tooltip: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            scheduleSearch()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(isOn.wrappedValue ? Color.accentColor.opacity(0.2) : Color.clear)
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : Color.secondary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isOn.wrappedValue ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
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
                .font(.caption.bold())
                .lineLimit(1)

            Text("(\(group.wrappedValue.matches.count))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if isReplaceMode && !replaceText.isEmpty {
                Button {
                    openDiffPreview(for: group.wrappedValue)
                } label: {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Preview replacement diff")

                Button {
                    performReplaceInFile(group: group.wrappedValue)
                } label: {
                    Text("Replace")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help("Replace all occurrences in this file")
            }
        }
        .padding(.vertical, 2)
    }

    private func matchRow(match: CodeSearchMatch, group: CodeSearchFileGroup) -> some View {
        Button {
            Task {
                await workspaceVM.editor.openFile(url: match.fullURL)
            }
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Text("L\(match.lineNumber)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundStyle(.secondary)
                    .cornerRadius(4)

                highlightedSnippet(match.lineContent, query: searchText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isReplaceMode && !replaceText.isEmpty {
                    Button {
                        performReplaceSingle(match: match)
                    } label: {
                        Image(systemName: "arrow.right.arrow.left")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Replace this occurrence")
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private func highlightedSnippet(_ snippet: String, query: String) -> Text {
        guard !query.isEmpty else {
            return Text(snippet).font(.system(size: 11, design: .monospaced))
        }

        let options: NSString.CompareOptions = matchCase ? [] : [.caseInsensitive]
        if let range = snippet.range(of: query, options: options) {
            let prefix = String(snippet[..<range.lowerBound])
            let match = String(snippet[range])
            let suffix = String(snippet[range.upperBound...])

            var prefixAttr = AttributedString(prefix)
            prefixAttr.font = .system(size: 11, design: .monospaced)
            prefixAttr.foregroundColor = .secondary

            var matchAttr = AttributedString(match)
            matchAttr.font = .system(size: 11, design: .monospaced).bold()
            matchAttr.foregroundColor = .orange
            matchAttr.backgroundColor = Color.orange.opacity(0.2)

            var suffixAttr = AttributedString(suffix)
            suffixAttr.font = .system(size: 11, design: .monospaced)
            suffixAttr.foregroundColor = .secondary

            var combined = prefixAttr
            combined.append(matchAttr)
            combined.append(suffixAttr)

            return Text(combined)
        }

        return Text(snippet).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
    }

    private func scheduleSearch() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if !Task.isCancelled {
                triggerImmediateSearch()
            }
        }
    }

    private func triggerImmediateSearch() {
        currentSearchTask?.cancel()
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fileGroups = []
            return
        }

        isSearching = true
        let query = searchText
        let root = workspaceVM.projectURL
        let options = CodeSearchOptions(
            caseSensitive: matchCase,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilters,
            scope: selectedScope,
            replacementText: replaceText
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

    private func performReplaceSingle(match: CodeSearchMatch) {
        let options = CodeSearchOptions(
            caseSensitive: matchCase,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilters,
            scope: selectedScope,
            replacementText: replaceText
        )
        Task {
            do {
                try await CodeSearchEngine.replace(match: match, with: replaceText, options: options)
                triggerImmediateSearch()
            } catch {
                statusAlertMessage = "Replace failed: \(error.localizedDescription)"
                showStatusAlert = true
            }
        }
    }

    private func performReplaceInFile(group: CodeSearchFileGroup) {
        let options = CodeSearchOptions(
            caseSensitive: matchCase,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilters,
            scope: selectedScope,
            replacementText: replaceText
        )
        Task {
            do {
                let count = try await CodeSearchEngine.replaceAll(in: group, query: searchText, replacement: replaceText, options: options)
                statusAlertMessage = "Replaced \(count) occurrence\(count == 1 ? "" : "s") in \(group.fileName)."
                showStatusAlert = true
                triggerImmediateSearch()
            } catch {
                statusAlertMessage = "Replace failed: \(error.localizedDescription)"
                showStatusAlert = true
            }
        }
    }

    private func performReplaceAllInProject() {
        let options = CodeSearchOptions(
            caseSensitive: matchCase,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilters,
            scope: selectedScope,
            replacementText: replaceText
        )
        let groups = fileGroups
        Task {
            do {
                let (files, replacements) = try await CodeSearchEngine.replaceAll(in: groups, query: searchText, replacement: replaceText, options: options)
                statusAlertMessage = "Successfully replaced \(replacements) occurrence\(replacements == 1 ? "" : "s") across \(files) file\(files == 1 ? "" : "s")."
                showStatusAlert = true
                triggerImmediateSearch()
            } catch {
                statusAlertMessage = "Replace failed: \(error.localizedDescription)"
                showStatusAlert = true
            }
        }
    }

    private func openDiffPreview(for group: CodeSearchFileGroup) {
        let options = CodeSearchOptions(
            caseSensitive: matchCase,
            wholeWord: wholeWord,
            useRegex: useRegex,
            fileFilters: fileFilters,
            scope: selectedScope,
            replacementText: replaceText
        )
        if let preview = CodeSearchEngine.diffPreview(for: group.fullURL, query: searchText, replacement: replaceText, options: options) {
            previewGroup = group
            diffPreviewData = preview
            showDiffPreview = true
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
                    showDiffPreview = false
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
                    showDiffPreview = false
                }
                Button("Apply Replacement to File") {
                    showDiffPreview = false
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
}
