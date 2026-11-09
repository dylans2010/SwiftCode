import SwiftUI
import AppKit
import SwiftCodeGitHub
import YcodeIDECore

@MainActor
struct GitHubCodeSearchView: View {
    let project: Project?

    enum SearchMode: String, CaseIterable, Identifiable {
        case local = "Local Code Search"
        case discover = "GitHub Discover"

        var id: String { rawValue }
    }

    enum DiscoverType: String, CaseIterable, Identifiable {
        case repositories = "Repositories"
        case users = "Users"
        case code = "Code"
        case issues = "Issues & PRs"
        case topics = "Topics"

        var id: String { rawValue }
    }

    @State private var mode: SearchMode = .local

    @State private var localQuery = ""
    @State private var localResults: [String] = []
    @State private var isLocalSearching = false

    @State private var discoverQuery = ""
    @State private var discoverType: DiscoverType = .repositories
    @State private var isDiscoverSearching = false
    @State private var discoverResults: [DiscoverResultItem] = []

    @State private var filterLanguage = ""
    @State private var filterLicense = ""
    @State private var filterStars = ""
    @State private var filterForks = ""
    @State private var filterSize = ""
    @State private var filterOrg = ""
    @State private var filterTopic = ""
    @State private var filterArchived = false
    @State private var filterVisibility = "all"

    @State private var selectedRepoFullName: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Search Mode", selection: $mode) {
                ForEach(SearchMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .frame(maxWidth: 400)

            Divider()

            switch mode {
            case .local:
                localSearchPane
            case .discover:
                discoverPane
            }
        }
        .sheet(item: Binding<RepoSelection?>(
            get: { selectedRepoFullName.map { RepoSelection(fullName: $0) } },
            set: { selectedRepoFullName = $0?.fullName }
        )) { selection in
            PublicRepositoryBrowserView(repoFullName: selection.fullName, client: GitHubTokenProvider.client())
        }
    }

    private var localSearchPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search local codebase content...", text: $localQuery)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            performLocalSearch()
                        }
                }
                .padding(6)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    performLocalSearch()
                } label: {
                    Text("Search")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isLocalSearching || localQuery.isEmpty)
            }
            .padding()
            .liquidGlass(style: .subtle, cornerRadius: 10)

            Divider()

            if isLocalSearching {
                GitHubLoadingView(message: "Searching codebase...")
            } else if localResults.isEmpty {
                GitHubEmptyStateView(
                    title: "Code Search",
                    description: "Search local codebase files for pattern matching or variable declarations.",
                    systemImage: "doc.text.magnifyingglass",
                    accentColor: .orange
                )
            } else {
                List(localResults, id: \.self) { result in
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.orange)
                        Text(result)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func performLocalSearch() {
        guard let project = project else { return }
        isLocalSearching = true
        localResults.removeAll()

        Task {
            do {
                let fileManager = FileManager.default
                let dirURL = project.directoryURL

                guard let enumerator = fileManager.enumerator(at: dirURL, includingPropertiesForKeys: nil) else {
                    isLocalSearching = false
                    return
                }

                var matched: [String] = []
                while let fileURL = enumerator.nextObject() as? URL {
                    if fileURL.pathExtension == "swift" || fileURL.pathExtension == "txt" || fileURL.pathExtension == "md" {
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        if content.contains(localQuery) {
                            let relPath = fileURL.path.replacingOccurrences(of: dirURL.path + "/", with: "")
                            matched.append(relPath)
                        }
                    }
                }
                self.localResults = matched
            } catch {
            }
            isLocalSearching = false
        }
    }

    private var discoverPane: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 14) {
                Text("ADVANCED FILTERS")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                Group {
                    filterField(label: "Language", placeholder: "e.g. Swift", text: $filterLanguage)
                    filterField(label: "License", placeholder: "e.g. mit", text: $filterLicense)
                    filterField(label: "Min Stars", placeholder: "e.g. 500", text: $filterStars)
                    filterField(label: "Min Forks", placeholder: "e.g. 100", text: $filterForks)
                    filterField(label: "Min Size (KB)", placeholder: "e.g. 1000", text: $filterSize)
                    filterField(label: "Organization/Owner", placeholder: "e.g. apple", text: $filterOrg)
                    filterField(label: "Topic", placeholder: "e.g. swiftui", text: $filterTopic)
                }

                Toggle("Exclude Archived", isOn: Binding(
                    get: { !filterArchived },
                    set: { filterArchived = !$0 }
                ))
                .font(.caption)

                Picker("Visibility", selection: $filterVisibility) {
                    Text("All").tag("all")
                    Text("Public").tag("public")
                    Text("Private").tag("private")
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)

                Spacer()

                Button("Reset Filters") {
                    filterLanguage = ""
                    filterLicense = ""
                    filterStars = ""
                    filterForks = ""
                    filterSize = ""
                    filterOrg = ""
                    filterTopic = ""
                    filterArchived = false
                    filterVisibility = "all"
                    triggerDiscoverSearch()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding(14)
            .frame(width: 220)
            .background(Color(NSColor.windowBackgroundColor))

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Picker("Search For", selection: $discoverType) {
                        ForEach(DiscoverType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .frame(width: 140)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search GitHub...", text: $discoverQuery)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                triggerDiscoverSearch()
                            }
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                    Button {
                        triggerDiscoverSearch()
                    } label: {
                        Text("Search")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isDiscoverSearching || discoverQuery.isEmpty)
                }
                .padding()
                .background(Color.secondary.opacity(0.03))

                Divider()

                if isDiscoverSearching {
                    GitHubLoadingView(message: "Searching GitHub...")
                } else if discoverResults.isEmpty {
                    GitHubEmptyStateView(
                        title: "Discover GitHub",
                        description: "Find repositories, users, or topics live from GitHub API.",
                        systemImage: "globe",
                        accentColor: .orange
                    )
                } else {
                    List(discoverResults) { item in
                        DiscoverResultRow(item: item) {
                            if discoverType == .repositories || discoverType == .code || discoverType == .issues {
                                selectedRepoFullName = item.repoFullName ?? item.title
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func filterField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onChange(of: text.wrappedValue) {
                    triggerDiscoverSearch()
                }
        }
    }

    private func triggerDiscoverSearch() {
        guard !discoverQuery.isEmpty else { return }

        var queryParts = [discoverQuery]

        if !filterLanguage.isEmpty { queryParts.append("language:\(filterLanguage)") }
        if !filterLicense.isEmpty { queryParts.append("license:\(filterLicense)") }
        if !filterStars.isEmpty { queryParts.append("stars:>=\(filterStars)") }
        if !filterForks.isEmpty { queryParts.append("forks:>=\(filterForks)") }
        if !filterSize.isEmpty { queryParts.append("size:>=\(filterSize)") }
        if !filterOrg.isEmpty { queryParts.append("org:\(filterOrg)") }
        if !filterTopic.isEmpty { queryParts.append("topic:\(filterTopic)") }
        if filterArchived { queryParts.append("archived:true") }
        if filterVisibility == "public" { queryParts.append("is:public") }
        if filterVisibility == "private" { queryParts.append("is:private") }

        let compositeQuery = queryParts.joined(separator: " ")

        isDiscoverSearching = true
        Task {
            do {
                switch discoverType {
                case .repositories:
                    let res = try await GitHubTokenProvider.service().searchRepositories(query: compositeQuery)
                    self.discoverResults = res.items.map { item in
                        DiscoverResultItem(
                            id: item.id,
                            title: item.fullName,
                            description: item.description ?? "No description",
                            subDetails: "★ \(item.stargazersCount)  ⑂ \(item.forksCount)  • \(item.language ?? "Unknown")",
                            repoFullName: item.fullName,
                            iconName: "folder.fill"
                        )
                    }

                case .users:
                    let users = try await GitHubTokenProvider.service().searchUsers(query: compositeQuery)
                    self.discoverResults = users.map { item in
                        DiscoverResultItem(
                            id: "\(item.id)",
                            title: item.login,
                            description: item.htmlUrl,
                            subDetails: "Profile ID: \(item.id)",
                            repoFullName: nil,
                            iconName: "person.crop.circle.fill"
                        )
                    }

                case .code:
                    let res = try await GitHubTokenProvider.service().searchCode(query: compositeQuery)
                    self.discoverResults = res.items.enumerated().map { (index, item) in
                        DiscoverResultItem(
                            id: "\(index)",
                            title: item.name,
                            description: item.path,
                            subDetails: "Repository: \(item.repositoryFullName)",
                            repoFullName: item.repositoryFullName,
                            iconName: "doc.text.fill"
                        )
                    }

                case .issues:
                    let res = try await GitHubTokenProvider.service().searchIssues(query: compositeQuery)
                    self.discoverResults = res.items.map { item in
                        let repoFullName = item.htmlUrl
                            .replacingOccurrences(of: "https://github.com/", with: "")
                            .components(separatedBy: "/").prefix(2).joined(separator: "/")
                        return DiscoverResultItem(
                            id: "\(item.id)",
                            title: "#\(item.number): \(item.title)",
                            description: "State: \(item.state.uppercased())",
                            subDetails: repoFullName,
                            repoFullName: repoFullName,
                            iconName: "exclamationmark.circle.fill"
                        )
                    }

                case .topics:
                    let topics = try await GitHubTokenProvider.service().searchTopics(query: compositeQuery)
                    self.discoverResults = topics.enumerated().map { (index, item) in
                        DiscoverResultItem(
                            id: "\(index)",
                            title: item.name,
                            description: item.shortDescription ?? "No description",
                            subDetails: "Released: \(item.released ?? "N/A")",
                            repoFullName: nil,
                            iconName: "tag.fill"
                        )
                    }
                }
            } catch {
                self.discoverResults = []
            }
            isDiscoverSearching = false
        }
    }

}

struct RepoSelection: Identifiable {
    var id: String { fullName }
    let fullName: String
}

struct DiscoverResultItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let subDetails: String
    let repoFullName: String?
    let iconName: String
}

struct DiscoverResultRow: View {
    let item: DiscoverResultItem
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.iconName)
                    .foregroundStyle(.orange)
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(item.subDetails)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if item.repoFullName != nil {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }
}

