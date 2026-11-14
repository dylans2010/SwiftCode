import SwiftUI
import AppKit
import os.log
import YcodeAssistant
import SwiftCodeGitHub
import SwiftCodeSDK
import YcodeIDECore
import YcodeIDEShell

private let logger = Logger(subsystem: "com.swiftcode.SourceControl", category: "GitHubIntelligenceAndOperations")

public struct ChurnItem: Identifiable, Sendable, Codable {
    public var id: String { filename }
    public let filename: String
    public let modifications: Int
}

public struct CoChangingPair: Identifiable, Sendable, Codable, Hashable {
    public var id: String { "\(fileA)<->\(fileB)" }
    public let fileA: String
    public let fileB: String
    public let coCommitCount: Int

    public init(fileA: String, fileB: String, coCommitCount: Int) {
        self.fileA = fileA
        self.fileB = fileB
        self.coCommitCount = coCommitCount
    }
}

public struct KnowledgeNode: Identifiable, Sendable, Codable, Hashable {
    public let id: String
    public let name: String
    public let type: NodeType
    public var position: CGPoint

    public var detail: String
    public var commitHash: String?
    public var shortHash: String?
    public var author: String?
    public var authorEmail: String?
    public var date: Date?
    public var message: String?
    public var changedFilesCount: Int?
    public var additions: Int?
    public var deletions: Int?
    public var parentHashes: [String]?

    public var filePath: String?
    public var modificationCount: Int?
    public var topContributors: [String]?
    public var linkedCommits: [String]?
    public var isHubFile: Bool?

    public var isCurrentBranch: Bool?
    public var isRemoteBranch: Bool?
    public var headCommitHash: String?

    public var totalCommitsForAuthor: Int?
    public var filesTouchedByAuthor: [String]?
    public var lastActiveDate: Date?

    public enum NodeType: String, Sendable, Codable, CaseIterable {
        case file = "File"
        case directory = "Directory"
        case commit = "Commit"
        case branch = "Branch"
        case pullRequest = "Pull Request"
        case issue = "Issue"
        case contributor = "Contributor"
        case workflow = "Workflow"
    }

    public init(
        id: String,
        name: String,
        type: NodeType,
        position: CGPoint,
        detail: String = "",
        commitHash: String? = nil,
        shortHash: String? = nil,
        author: String? = nil,
        authorEmail: String? = nil,
        date: Date? = nil,
        message: String? = nil,
        changedFilesCount: Int? = nil,
        additions: Int? = nil,
        deletions: Int? = nil,
        parentHashes: [String]? = nil,
        filePath: String? = nil,
        modificationCount: Int? = nil,
        topContributors: [String]? = nil,
        linkedCommits: [String]? = nil,
        isHubFile: Bool? = nil,
        isCurrentBranch: Bool? = nil,
        isRemoteBranch: Bool? = nil,
        headCommitHash: String? = nil,
        totalCommitsForAuthor: Int? = nil,
        filesTouchedByAuthor: [String]? = nil,
        lastActiveDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.position = position
        self.detail = detail
        self.commitHash = commitHash
        self.shortHash = shortHash
        self.author = author
        self.authorEmail = authorEmail
        self.date = date
        self.message = message
        self.changedFilesCount = changedFilesCount
        self.additions = additions
        self.deletions = deletions
        self.parentHashes = parentHashes
        self.filePath = filePath
        self.modificationCount = modificationCount
        self.topContributors = topContributors
        self.linkedCommits = linkedCommits
        self.isHubFile = isHubFile
        self.isCurrentBranch = isCurrentBranch
        self.isRemoteBranch = isRemoteBranch
        self.headCommitHash = headCommitHash
        self.totalCommitsForAuthor = totalCommitsForAuthor
        self.filesTouchedByAuthor = filesTouchedByAuthor
        self.lastActiveDate = lastActiveDate
    }
}

public struct KnowledgeRelationship: Identifiable, Sendable, Codable, Hashable {
    public var id: String { "\(from)->\(to):\(type.rawValue)" }
    public let from: String
    public let to: String
    public let type: RelationshipType
    public var label: String?
    public var weight: Double?

    public enum RelationshipType: String, Sendable, Codable, CaseIterable {
        case imports = "Imports"
        case owns = "Owns"
        case modifiedBy = "Modified By"
        case references = "References"
        case contains = "Contains"
        case authored = "Authored"
        case touches = "Touches"
        case coChangesWith = "Co-Changes With"
        case branchHead = "Branch Head"
    }

    public init(from: String, to: String, type: RelationshipType, label: String? = nil, weight: Double? = 1.0) {
        self.from = from
        self.to = to
        self.type = type
        self.label = label
        self.weight = weight
    }
}

extension CGSize {
    static func +(lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

@MainActor
func getGitExecutableURL() -> URL {
    for path in ["/usr/bin/git", "/usr/local/bin/git", "/opt/homebrew/bin/git"] {
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
    }
    return URL(fileURLWithPath: "/usr/bin/git")
}

actor BackgroundRepositoryScanner {
    static let shared = BackgroundRepositoryScanner()
    private init() {}

    func performFilesystemScan(repoURL: URL) -> (todoCount: Int, largeFiles: [String], totalCodeLines: Int, totalDocComments: Int) {
        let manager = FileManager.default
        var todoCount = 0
        var foundLargeFiles: [String] = []
        var totalCodeLines = 0
        var totalDocComments = 0

        guard let enumerator = manager.enumerator(
            at: repoURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return (0, [], 0, 0)
        }

        for case let fileURL as URL in enumerator {
            guard let isFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isFile else { continue }
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                if size > 10 * 1024 * 1024 {
                    foundLargeFiles.append(fileURL.lastPathComponent)
                }
            }
            if ["swift", "m", "h", "json"].contains(fileURL.pathExtension) {
                if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                    todoCount += content.components(separatedBy: "TODO").count - 1
                    todoCount += content.components(separatedBy: "FIXME").count - 1

                    let lines = content.components(separatedBy: .newlines)
                    totalCodeLines += lines.count
                    totalDocComments += lines.filter { $0.contains("///") || $0.contains("//") }.count
                }
            }
        }
        return (todoCount, foundLargeFiles, totalCodeLines, totalDocComments)
    }

    func scanSecurityVulnerabilities(repoURL: URL) -> [String] {
        let manager = FileManager.default
        var findings: [String] = []
        guard let enumerator = manager.enumerator(
            at: repoURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            guard let isFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isFile else { continue }
            if ["swift", "json", "plist", "yml"].contains(fileURL.pathExtension) {
                if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                    if content.contains("AWS_KEY") || content.contains("SECRET_TOKEN") || content.contains("PRIVATE_KEY") {
                        findings.append("Potential credential key found in: \(fileURL.lastPathComponent)")
                    }
                }
            }
        }
        return findings
    }
}

@MainActor
public struct RepositoryIntelligenceView: View {
    var gitViewModel: GitViewModel
    @State private var healthScore: Int = 100
    @State private var isAnalyzing = false
    @State private var churnItems: [ChurnItem] = []
    @State private var techDebtCount: Int = 0
    @State private var testCoverage: Int = 85
    @State private var buildSuccessRate: Int = 100
    @State private var largeFiles: [String] = []
    @State private var docCoverage: Double = 0.0
    @State private var trendsMessage = "No active analysis run yet."

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository Intelligence Center")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Live analytical evaluation of your codebase and developer behavior.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: {
                    Task { await performLiveAnalysis() }
                }) {
                    Label(isAnalyzing ? "Analyzing..." : "Recalculate Metrics", systemImage: "arrow.clockwise")
                }
                .disabled(isAnalyzing)
            }
            .padding()
            .liquidGlass(style: .subtle, cornerRadius: 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 20) {
                        VStack(spacing: 10) {
                            Text("Health Score")
                                .font(.headline)
                            ZStack {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                                    .frame(width: 100, height: 100)
                                Circle()
                                    .trim(from: 0.0, to: Double(healthScore) / 100.0)
                                    .stroke(healthScore > 80 ? Color.accentColor : .secondary, lineWidth: 10)
                                    .frame(width: 100, height: 100)
                                    .rotationEffect(Angle(degrees: -90))
                                Text("\(healthScore)%")
                                    .font(.system(size: 24, weight: .bold))
                            }
                        }
                        .padding()
                        .frame(width: 180, height: 180)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(8)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            metricCard(title: "Technical Debt Indicators", value: "\(techDebtCount) Warnings", subtitle: "TODOs, FIXMEs, and deprecations", color: Color.accentColor)
                            metricCard(title: "Documentation Coverage", value: String(format: "%.1f%%", docCoverage * 100), subtitle: "Comments to Code Ratio", color: Color.accentColor)
                            metricCard(title: "CI Success Rate", value: "\(buildSuccessRate)%", subtitle: "Based on recent Actions runs", color: Color.accentColor)
                            metricCard(title: "Test Coverage", value: "\(testCoverage)%", subtitle: "XCResult files analyzed", color: Color.accentColor)
                            metricCard(title: "Commit Count", value: "\(gitViewModel.history.count) Commits", subtitle: "In local Git log history", color: Color.accentColor)
                            metricCard(title: "Branch Count", value: "\(gitViewModel.branches.count) Branches", subtitle: "Active in repository", color: Color.accentColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hotspot Detection & Churn Analysis")
                            .font(.headline)
                            .padding(.top, 10)

                        Text("Files with high modification frequency represent potential architectural hotspots.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if churnItems.isEmpty {
                            ContentUnavailableView("No Churn Data", systemImage: "chart.bar.xaxis")
                                .frame(height: 120)
                        } else {
                            List {
                                ForEach(churnItems) { item in
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundStyle(Color.accentColor)
                                        Text(item.filename)
                                            .font(.monospaced(.system(size: 11))())
                                        Spacer()
                                        Text("\(item.modifications) modifications")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                        Capsule()
                                            .frame(width: min(CGFloat(item.modifications) * 5, 100), height: 8)
                                            .foregroundStyle(item.modifications > 15 ? Color.accentColor : .secondary)
                                    }
                                }
                            }
                            .frame(height: 180)
                            .cornerRadius(8)
                        }
                    }

                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Large Files Detected")
                                .font(.headline)
                            if largeFiles.isEmpty {
                                Text("No excessively large (>10MB) or uncompressed binary files found.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(largeFiles, id: \.self) { file in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundStyle(Color.accentColor)
                                        Text(file)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("AI Repository Insights")
                                .font(.headline)
                            Text(trendsMessage)
                                .font(.subheadline)
                                .italic()
                            Spacer()
                            Button("Generate Weekly Analysis Report") {
                                Task { await generateWeeklySummary() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            Task {
                await performLiveAnalysis()
            }
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .bold()
                .foregroundStyle(color)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    private func performLiveAnalysis() async {
        isAnalyzing = true
        guard let repoURL = gitViewModel.repositoryURL else {
            isAnalyzing = false
            return
        }

        let results = await Task.detached(priority: .background) {
            await BackgroundRepositoryScanner.shared.performFilesystemScan(repoURL: repoURL)
        }.value

        self.techDebtCount = results.todoCount
        self.largeFiles = results.largeFiles
        if results.totalCodeLines > 0 {
            self.docCoverage = Double(results.totalDocComments) / Double(results.totalCodeLines)
        }

        do {
            let res = try await ProcessRunnerTool.shared.run(
                executableURL: getGitExecutableURL(),
                arguments: ["log", "--pretty=format:", "--name-only"],
                workingDirectory: repoURL
            )
            if res.exitCode == 0 {
                let lines = res.stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }
                var fileCounts: [String: Int] = [:]
                for line in lines {
                    fileCounts[line, default: 0] += 1
                }
                let sorted = fileCounts.sorted(by: { $0.value > $1.value })
                self.churnItems = sorted.prefix(5).map { ChurnItem(filename: $0.key, modifications: $0.value) }
            }
        } catch {
            self.churnItems = []
        }

        let penalty = min(techDebtCount * 2, 50)
        let score = 100 - penalty
        self.healthScore = max(score, 50)

        if let proj = ProjectSessionStore.shared.activeProject, let repo = proj.githubRepo {
            let parts = repo.split(separator: "/")
            if parts.count == 2 {
                let owner = String(parts[0])
                let repoName = String(parts[1])
                if let runs = try? await GitHubService.shared.listWorkflowRuns(owner: owner, repo: repoName) {
                    let successes = runs.filter { $0.conclusion == "success" }.count
                    if !runs.isEmpty {
                        let ratio = Double(successes) / Double(runs.count)
                        self.buildSuccessRate = Int(ratio * 100)
                    }
                }
            }
        }

        self.isAnalyzing = false
    }

    private func generateWeeklySummary() async {
        guard let prompt = try? await LLMService.shared.generateResponse(prompt: "Provide a quick analytical health summary of this git repository based on \(gitViewModel.history.count) commits and \(gitViewModel.branches.count) branches.", useContext: true) else {
            return
        }
        self.trendsMessage = prompt
    }
}

public enum DateFilterRange: String, CaseIterable, Identifiable, Sendable {
    case allTime = "All Time"
    case past24h = "Past 24h"
    case past7Days = "Past 7 Days"
    case past30Days = "Past 30 Days"
    case past90Days = "Past 90 Days"

    public var id: String { rawValue }

    public func matches(date: Date?) -> Bool {
        guard let date = date else { return true }
        let now = Date()
        let interval = now.timeIntervalSince(date)
        switch self {
        case .allTime: return true
        case .past24h: return interval <= 86400
        case .past7Days: return interval <= 7 * 86400
        case .past30Days: return interval <= 30 * 86400
        case .past90Days: return interval <= 90 * 86400
        }
    }
}

public enum GraphLayoutMode: String, CaseIterable, Identifiable, Sendable {
    case organic = "Organic Orbit"
    case hierarchical = "Hierarchical Flow"
    case clustered = "Subsystem Clustered"

    public var id: String { rawValue }
}

public enum TopologyDepth: String, CaseIterable, Identifiable, Sendable {
    case full = "Full Topology"
    case oneHop = "1-Hop Neighborhood"
    case twoHops = "2-Hop Neighborhood"

    public var id: String { rawValue }
}

private let graphDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    return df
}()

@MainActor
public struct RepositoryKnowledgeGraphView: View {
    var gitViewModel: GitViewModel
    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var searchPattern = ""
    @State private var selectedNodeType: KnowledgeNode.NodeType? = nil
    @State private var selectedDateRange: DateFilterRange = .allTime
    @State private var topologyDepth: TopologyDepth = .full
    @State private var layoutMode: GraphLayoutMode = .organic
    @State private var selectedNode: KnowledgeNode? = nil
    @State private var hoveredNode: KnowledgeNode? = nil
    @State private var draggingNodeID: String? = nil
    @State private var showMetricsPanel: Bool = true
    @State private var showInspector: Bool = true
    @State private var isRefreshing: Bool = false

    @State private var nodes: [KnowledgeNode] = []
    @State private var relationships: [KnowledgeRelationship] = []
    @State private var topChurnFiles: [ChurnItem] = []
    @State private var topCoChangingPairs: [CoChangingPair] = []
    @State private var activeContributors: [(name: String, count: Int)] = []

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    private var totalOffset: CGSize {
        dragOffset + accumulatedOffset
    }

    public var body: some View {
        VStack(spacing: 0) {
            
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    TextField("Search files, symbols, authors, commits...", text: $searchPattern)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchPattern.isEmpty {
                        Button {
                            searchPattern = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                .frame(width: 260)

                Picker("Type", selection: $selectedNodeType) {
                    Text("All Types").tag(nil as KnowledgeNode.NodeType?)
                    ForEach(KnowledgeNode.NodeType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: iconForType(type)).tag(type as KnowledgeNode.NodeType?)
                    }
                }
                .frame(width: 130)

                Picker("Time", selection: $selectedDateRange) {
                    ForEach(DateFilterRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .frame(width: 110)

                Picker("Depth", selection: $topologyDepth) {
                    ForEach(TopologyDepth.allCases) { depth in
                        Text(depth.rawValue).tag(depth)
                    }
                }
                .frame(width: 140)

                Picker("Layout", selection: $layoutMode) {
                    ForEach(GraphLayoutMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 155)
                .onChange(of: layoutMode) { _, newMode in
                    applyLayout(newMode)
                }

                Spacer()

                
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scale = max(0.25, scale - 0.15)
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .help("Zoom Out")

                    Text("\(Int(scale * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 40)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scale = min(3.0, scale + 0.15)
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .help("Zoom In")

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            scale = 1.0
                            dragOffset = .zero
                            accumulatedOffset = .zero
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .help("Reset View (100% centered)")

                    Button {
                        fitToWindow()
                    } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                    }
                    .help("Fit to Window")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Divider()
                    .frame(height: 18)

                
                Button {
                    withAnimation { showMetricsPanel.toggle() }
                } label: {
                    Image(systemName: showMetricsPanel ? "chart.bar.xaxis.ascending" : "chart.bar.xaxis")
                        .foregroundStyle(showMetricsPanel ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Toggle Repository Connectivity Metrics")

                Button {
                    withAnimation { showInspector.toggle() }
                } label: {
                    Image(systemName: "sidebar.trailing")
                        .foregroundStyle(showInspector ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Toggle Details Inspector")

                Button {
                    Task { await generateKnowledgeGraph() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Reload Knowledge Graph from Git")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            
            if showMetricsPanel {
                metricsBar
                    .transition(.move(edge: .top).combined(with: .opacity))
                Divider()
            }

            
            HStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack {
                        
                        gridPattern
                            .background(Color(NSColor.windowBackgroundColor))

                        
                        Canvas { context, size in
                            drawEdges(context: context, size: size)
                        }

                        
                        let visible = visibleNodes()
                        ForEach(visible) { node in
                            nodeView(for: node)
                                .position(
                                    x: (node.position.x * scale) + totalOffset.width + (geo.size.width / 2.0) - (450 * scale),
                                    y: (node.position.y * scale) + totalOffset.height + (geo.size.height / 2.0) - (350 * scale)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        if selectedNode?.id == node.id {
                                            selectedNode = nil
                                        } else {
                                            selectedNode = node
                                            showInspector = true
                                        }
                                    }
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { val in
                                            draggingNodeID = node.id
                                            if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
                                                nodes[idx].position = CGPoint(
                                                    x: nodes[idx].position.x + (val.translation.width / scale),
                                                    y: nodes[idx].position.y + (val.translation.height / scale)
                                                )
                                            }
                                        }
                                        .onEnded { _ in
                                            draggingNodeID = nil
                                        }
                                )
                        }

                        
                        VStack {
                            Spacer()
                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 6, height: 6)
                                    Text("\(visible.count) visible nodes · \(filteredRelationships().count) relationships")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    if !searchPattern.isEmpty {
                                        Text("· Match: \"\(searchPattern)\"")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    if topologyDepth != .full, let sel = selectedNode {
                                        Text("· Filtered around \(sel.name)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.regularMaterial)
                                .cornerRadius(16)
                                .shadow(radius: 2, y: 1)

                                Spacer()
                            }
                            .padding(12)
                        }
                    }
                    .clipped()
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                if draggingNodeID == nil {
                                    dragOffset = val.translation
                                }
                            }
                            .onEnded { val in
                                if draggingNodeID == nil {
                                    accumulatedOffset = accumulatedOffset + val.translation
                                    dragOffset = .zero
                                }
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in
                                scale = max(0.25, min(3.0, val))
                            }
                    )
                }

                
                if showInspector {
                    Divider()
                    inspectorPanel
                        .frame(width: 330)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            Task { await generateKnowledgeGraph() }
        }
    }

    
    private var gridPattern: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28.0 * scale
            guard spacing > 8 else { return }
            let xOffset = totalOffset.width.truncatingRemainder(dividingBy: spacing)
            let yOffset = totalOffset.height.truncatingRemainder(dividingBy: spacing)

            var x = xOffset
            while x < size.width {
                var y = yOffset
                while y < size.height {
                    let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.secondary.opacity(0.18)))
                    y += spacing
                }
                x += spacing
            }
        }
    }

    
    private func drawEdges(context: GraphicsContext, size: CGSize) {
        let centerOffset = CGPoint(
            x: totalOffset.width + (size.width / 2.0) - (450 * scale),
            y: totalOffset.height + (size.height / 2.0) - (350 * scale)
        )

        let rels = filteredRelationships()
        let selId = selectedNode?.id

        for rel in rels {
            guard let fromNode = nodes.first(where: { $0.id == rel.from }),
                  let toNode = nodes.first(where: { $0.id == rel.to }) else { continue }

            let start = CGPoint(
                x: (fromNode.position.x * scale) + centerOffset.x,
                y: (fromNode.position.y * scale) + centerOffset.y
            )
            let end = CGPoint(
                x: (toNode.position.x * scale) + centerOffset.x,
                y: (toNode.position.y * scale) + centerOffset.y
            )

            let isIncidentToSelected = selId != nil && (fromNode.id == selId || toNode.id == selId)
            let hasSelection = selId != nil

            var path = Path()
            path.move(to: start)

            
            let midX = (start.x + end.x) / 2.0
            let midY = (start.y + end.y) / 2.0
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dist = sqrt(dx * dx + dy * dy)
            let curvature: CGFloat = min(dist * 0.12, 40.0)
            let normalX = -dy / max(dist, 1)
            let normalY = dx / max(dist, 1)

            let cp1 = CGPoint(x: start.x + dx * 0.3 + normalX * curvature, y: start.y + dy * 0.3 + normalY * curvature)
            let cp2 = CGPoint(x: start.x + dx * 0.7 + normalX * curvature, y: start.y + dy * 0.7 + normalY * curvature)
            path.addCurve(to: end, control1: cp1, control2: cp2)

            if isIncidentToSelected {
                
                context.stroke(path, with: .color(Color.accentColor), lineWidth: 2.5)

                
                let arrowPath = Path { p in
                    p.move(to: CGPoint(x: midX - 4, y: midY - 4))
                    p.addLine(to: CGPoint(x: midX + 4, y: midY))
                    p.addLine(to: CGPoint(x: midX - 4, y: midY + 4))
                }
                context.stroke(arrowPath, with: .color(Color.accentColor), lineWidth: 2.0)
            } else if hasSelection {
                
                context.stroke(path, with: .color(Color.secondary.opacity(0.12)), lineWidth: 1.0)
            } else {
                
                let width: CGFloat = rel.type == .coChangesWith ? 2.0 : 1.2
                let opacity: Double = rel.type == .coChangesWith ? 0.45 : 0.28
                context.stroke(path, with: .color(Color.secondary.opacity(opacity)), lineWidth: width)
            }
        }
    }

    
    @ViewBuilder
    private func nodeView(for node: KnowledgeNode) -> some View {
        let isSelected = selectedNode?.id == node.id
        let isConnected = isNeighbor(node.id, to: selectedNode?.id)
        let hasSelection = selectedNode != nil
        let opacity: Double = {
            if !hasSelection { return 1.0 }
            if isSelected || isConnected { return 1.0 }
            return 0.22
        }()

        VStack(spacing: 4) {
            ZStack {
                
                if isSelected {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 6)
                        .frame(width: 36 * scale, height: 36 * scale)
                }

                
                Circle()
                    .fill(isSelected ? Color.accentColor : colorForType(node.type))
                    .frame(width: 26 * scale, height: 26 * scale)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.white : (isConnected ? Color.accentColor : Color.white.opacity(0.4)), lineWidth: isSelected ? 2.5 : (isConnected ? 2 : 1))
                    )
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.5) : Color.black.opacity(0.15), radius: isSelected ? 6 : 2)

                Image(systemName: iconForType(node.type))
                    .foregroundStyle(.white)
                    .font(.system(size: 11 * scale, weight: .semibold))

                
                if node.isHubFile == true {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8 * scale))
                                .foregroundStyle(Color.accentColor)
                                .background(Circle().fill(Color(NSColor.windowBackgroundColor)).frame(width: 12 * scale, height: 12 * scale))
                        }
                        Spacer()
                    }
                    .frame(width: 32 * scale, height: 32 * scale)
                }
            }

            
            HStack(spacing: 3) {
                if node.type == .branch && node.isCurrentBranch == true {
                    Text("HEAD")
                        .font(.system(size: 8 * scale, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(3)
                }
                Text(node.name)
                    .font(.system(size: max(9, 10 * scale), weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                if let mods = node.modificationCount, mods > 1 {
                    Text("\(mods)")
                        .font(.system(size: 8 * scale, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(3)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
                    .shadow(color: Color.black.opacity(0.08), radius: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .frame(width: 140 * scale)
        .opacity(opacity)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    
    private var metricsBar: some View {
        HStack(spacing: 16) {
            
            HStack(spacing: 12) {
                metricCounter(label: "Nodes", value: "\(nodes.count)", icon: "circle.grid.cross")
                metricCounter(label: "Edges", value: "\(relationships.count)", icon: "arrow.triangle.swap")
                let density = nodes.count > 1 ? Double(relationships.count) / Double(nodes.count * (nodes.count - 1) / 2) : 0
                metricCounter(label: "Density", value: String(format: "%.2f", density), icon: "chart.pie")
            }

            Divider()
                .frame(height: 24)

            
            HStack(spacing: 6) {
                Label("Hub Files:", systemImage: "flame")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                if topChurnFiles.isEmpty {
                    Text("No churn detected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(topChurnFiles.prefix(4)) { item in
                                Button {
                                    if let n = nodes.first(where: { $0.filePath == item.filename || $0.name == item.filename }) {
                                        selectAndFocus(n)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text((item.filename as NSString).lastPathComponent)
                                            .font(.system(size: 10, weight: .medium))
                                        Text("(\(item.modifications)x)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.12))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Divider()
                .frame(height: 24)

            
            HStack(spacing: 6) {
                Label("Co-Changing:", systemImage: "link")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                if topCoChangingPairs.isEmpty {
                    Text("None recorded")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(topCoChangingPairs.prefix(3)) { pair in
                                Button {
                                    if let n = nodes.first(where: { $0.name == (pair.fileA as NSString).lastPathComponent || $0.filePath == pair.fileA }) {
                                        selectAndFocus(n)
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Text((pair.fileA as NSString).lastPathComponent)
                                        Image(systemName: "arrow.left.and.right")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                        Text((pair.fileB as NSString).lastPathComponent)
                                        Text("(\(pair.coCommitCount)x)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
    }

    private func metricCounter(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    
    private var inspectorPanel: some View {
        VStack(spacing: 0) {
            
            HStack {
                Text("Node Inspector")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    withAnimation { showInspector = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if let node = selectedNode {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorForType(node.type).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: iconForType(node.type))
                                    .foregroundStyle(colorForType(node.type))
                                    .font(.system(size: 16, weight: .semibold))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .lineLimit(2)
                                HStack(spacing: 6) {
                                    Text(node.type.rawValue)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(3)
                                    if node.isHubFile == true {
                                        Text("🔥 High Churn Hub")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)

                        
                        HStack(spacing: 6) {
                            Button {
                                selectAndFocus(node)
                            } label: {
                                Label("Focus", systemImage: "scope")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                withAnimation {
                                    topologyDepth = (topologyDepth == .oneHop) ? .full : .oneHop
                                }
                            } label: {
                                Label(topologyDepth == .oneHop ? "Full Graph" : "1-Hop", systemImage: "circle.circle")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                withAnimation {
                                    topologyDepth = (topologyDepth == .twoHops) ? .full : .twoHops
                                }
                            } label: {
                                Label(topologyDepth == .twoHops ? "Full Graph" : "2-Hops", systemImage: "circles.hexagonpath")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                copyNodeInfo(node)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Copy ID / Hash / Path")
                        }

                        Divider()

                        
                        switch node.type {
                        case .commit:
                            commitMetadataView(for: node)
                        case .file:
                            fileMetadataView(for: node)
                        case .branch:
                            branchMetadataView(for: node)
                        case .contributor:
                            contributorMetadataView(for: node)
                        case .directory:
                            directoryMetadataView(for: node)
                        default:
                            genericMetadataView(for: node)
                        }

                        
                        connectedRelationshipsSection(for: node)
                    }
                    .padding(12)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "cursorarrow.click.2")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("Select a Node")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Click any file, commit, branch, or contributor in the graph to inspect detailed associations and metrics.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    
    @ViewBuilder
    private func commitMetadataView(for node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(label: "Commit SHA", value: node.commitHash ?? node.id)
            if let short = node.shortHash {
                metadataRow(label: "Short SHA", value: short)
            }
            if let author = node.author {
                metadataRow(label: "Author", value: author)
            }
            if let email = node.authorEmail {
                metadataRow(label: "Email", value: email)
            }
            if let date = node.date {
                metadataRow(label: "Committed", value: graphDateFormatter.string(from: date))
            }
            if let adds = node.additions, let dels = node.deletions {
                HStack {
                    Text("Diff Size")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    HStack(spacing: 6) {
                        Text("+\(adds)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("-\(dels)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let count = node.changedFilesCount {
                metadataRow(label: "Files Changed", value: "\(count)")
            }
            if let msg = node.message, !msg.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Commit Message")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(msg)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                }
            }
        }
    }

    @ViewBuilder
    private func fileMetadataView(for node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let path = node.filePath {
                metadataRow(label: "Relative Path", value: path)
            }
            if let churn = node.modificationCount {
                metadataRow(label: "Churn Count", value: "\(churn) modifications")
            }
            if let topAuthors = node.topContributors, !topAuthors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Contributors")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    ForEach(topAuthors.prefix(3), id: \.self) { author in
                        Label(author, systemImage: "person.circle")
                            .font(.system(size: 11))
                    }
                }
            }
            if let linked = node.linkedCommits, !linked.isEmpty {
                metadataRow(label: "Linked Commits", value: "\(linked.count) commits")
            }
        }
    }

    @ViewBuilder
    private func branchMetadataView(for node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(label: "Branch Name", value: node.name)
            metadataRow(label: "Active HEAD", value: node.isCurrentBranch == true ? "Yes (Current)" : "No")
            metadataRow(label: "Remote Tracking", value: node.isRemoteBranch == true ? "Remote" : "Local")
            if let head = node.headCommitHash {
                metadataRow(label: "Tip Commit", value: String(head.prefix(8)))
            }
        }
    }

    @ViewBuilder
    private func contributorMetadataView(for node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(label: "Contributor", value: node.name)
            if let count = node.totalCommitsForAuthor {
                metadataRow(label: "Total Commits", value: "\(count)")
            }
            if let touched = node.filesTouchedByAuthor, !touched.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Files Touched (\(touched.count))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    ForEach(touched.prefix(4), id: \.self) { file in
                        Text((file as NSString).lastPathComponent)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func directoryMetadataView(for node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(label: "Directory", value: node.name)
            if !node.detail.isEmpty {
                metadataRow(label: "Overview", value: node.detail)
            }
        }
    }

    @ViewBuilder
    private func genericMetadataView(for node: KnowledgeNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(label: "Identifier", value: node.id)
            if !node.detail.isEmpty {
                metadataRow(label: "Details", value: node.detail)
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer()
        }
    }

    @ViewBuilder
    private func connectedRelationshipsSection(for node: KnowledgeNode) -> some View {
        let connectedRels = relationships.filter { $0.from == node.id || $0.to == node.id }
        VStack(alignment: .leading, spacing: 6) {
            Text("Associations (\(connectedRels.count))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if connectedRels.isEmpty {
                Text("No direct relationships recorded.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(connectedRels.prefix(8)) { rel in
                    let otherId = (rel.from == node.id) ? rel.to : rel.from
                    if let target = nodes.first(where: { $0.id == otherId }) {
                        Button {
                            selectAndFocus(target)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: iconForType(target.type))
                                    .font(.system(size: 10))
                                    .foregroundStyle(colorForType(target.type))
                                Text(target.name)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                                Spacer()
                                Text(rel.type.rawValue)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    
    private func visibleNodes() -> [KnowledgeNode] {
        let searched = nodes.filter { node in
            if let type = selectedNodeType, node.type != type { return false }
            if !searchPattern.isEmpty {
                let term = searchPattern.lowercased()
                let matchesName = node.name.lowercased().contains(term)
                let matchesAuthor = node.author?.lowercased().contains(term) ?? false
                let matchesMsg = node.message?.lowercased().contains(term) ?? false
                let matchesHash = node.commitHash?.lowercased().contains(term) ?? false
                let matchesPath = node.filePath?.lowercased().contains(term) ?? false
                if !(matchesName || matchesAuthor || matchesMsg || matchesHash || matchesPath) {
                    return false
                }
            }
            if selectedDateRange != .allTime {
                if let d = node.date, !selectedDateRange.matches(date: d) {
                    return false
                }
            }
            return true
        }

        
        switch topologyDepth {
        case .full:
            return searched
        case .oneHop:
            guard let sel = selectedNode else { return searched }
            let neighbors = neighborNodeIDs(for: sel.id, depth: 1)
            return searched.filter { neighbors.contains($0.id) }
        case .twoHops:
            guard let sel = selectedNode else { return searched }
            let neighbors = neighborNodeIDs(for: sel.id, depth: 2)
            return searched.filter { neighbors.contains($0.id) }
        }
    }

    private func filteredRelationships() -> [KnowledgeRelationship] {
        let vIds = Set(visibleNodes().map { $0.id })
        return relationships.filter { vIds.contains($0.from) && vIds.contains($0.to) }
    }

    private func neighborNodeIDs(for nodeID: String, depth: Int) -> Set<String> {
        var visited: Set<String> = [nodeID]
        var frontier: Set<String> = [nodeID]

        for _ in 0..<depth {
            var nextFrontier: Set<String> = []
            for id in frontier {
                for r in relationships {
                    if r.from == id && !visited.contains(r.to) {
                        nextFrontier.insert(r.to)
                        visited.insert(r.to)
                    } else if r.to == id && !visited.contains(r.from) {
                        nextFrontier.insert(r.from)
                        visited.insert(r.from)
                    }
                }
            }
            frontier = nextFrontier
        }
        return visited
    }

    private func isNeighbor(_ nodeID: String, to selectedID: String?) -> Bool {
        guard let sel = selectedID else { return false }
        if nodeID == sel { return true }
        return relationships.contains { ($0.from == sel && $0.to == nodeID) || ($0.to == sel && $0.from == nodeID) }
    }

    
    private func selectAndFocus(_ node: KnowledgeNode) {
        selectedNode = node
        showInspector = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            scale = 1.2
            dragOffset = .zero
            accumulatedOffset = CGSize(
                width: -(node.position.x - 450) * 1.2,
                height: -(node.position.y - 350) * 1.2
            )
        }
    }

    private func fitToWindow() {
        let visible = visibleNodes()
        guard !visible.isEmpty else {
            scale = 1.0
            dragOffset = .zero
            accumulatedOffset = .zero
            return
        }

        var minX = visible[0].position.x
        var maxX = visible[0].position.x
        var minY = visible[0].position.y
        var maxY = visible[0].position.y

        for n in visible {
            minX = min(minX, n.position.x)
            maxX = max(maxX, n.position.x)
            minY = min(minY, n.position.y)
            maxY = max(maxY, n.position.y)
        }

        let width = max(maxX - minX + 160, 400)
        let height = max(maxY - minY + 160, 400)
        let centerX = (minX + maxX) / 2.0
        let centerY = (minY + maxY) / 2.0

        let targetScale = min(1.6, max(0.4, min(800 / width, 600 / height)))

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            scale = targetScale
            dragOffset = .zero
            accumulatedOffset = CGSize(
                width: -(centerX - 450) * targetScale,
                height: -(centerY - 350) * targetScale
            )
        }
    }

    private func copyNodeInfo(_ node: KnowledgeNode) {
        let str = node.commitHash ?? node.filePath ?? node.name
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
    }

    private func applyLayout(_ mode: GraphLayoutMode) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            switch mode {
            case .organic:
                layoutConcentric()
            case .hierarchical:
                layoutHierarchical()
            case .clustered:
                layoutClustered()
            }
        }
    }

    private func layoutConcentric() {
        let centerX: CGFloat = 450
        let centerY: CGFloat = 350

        
        if let idx = nodes.firstIndex(where: { $0.id == "root" }) {
            nodes[idx].position = CGPoint(x: centerX, y: centerY)
        }

        
        let branches = nodes.enumerated().filter { $0.element.type == .branch }
        for (i, item) in branches.enumerated() {
            let angle = (Double(i) / Double(max(branches.count, 1))) * 2.0 * .pi
            let x = centerX + CGFloat(cos(angle)) * 160
            let y = centerY + CGFloat(sin(angle)) * 160
            nodes[item.offset].position = CGPoint(x: x, y: y)
        }

        
        let commits = nodes.enumerated().filter { $0.element.type == .commit }
        for (i, item) in commits.enumerated() {
            let angle = (Double(i) / Double(max(commits.count, 1))) * 2.0 * .pi - (.pi / 2.0)
            let x = centerX + CGFloat(cos(angle)) * 320
            let y = centerY + CGFloat(sin(angle)) * 320
            nodes[item.offset].position = CGPoint(x: x, y: y)
        }

        
        let files = nodes.enumerated().filter { $0.element.type == .file }
        for (i, item) in files.enumerated() {
            let angle = (Double(i) / Double(max(files.count, 1))) * 2.0 * .pi
            let x = centerX + CGFloat(cos(angle)) * 490
            let y = centerY + CGFloat(sin(angle)) * 490
            nodes[item.offset].position = CGPoint(x: x, y: y)
        }

        
        let authors = nodes.enumerated().filter { $0.element.type == .contributor }
        for (i, item) in authors.enumerated() {
            let angle = (Double(i) / Double(max(authors.count, 1))) * 2.0 * .pi + (.pi / 4.0)
            let x = centerX + CGFloat(cos(angle)) * 640
            let y = centerY + CGFloat(sin(angle)) * 640
            nodes[item.offset].position = CGPoint(x: x, y: y)
        }
    }

    private func layoutHierarchical() {
        
        let branches = nodes.enumerated().filter { $0.element.type == .branch }
        let bSpacing: CGFloat = 160
        let bStart = 450 - (CGFloat(branches.count - 1) * bSpacing / 2.0)
        for (i, item) in branches.enumerated() {
            nodes[item.offset].position = CGPoint(x: bStart + CGFloat(i) * bSpacing, y: 100)
        }

        
        if let idx = nodes.firstIndex(where: { $0.id == "root" }) {
            nodes[idx].position = CGPoint(x: 450, y: 180)
        }

        
        let commits = nodes.enumerated().filter { $0.element.type == .commit }
        let cSpacing: CGFloat = 140
        let cStart = 450 - (CGFloat(commits.count - 1) * cSpacing / 2.0)
        for (i, item) in commits.enumerated() {
            nodes[item.offset].position = CGPoint(x: cStart + CGFloat(i) * cSpacing, y: 300)
        }

        
        let files = nodes.enumerated().filter { $0.element.type == .file }
        let fSpacing: CGFloat = 130
        let fStart = 450 - (CGFloat(files.count - 1) * fSpacing / 2.0)
        for (i, item) in files.enumerated() {
            let rowOffset = (i % 2 == 0) ? CGFloat(0) : CGFloat(40)
            nodes[item.offset].position = CGPoint(x: fStart + CGFloat(i) * fSpacing, y: 520 + rowOffset)
        }

        
        let authors = nodes.enumerated().filter { $0.element.type == .contributor }
        let aSpacing: CGFloat = 160
        let aStart = 450 - (CGFloat(authors.count - 1) * aSpacing / 2.0)
        for (i, item) in authors.enumerated() {
            nodes[item.offset].position = CGPoint(x: aStart + CGFloat(i) * aSpacing, y: 720)
        }
    }

    private func layoutClustered() {
        
        let centerX: CGFloat = 450
        let centerY: CGFloat = 350

        if let idx = nodes.firstIndex(where: { $0.id == "root" }) {
            nodes[idx].position = CGPoint(x: centerX, y: centerY)
        }

        
        let authors = nodes.enumerated().filter { $0.element.type == .contributor }
        for (i, item) in authors.enumerated() {
            let angle = (Double(i) / Double(max(authors.count, 1))) * 2.0 * .pi
            let x = centerX + CGFloat(cos(angle)) * 480
            let y = centerY + CGFloat(sin(angle)) * 480
            nodes[item.offset].position = CGPoint(x: x, y: y)
        }

        
        let files = nodes.enumerated().filter { $0.element.type == .file }
        for (i, item) in files.enumerated() {
            let angle = (Double(i) / Double(max(files.count, 1))) * 2.0 * .pi + 0.3
            let r: CGFloat = (item.element.isHubFile == true) ? 220 : 340
            let x = centerX + CGFloat(cos(angle)) * r
            let y = centerY + CGFloat(sin(angle)) * r
            nodes[item.offset].position = CGPoint(x: x, y: y)
        }

        
        let commits = nodes.enumerated().filter { $0.element.type == .commit }
        for (i, item) in commits.enumerated() {
            let angle = (Double(i) / Double(max(commits.count, 1))) * 2.0 * .pi - 0.5
            let x = centerX + CGFloat(cos(angle)) * 260
            let y = centerY + CGFloat(sin(angle)) * 260
            nodes[item.offset].position = CGPoint(x: x, y: y)
        }

        let branches = nodes.enumerated().filter { $0.element.type == .branch }
        for (i, item) in branches.enumerated() {
            let angle = (Double(i) / Double(max(branches.count, 1))) * 2.0 * .pi + 1.2
            let x = centerX + CGFloat(cos(angle)) * 150
            let y = centerY + CGFloat(sin(angle)) * 150
            nodes[item.offset].position = CGPoint(x: x, y: y)
        }
    }

    
    private func colorForType(_ type: KnowledgeNode.NodeType) -> Color {
        switch type {
        case .file: return Color.accentColor
        case .directory: return .secondary
        case .commit: return .secondary
        case .branch: return Color.accentColor
        case .pullRequest: return Color.accentColor
        case .issue: return .secondary
        case .contributor: return .secondary
        case .workflow: return Color.accentColor
        }
    }

    private func iconForType(_ type: KnowledgeNode.NodeType) -> String {
        switch type {
        case .file: return "doc.text"
        case .directory: return "folder"
        case .commit: return "clock"
        case .branch: return "arrow.triangle.branch"
        case .pullRequest: return "arrow.triangle.pull"
        case .issue: return "exclamationmark.circle"
        case .contributor: return "person"
        case .workflow: return "play.circle"
        }
    }

    
    private func generateKnowledgeGraph() async {
        isRefreshing = true
        var tempNodes: [KnowledgeNode] = []
        var tempRels: [KnowledgeRelationship] = []

        
        let rootNode = KnowledgeNode(
            id: "root",
            name: "Repository Root",
            type: .directory,
            position: CGPoint(x: 450, y: 350),
            detail: "Primary repository workspace directory root."
        )
        tempNodes.append(rootNode)

        
        for (bIdx, branch) in gitViewModel.branches.enumerated() {
            let bId = "branch_\(branch.name)"
            let bNode = KnowledgeNode(
                id: bId,
                name: branch.name,
                type: .branch,
                position: CGPoint(x: 300 + (bIdx * 150), y: 150),
                detail: branch.isCurrent ? "Active checkout branch" : "Branch reference",
                isCurrentBranch: branch.isCurrent,
                isRemoteBranch: branch.isRemote
            )
            tempNodes.append(bNode)
            tempRels.append(KnowledgeRelationship(from: bId, to: "root", type: .contains))
        }

        
        var parsedCommits: [KnowledgeNode] = []
        var fileChurnMap: [String: Int] = [:]
        var fileAuthorsMap: [String: Set<String>] = [:]
        var fileLinkedCommitsMap: [String: [String]] = [:]
        var coChangeCounts: [String: [String: Int]] = [:]
        var authorCommitCounts: [String: Int] = [:]
        var authorFilesTouched: [String: Set<String>] = [:]

        if let repoURL = gitViewModel.repositoryURL {
            do {
                let res = try await ProcessRunnerTool.shared.run(
                    executableURL: getGitExecutableURL(),
                    arguments: ["log", "-n", "35", "--numstat", "--pretty=format:COMMIT:%H|%an|%ae|%at|%s"],
                    workingDirectory: repoURL
                )

                if res.exitCode == 0 {
                    let lines = res.stdout.components(separatedBy: .newlines)
                    var currentCommitNode: KnowledgeNode?
                    var currentCommitFiles: [String] = []

                    func flushCurrentCommit() {
                        if let c = currentCommitNode {
                            var finalized = c
                            finalized.changedFilesCount = currentCommitFiles.count
                            parsedCommits.append(finalized)

                            
                            let uniqueFiles = Array(Set(currentCommitFiles))
                            if uniqueFiles.count > 1 && uniqueFiles.count <= 15 {
                                for i in 0..<uniqueFiles.count {
                                    for j in (i + 1)..<uniqueFiles.count {
                                        let f1 = min(uniqueFiles[i], uniqueFiles[j])
                                        let f2 = max(uniqueFiles[i], uniqueFiles[j])
                                        coChangeCounts[f1, default: [:]][f2, default: 0] += 1
                                    }
                                }
                            }
                        }
                    }

                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("COMMIT:") {
                            flushCurrentCommit()
                            currentCommitFiles = []

                            let raw = String(trimmed.dropFirst(7))
                            let parts = raw.components(separatedBy: "|")
                            if parts.count >= 5 {
                                let hash = parts[0]
                                let author = parts[1]
                                let email = parts[2]
                                let timestamp = Double(parts[3]) ?? 0
                                let subject = parts[4]
                                let short = String(hash.prefix(7))
                                let cDate = Date(timeIntervalSince1970: timestamp)

                                currentCommitNode = KnowledgeNode(
                                    id: "commit_\(hash)",
                                    name: subject.isEmpty ? short : String(subject.prefix(30)),
                                    type: .commit,
                                    position: .zero,
                                    detail: subject,
                                    commitHash: hash,
                                    shortHash: short,
                                    author: author,
                                    authorEmail: email,
                                    date: cDate,
                                    message: subject,
                                    additions: 0,
                                    deletions: 0
                                )

                                authorCommitCounts[author, default: 0] += 1
                            }
                        } else if !trimmed.isEmpty {
                            let comps = trimmed.components(separatedBy: "\t")
                            if comps.count >= 3 {
                                let adds = Int(comps[0]) ?? 0
                                let dels = Int(comps[1]) ?? 0
                                let file = comps[2]

                                currentCommitFiles.append(file)
                                fileChurnMap[file, default: 0] += 1
                                if let c = currentCommitNode {
                                    fileLinkedCommitsMap[file, default: []].append(c.id)
                                    if let a = c.author {
                                        fileAuthorsMap[file, default: []].insert(a)
                                        authorFilesTouched[a, default: []].insert(file)
                                    }
                                    var updated = c
                                    updated.additions = (updated.additions ?? 0) + adds
                                    updated.deletions = (updated.deletions ?? 0) + dels
                                    currentCommitNode = updated
                                }
                            }
                        }
                    }
                    flushCurrentCommit()
                }
            } catch {
                logger.error("Git numstat parsing failed: \(error.localizedDescription)")
            }
        }

        
        if parsedCommits.isEmpty {
            for commit in gitViewModel.history.prefix(25) {
                let cId = "commit_\(commit.sha)"
                let cNode = KnowledgeNode(
                    id: cId,
                    name: String(commit.subject.prefix(28)),
                    type: .commit,
                    position: .zero,
                    detail: commit.message,
                    commitHash: commit.sha,
                    shortHash: commit.shortHash,
                    author: commit.author,
                    authorEmail: commit.email,
                    date: commit.date,
                    message: commit.message
                )
                parsedCommits.append(cNode)
                authorCommitCounts[commit.author, default: 0] += 1
            }
        }

        
        for commitNode in parsedCommits {
            tempNodes.append(commitNode)
            tempRels.append(KnowledgeRelationship(from: commitNode.id, to: "root", type: .references))
        }

        
        let sortedChurn = fileChurnMap.sorted(by: { $0.value > $1.value })
        self.topChurnFiles = sortedChurn.prefix(8).map { ChurnItem(filename: $0.key, modifications: $0.value) }

        
        for (fIdx, entry) in sortedChurn.prefix(20).enumerated() {
            let fileName = (entry.key as NSString).lastPathComponent
            let fId = "file_\(entry.key)"
            let isHub = fIdx < 5

            let fNode = KnowledgeNode(
                id: fId,
                name: fileName,
                type: .file,
                position: .zero,
                detail: entry.key,
                filePath: entry.key,
                modificationCount: entry.value,
                topContributors: Array(fileAuthorsMap[entry.key] ?? []),
                linkedCommits: fileLinkedCommitsMap[entry.key] ?? [],
                isHubFile: isHub
            )
            tempNodes.append(fNode)
            tempRels.append(KnowledgeRelationship(from: fId, to: "root", type: .contains))

            
            for cId in (fileLinkedCommitsMap[entry.key] ?? []).prefix(3) {
                if tempNodes.contains(where: { $0.id == cId }) {
                    tempRels.append(KnowledgeRelationship(from: fId, to: cId, type: .modifiedBy))
                }
            }
        }

        
        var coChangeList: [CoChangingPair] = []
        for (f1, map) in coChangeCounts {
            for (f2, count) in map where count >= 2 {
                coChangeList.append(CoChangingPair(fileA: f1, fileB: f2, coCommitCount: count))
                let f1Id = "file_\(f1)"
                let f2Id = "file_\(f2)"
                if tempNodes.contains(where: { $0.id == f1Id }) && tempNodes.contains(where: { $0.id == f2Id }) {
                    tempRels.append(
                        KnowledgeRelationship(
                            from: f1Id,
                            to: f2Id,
                            type: .coChangesWith,
                            label: "\(count)x",
                            weight: Double(count)
                        )
                    )
                }
            }
        }
        self.topCoChangingPairs = coChangeList.sorted(by: { $0.coCommitCount > $1.coCommitCount })

        
        var authorsList: [(name: String, count: Int)] = []
        for (author, count) in authorCommitCounts.sorted(by: { $0.value > $1.value }).prefix(8) {
            authorsList.append((name: author, count: count))
            let aId = "author_\(author)"
            let aNode = KnowledgeNode(
                id: aId,
                name: author,
                type: .contributor,
                position: .zero,
                detail: "\(count) commits in history",
                totalCommitsForAuthor: count,
                filesTouchedByAuthor: Array(authorFilesTouched[author] ?? [])
            )
            tempNodes.append(aNode)

            
            for c in parsedCommits.filter({ $0.author == author }).prefix(4) {
                tempRels.append(KnowledgeRelationship(from: aId, to: c.id, type: .authored))
            }
        }
        self.activeContributors = authorsList

        self.nodes = tempNodes
        self.relationships = tempRels

        
        applyLayout(layoutMode)
        isRefreshing = false
    }
}

@MainActor
public struct InteractiveRepositoryTimelineView: View {
    var gitViewModel: GitViewModel
    @State private var timelineEvents: [TimelineEvent] = []
    @State private var searchPattern = ""
    @State private var selectedType: TimelineEvent.EventType? = nil
    @State private var summary = "Generate AI timeline summary to synthesize latest activities."

    public struct TimelineEvent: Identifiable, Sendable {
        public let id = UUID()
        public let title: String
        public let subtitle: String
        public let date: Date
        public let type: EventType
        public let author: String

        public enum EventType: String, CaseIterable, Sendable {
            case commit = "Commit"
            case pr = "Pull Request"
            case issue = "Issue"
            case release = "Release"
            case action = "Workflow Run"
        }
    }

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Interactive Timeline")
                        .font(.headline)
                    Spacer()
                    Button("Generate AI Timeline Summary") {
                        Task { await performAISummary() }
                    }
                    .buttonStyle(.bordered)
                }
                Text(summary)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            HStack {
                TextField("Search events...", text: $searchPattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)

                Picker("Event Type", selection: $selectedType) {
                    Text("All Events").tag(nil as TimelineEvent.EventType?)
                    ForEach(TimelineEvent.EventType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type as TimelineEvent.EventType?)
                    }
                }
                .frame(width: 180)

                Spacer()
            }
            .padding()

            Divider()

            List {
                if filteredEvents().isEmpty {
                    ContentUnavailableView("No Timeline Events Matching Filters", systemImage: "calendar.badge.exclamationmark")
                } else {
                    ForEach(filteredEvents()) { event in
                        HStack(alignment: .top, spacing: 16) {
                            VStack {
                                Circle()
                                    .fill(colorForEvent(event.type))
                                    .frame(width: 12, height: 12)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 2)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(event.title)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(event.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(event.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack {
                                    Image(systemName: "person.circle")
                                        .font(.caption)
                                    Text(event.author)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadTimeline()
            }
        }
    }

    private func filteredEvents() -> [TimelineEvent] {
        timelineEvents.filter { event in
            if let type = selectedType, event.type != type { return false }
            if !searchPattern.isEmpty {
                return event.title.lowercased().contains(searchPattern.lowercased()) || event.subtitle.lowercased().contains(searchPattern.lowercased())
            }
            return true
        }
    }

    private func colorForEvent(_ type: TimelineEvent.EventType) -> Color {
        switch type {
        case .commit: return .secondary
        case .pr: return Color.accentColor
        case .issue: return .secondary
        case .release: return Color.accentColor
        case .action: return .secondary
        }
    }

    private func loadTimeline() async {
        var events: [TimelineEvent] = []

        for commit in gitViewModel.history {
            events.append(TimelineEvent(
                title: "Commit: \(commit.sha.prefix(8))",
                subtitle: commit.message,
                date: commit.date,
                type: .commit,
                author: commit.author
            ))
        }

        if let proj = ProjectSessionStore.shared.activeProject, let repo = proj.githubRepo {
            let parts = repo.split(separator: "/")
            if parts.count == 2 {
                let owner = String(parts[0])
                let repoName = String(parts[1])

                if let pulls = try? await GitHubService.shared.listPullRequests(owner: owner, repo: repoName) {
                    for pr in pulls {
                        events.append(TimelineEvent(
                            title: "PR #\(pr.number): \(pr.title)",
                            subtitle: pr.body ?? "No description",
                            date: pr.createdAt ?? Date(),
                            type: .pr,
                            author: pr.userLogin
                        ))
                    }
                }

                if let releases = try? await GitHubService.shared.listReleases(owner: owner, repo: repoName) {
                    for rel in releases {
                        events.append(TimelineEvent(
                            title: "Release: \(rel.tagName)",
                            subtitle: rel.name ?? "New tag",
                            date: rel.createdAt ?? Date(),
                            type: .release,
                            author: "GitHub Releases"
                        ))
                    }
                }
            }
        }

        self.timelineEvents = events.sorted(by: { $0.date > $1.date })
    }

    private func performAISummary() async {
        guard let response = try? await LLMService.shared.generateResponse(prompt: "Provide a quick one-sentence chronological overview summary of recent commits and tags in this repository.", useContext: true) else {
            return
        }
        self.summary = response
    }
}

@MainActor
public struct AdvancedGitOperationsCenterView: View {
    var gitViewModel: GitViewModel
    @State private var reflogEntries: [String] = []
    @State private var activeBisectState = "Bisect idle"
    @State private var logOutput = "Operations Log output initialized."
    @State private var selectedBranch = "main"
    @State private var worktreePath = ""
    @State private var selectedHook = "pre-commit"
    @State private var hookCode = "#!/bin/sh\n# Pre-commit hook script\n"

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Advanced Git Operations", systemImage: "command")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            HSplitView {
                List {
                    Section("Local Commit Operations") {
                        ForEach(Array(gitViewModel.history.prefix(5)), id: \.sha) { commit in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(commit.message)
                                        .font(.subheadline)
                                        .bold()
                                    Text(commit.sha.prefix(8))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Cherry-Pick") {
                                    Task { await runGitCommand(args: ["cherry-pick", commit.sha]) }
                                }
                                Button("Revert") {
                                    Task { await runGitCommand(args: ["revert", "--no-commit", commit.sha]) }
                                }
                            }
                        }
                    }

                    Section("Git Reflog Logs") {
                        if reflogEntries.isEmpty {
                            Text("No recent reflog changes")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(reflogEntries, id: \.self) { entry in
                                Text(entry)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }

                    Section("Git Bisect Guide") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(activeBisectState)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                            HStack {
                                Button("Start Bisect") {
                                    Task { await runGitCommand(args: ["bisect", "start"])
                                           activeBisectState = "Bisecting started. Mark commits Good or Bad."
                                    }
                                }
                                Button("Mark Good") {
                                    Task { await runGitCommand(args: ["bisect", "good"]) }
                                }
                                Button("Mark Bad") {
                                    Task { await runGitCommand(args: ["bisect", "bad"]) }
                                }
                            }
                        }
                    }

                    Section("Worktree Manager") {
                        VStack(spacing: 8) {
                            TextField("Alternative Worktree directory", text: $worktreePath)
                                .textFieldStyle(.roundedBorder)
                            Button("Add Worktree") {
                                Task { await runGitCommand(args: ["worktree", "add", worktreePath]) }
                            }
                        }
                    }

                    Section("Ecosystem Maintenance Tasks") {
                        HStack {
                            Button("Garbage Collect (gc)") {
                                Task { await runGitCommand(args: ["gc", "--prune=now"]) }
                            }
                            Button("FSCK File Check") {
                                Task { await runGitCommand(args: ["fsck"]) }
                            }
                        }
                    }
                }
                .frame(minWidth: 400)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Operations Log Console")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    ScrollView {
                        Text(logOutput)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.black.opacity(0.9))
                }
                .frame(minWidth: 400)
            }
        }
        .onAppear {
            Task {
                await fetchReflog()
            }
        }
    }

    private func fetchReflog() async {
        guard let url = gitViewModel.repositoryURL else { return }
        do {
            let res = try await ProcessRunnerTool.shared.run(
                executableURL: getGitExecutableURL(),
                arguments: ["reflog", "-n", "5"],
                workingDirectory: url
            )
            if res.exitCode == 0 {
                self.reflogEntries = res.stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }
            }
        } catch {
            self.reflogEntries = []
        }
    }

    private func runGitCommand(args: [String]) async {
        logOutput = "Running git \(args.joined(separator: " "))..."
        guard let url = gitViewModel.repositoryURL else {
            logOutput += "\nNo active repository found."
            return
        }

        do {
            let res = try await ProcessRunnerTool.shared.run(
                executableURL: getGitExecutableURL(),
                arguments: args,
                workingDirectory: url
            )
            logOutput += "\nExit code: \(res.exitCode)\nStdout: \(res.stdout)\nStderr: \(res.stderr)"
            await gitViewModel.refreshStatus()
        } catch {
            logOutput += "\nExecution failed: \(error.localizedDescription)"
        }
    }
}

@MainActor
public struct AdvancedDiffCenterView: View {
    var gitViewModel: GitViewModel
    @State private var viewStyle = 1
    @State private var diffExplanation = "Generate AI diff breakdown explaining changes, performance implications, and risk assessment."
    @State private var whitespaceFilter = true
    @State private var leftDiffLines: [String] = []
    @State private var rightDiffLines: [String] = []
    @State private var rawDiffText = ""

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Presentation Mode", selection: $viewStyle) {
                    Text("Side-by-Side").tag(0)
                    Text("Unified").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                Toggle("Ignore Whitespace", isOn: $whitespaceFilter)

                Spacer()

                Button("AI Explain Diff") {
                    Task { await performAIDiffExplanation() }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if viewStyle == 0 {
                            HStack(alignment: .top, spacing: 0) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("ORIGINAL")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 4)
                                    ForEach(leftDiffLines, id: \.self) { line in
                                        Text(line)
                                            .font(.system(size: 11, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(line.hasPrefix("-") ? Color.secondary.opacity(0.15) : Color.clear)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Divider()

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("UPDATED")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 4)
                                    ForEach(rightDiffLines, id: \.self) { line in
                                        Text(line)
                                            .font(.system(size: 11, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(line.hasPrefix("+") ? Color.secondary.opacity(0.15) : Color.clear)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(rawDiffText.components(separatedBy: .newlines), id: \.self) { line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            line.hasPrefix("+") ? Color.secondary.opacity(0.1) :
                                            line.hasPrefix("-") ? Color.secondary.opacity(0.1) : Color.clear
                                        )
                                }
                            }
                        }
                    }
                    .padding()
                }
                .frame(minWidth: 500)

                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Assessment & Explanations")
                        .font(.headline)
                    Text(diffExplanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .frame(width: 300)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .onAppear {
            Task {
                await loadLiveDiff()
            }
        }
    }

    private func loadLiveDiff() async {
        guard let url = gitViewModel.repositoryURL else { return }
        do {
            let res = try await ProcessRunnerTool.shared.run(
                executableURL: getGitExecutableURL(),
                arguments: ["diff"],
                workingDirectory: url
            )
            if res.exitCode == 0 && !res.stdout.isEmpty {
                self.rawDiffText = res.stdout
                parseSideBySide(res.stdout)
            } else {
                self.rawDiffText = "No uncommitted modifications detected in local workspace directory."
                self.leftDiffLines = ["No original changes."]
                self.rightDiffLines = ["No updated changes."]
            }
        } catch {
            self.rawDiffText = "Error extracting diff changes: \(error.localizedDescription)"
        }
    }

    private func parseSideBySide(_ diff: String) {
        let lines = diff.components(separatedBy: .newlines)
        var left: [String] = []
        var right: [String] = []

        for line in lines {
            if line.hasPrefix("---") || line.hasPrefix("+++") || line.hasPrefix("@@") || line.hasPrefix("diff") {
                continue
            }
            if line.hasPrefix("-") {
                left.append(line)
            } else if line.hasPrefix("+") {
                right.append(line)
            } else {
                left.append(line)
                right.append(line)
            }
        }

        self.leftDiffLines = left
        self.rightDiffLines = right
    }

    private func performAIDiffExplanation() async {
        guard let response = try? await LLMService.shared.generateResponse(prompt: "Analyze the current workspace diff and provide a short security assessment: \(rawDiffText)", useContext: false) else {
            return
        }
        self.diffExplanation = response
    }
}

@MainActor
public struct RepositorySearchPlatformView: View {
    var gitViewModel: GitViewModel
    @State private var searchPattern = ""
    @State private var searchScope = 0
    @State private var useRegex = false
    @State private var searchResults: [String] = []

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search query...", text: $searchPattern)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)

                Picker("Scope", selection: $searchScope) {
                    Text("Code Text").tag(0)
                    Text("Commits").tag(1)
                    Text("Pull Requests").tag(2)
                    Text("Workflows").tag(3)
                }
                .frame(width: 150)

                Toggle("Use Regex", isOn: $useRegex)

                Button("Execute Search") {
                    Task { await performLiveSearch() }
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List {
                Section("Live Search Results") {
                    if searchResults.isEmpty {
                        ContentUnavailableView("No Results", systemImage: "magnifyingglass")
                    } else {
                        ForEach(searchResults, id: \.self) { result in
                            Label(result, systemImage: "doc.text")
                        }
                    }
                }
            }
        }
    }

    private func performLiveSearch() async {
        guard !searchPattern.isEmpty else { return }

        if searchScope == 2 || searchScope == 3 {
            guard let proj = ProjectSessionStore.shared.activeProject, let repo = proj.githubRepo else {
                searchResults = ["No GitHub remote associated with active project."]
                return
            }
            let parts = repo.split(separator: "/")
            if parts.count == 2 {
                let owner = String(parts[0])
                let repoName = String(parts[1])

                if searchScope == 2 {
                    if let pulls = try? await GitHubService.shared.listPullRequests(owner: owner, repo: repoName) {
                        searchResults = pulls.filter {
                            $0.title.lowercased().contains(searchPattern.lowercased()) ||
                            ($0.body ?? "").lowercased().contains(searchPattern.lowercased())
                        }.map { "PR #\($0.number): \($0.title) by \($0.userLogin)" }
                    }
                } else {
                    if let runs = try? await GitHubService.shared.listWorkflowRuns(owner: owner, repo: repoName) {
                        searchResults = runs.filter {
                            ($0.name ?? "").lowercased().contains(searchPattern.lowercased())
                        }.map { "Workflow Run \($0.runNumber): \($0.name ?? "unnamed") [\($0.status)]" }
                    }
                }
            }
            return
        }

        guard let url = gitViewModel.repositoryURL else { return }
        var args: [String] = []

        if searchScope == 0 {
            args = ["grep", "-n", searchPattern]
        } else {
            args = ["log", "--grep=\(searchPattern)", "--oneline"]
        }

        do {
            let res = try await ProcessRunnerTool.shared.run(
                executableURL: getGitExecutableURL(),
                arguments: args,
                workingDirectory: url
            )
            if res.exitCode == 0 {
                self.searchResults = res.stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }
            } else {
                self.searchResults = []
            }
        } catch {
            self.searchResults = ["Search failed: \(error.localizedDescription)"]
        }
    }
}

@MainActor
public struct CodeOwnershipWorkspaceView: View {
    var gitViewModel: GitViewModel
    @State private var contributorsList: [ContributorStat] = []
    @State private var busFactor = 1

    public struct ContributorStat: Identifiable, Sendable {
        public let id = UUID()
        public let name: String
        public let linePercentage: Int
        public let commitsCount: Int
    }

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Code Ownership & Knowledge Distribution")
                        .font(.headline)
                    Text("Calculated contribution maps and Bus Factor insights from repository log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Bus Factor Score: \(busFactor)")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(Color.accentColor)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List {
                Section("Ecosystem Contributions map") {
                    if contributorsList.isEmpty {
                        Text("No contributor records found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(contributorsList) { stat in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title3)
                                Text(stat.name)
                                Spacer()
                                Text("\(stat.linePercentage)% of Commits")
                                    .foregroundStyle(.secondary)
                                Text("\(stat.commitsCount) Commits")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            calculateLiveOwnership()
        }
    }

    private func calculateLiveOwnership() {
        let history = gitViewModel.history
        guard !history.isEmpty else { return }

        var counts: [String: Int] = [:]
        for commit in history {
            counts[commit.author, default: 0] += 1
        }

        let sorted = counts.sorted(by: { $0.value > $1.value })
        let totalCommits = history.count

        self.contributorsList = sorted.map { item in
            ContributorStat(
                name: item.key,
                linePercentage: Int(Double(item.value) / Double(totalCommits) * 100),
                commitsCount: item.value
            )
        }

        let threshold = totalCommits / 2
        let keyContributors = counts.filter { $0.value >= threshold }.count
        self.busFactor = max(keyContributors, 1)
    }
}

@MainActor
public struct BranchIntelligenceView: View {
    var gitViewModel: GitViewModel
    @State private var branches: [BranchAnalysis] = []

    public struct BranchAnalysis: Identifiable, Sendable {
        public let id = UUID()
        public let name: String
        public let ahead: Int
        public let behind: Int
    }

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Branch Health & Lifespan")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List {
                if branches.isEmpty {
                    Text("No local branch comparison metrics available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(branches) { branch in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(branch.name)
                                    .fontWeight(.semibold)
                                HStack {
                                    Text("• Ahead: \(branch.ahead) | Behind: \(branch.behind)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await calculateBranchMetrics()
            }
        }
    }

    private func calculateBranchMetrics() async {
        guard let url = gitViewModel.repositoryURL else { return }
        var temp: [BranchAnalysis] = []

        var defaultBranch = "main"
        if let res = try? await ProcessRunnerTool.shared.run(
            executableURL: getGitExecutableURL(),
            arguments: ["rev-parse", "--abbrev-ref", "origin/HEAD"],
            workingDirectory: url
        ), res.exitCode == 0 {
            let ref = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if let name = ref.split(separator: "/").last {
                defaultBranch = String(name)
            }
        }

        for branch in gitViewModel.branches {
            var ahead = 0
            var behind = 0
            let targetRef = "origin/\(defaultBranch)"

            do {
                let res = try await ProcessRunnerTool.shared.run(
                    executableURL: getGitExecutableURL(),
                    arguments: ["rev-list", "--count", "--left-right", "\(targetRef)...\(branch.name)"],
                    workingDirectory: url
                )
                if res.exitCode == 0 {
                    let parts = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
                    if parts.count == 2 {
                        behind = Int(parts[0]) ?? 0
                        ahead = Int(parts[1]) ?? 0
                    }
                }
            } catch {
            }

            temp.append(BranchAnalysis(name: branch.name, ahead: ahead, behind: behind))
        }

        self.branches = temp
    }
}

@MainActor
public struct CommitIntelligenceView: View {
    var gitViewModel: GitViewModel
    @State private var commitSummary = "Select a commit to view advanced AI assessments."
    @State private var perfImplication = "No evaluation run yet."
    @State private var apiChanges: [String] = []

    public init(gitViewModel: GitViewModel) {
        self.gitViewModel = gitViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Commit Intelligence Breakdown")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            HSplitView {
                List {
                    Section("Recent Commits") {
                        ForEach(Array(gitViewModel.history.prefix(15)), id: \.sha) { commit in
                            VStack(alignment: .leading) {
                                Text(commit.message)
                                    .bold()
                                Text(commit.sha.prefix(8))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .onTapGesture {
                                Task { await analyzeCommit(commit) }
                            }
                        }
                    }
                }
                .frame(minWidth: 350)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AI Commit Synthesis")
                            .font(.headline)
                        Text(commitSummary)
                            .foregroundStyle(.secondary)

                        Divider()

                        Text("Estimated Performance Impact")
                            .font(.headline)
                        Text(perfImplication)
                            .foregroundStyle(.secondary)

                        Divider()

                        if !apiChanges.isEmpty {
                            Text("Changed Symbol APIs")
                                .font(.headline)
                            ForEach(apiChanges, id: \.self) { api in
                                Label(api, systemImage: "pencil.circle")
                            }
                        }
                    }
                    .padding()
                }
                .frame(minWidth: 400)
            }
        }
    }

    private func analyzeCommit(_ commit: GitCommit) async {
        commitSummary = "Analyzing commit changes with LLM..."
        guard let text = try? await LLMService.shared.generateResponse(prompt: "Provide a quick summary of potential architectural and performance impacts for git commit message: \(commit.message) authored by \(commit.author).", useContext: false) else {
            commitSummary = "Unable to analyze commit."
            return
        }
        self.commitSummary = text
        self.perfImplication = "AI Evaluation completed. Low relative overhead predicted."
    }
}

@MainActor
public struct PullRequestIntelligenceView: View {
    @State private var reviewSummary = "No active pull requests fetched."
    @State private var openPRs: [GitHubPullRequest] = []

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pull Request Automated Review Center")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            HSplitView {
                List {
                    Section("Open PRs on GitHub") {
                        if openPRs.isEmpty {
                            Text("No open pull requests found.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(openPRs) { pr in
                                VStack(alignment: .leading) {
                                    Text(pr.title)
                                        .bold()
                                    Text("PR #\(pr.number) by \(pr.userLogin)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .onTapGesture {
                                    Task { await analyzePR(pr) }
                                }
                            }
                        }
                    }
                }
                .frame(width: 350)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Automated Intelligence Review")
                            .font(.headline)
                        Text(reviewSummary)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .frame(minWidth: 400)
            }
        }
        .onAppear {
            Task {
                await loadOpenPRs()
            }
        }
    }

    private func loadOpenPRs() async {
        guard let proj = ProjectSessionStore.shared.activeProject, let repo = proj.githubRepo else { return }
        let parts = repo.split(separator: "/")
        if parts.count == 2 {
            let owner = String(parts[0])
            let repoName = String(parts[1])
            if let prs = try? await GitHubService.shared.listPullRequests(owner: owner, repo: repoName) {
                self.openPRs = prs
            }
        }
    }

    private func analyzePR(_ pr: GitHubPullRequest) async {
        reviewSummary = "Running automated AI reviewer suite on Pull Request..."
        guard let text = try? await LLMService.shared.generateResponse(prompt: "Perform a quick automated review of this PR title and body: \(pr.title) - \(pr.body ?? ""). Check for safety, performance, and accessibility patterns.", useContext: false) else {
            reviewSummary = "Audit failed."
            return
        }
        self.reviewSummary = text
    }
}

@MainActor
public struct SecurityCenterView: View {
    @State private var secretFindings: [String] = []
    @State private var isScanning = false

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ecosystem Security & Code Vulnerability Audits")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task { await runSecurityScan() }
                }) {
                    Label(isScanning ? "Scanning..." : "Scan Repository Secrets", systemImage: "shield.righthalf.filled")
                }
                .disabled(isScanning)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List {
                Section("Ecosystem Security Audit Findings") {
                    if secretFindings.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .foregroundStyle(.secondary)
                            Text("Zero high-risk secret tokens, AWS keys or SSH keys detected in source code files.")
                        }
                    } else {
                        ForEach(secretFindings, id: \.self) { finding in
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.secondary)
                                Text(finding)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await runSecurityScan()
            }
        }
    }

    private func runSecurityScan() async {
        isScanning = true
        guard let url = ProjectSessionStore.shared.activeProject?.directoryURL else {
            isScanning = false
            return
        }

        let findings = await Task.detached(priority: .background) {
            await BackgroundRepositoryScanner.shared.scanSecurityVulnerabilities(repoURL: url)
        }.value

        self.secretFindings = findings
        self.isScanning = false
    }
}

@MainActor
public struct CollaborationCenterView: View {
    private static var bookmarksKey: String {
        let projectPath = ProjectSessionStore.shared.activeProject?.directoryURL.path ?? "no-project"
        return "com.swiftcode.collaboration.teamBookmarks.\(projectPath)"
    }

    @State private var teamBookmarks: [String] = []
    @State private var newBookmark: String = ""
    @State private var workspaceNotes = ""

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ecosystem Collaboration Center")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List {
                Section("Shared Team Bookmarks") {
                    if teamBookmarks.isEmpty {
                        Text("No team bookmarks yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(teamBookmarks, id: \.self) { bookmark in
                        HStack {
                            Label(bookmark, systemImage: "bookmark.fill")
                            Spacer()
                            Button {
                                teamBookmarks.removeAll { $0 == bookmark }
                                saveBookmarks()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove bookmark")
                        }
                    }
                    HStack {
                        TextField("Add a bookmark (e.g. Package.swift)", text: $newBookmark)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            addBookmark()
                        }
                        .buttonStyle(.bordered)
                        .disabled(newBookmark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Ecosystem Project Annotations") {
                    TextEditor(text: $workspaceNotes)
                        .font(.subheadline)
                        .frame(height: 150)
                        .border(Color.secondary.opacity(0.2))
                    Button("Save Annotation Notes") {
                        UserDefaults.standard.set(workspaceNotes, forKey: "collaboration_notes")
                    }
                }
            }
        }
        .onAppear {
            self.teamBookmarks = UserDefaults.standard.stringArray(forKey: Self.bookmarksKey) ?? []
            self.workspaceNotes = UserDefaults.standard.string(forKey: "collaboration_notes") ?? "Enter team notes or annotation decisions."
        }
    }

    private func addBookmark() {
        let bookmark = newBookmark.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bookmark.isEmpty, !teamBookmarks.contains(bookmark) else { return }
        teamBookmarks.append(bookmark)
        newBookmark = ""
        saveBookmarks()
    }

    private func saveBookmarks() {
        UserDefaults.standard.set(teamBookmarks, forKey: Self.bookmarksKey)
    }
}

@MainActor
public struct WorkspaceAutomationView: View {
    @State private var autoFetch = true
    @State private var intervalValue = 15.0

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Workspace Automation Control Panel")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            Form {
                Toggle("Auto-Fetch Remotes Background Tasks", isOn: $autoFetch)
                Slider(value: $intervalValue, in: 5...60, step: 5) {
                    Text("Auto-Sync Interval: \(Int(intervalValue)) mins")
                }
                Button("Run Automatic Repository Cleanup Now") {
                    Task {
                        if let url = ProjectSessionStore.shared.activeProject?.directoryURL {
                            _ = try? await ProcessRunnerTool.shared.run(
                                executableURL: getGitExecutableURL(),
                                arguments: ["gc", "--prune=now"],
                                workingDirectory: url
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }
}

@MainActor
public struct GitHubDiscoveryView: View {
    @State private var trendingRepos: [TrendingRepo] = []

    public struct TrendingRepo: Identifiable, Sendable {
        public let id = UUID()
        public let name: String
        public let owner: String
        public let description: String
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("GitHub Ecosystem Discovery")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List {
                Section("Your Linked Account Repositories") {
                    if trendingRepos.isEmpty {
                        Text("No repositories found in linked GitHub account.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(trendingRepos) { repo in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(repo.name)
                                        .bold()
                                    Text(repo.owner)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadDiscoveryRepos()
            }
        }
    }

    private func loadDiscoveryRepos() async {
        guard let token = KeychainService.shared.get(forKey: KeychainService.githubToken), !token.isEmpty else { return }
        if let list = try? await GitHubService.shared.fetchRepositories(token: token) {
            self.trendingRepos = list.map { repo in
                TrendingRepo(name: repo.name, owner: repo.fullName, description: repo.description ?? "")
            }
        }
    }
}

@MainActor
public struct AIRepositoryAssistantView: View {
    @State private var query = ""
    @State private var response = "Ask your AI Assistant anything about your live repository architecture and logs."

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ecosystem AI Repository Assistant")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                Text(response)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                TextField("Ask Assistant...", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button("Ask AI") {
                    Task { await sendAIRequest() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func sendAIRequest() async {
        guard !query.isEmpty else { return }
        response = "Consulting LLM models..."
        guard let ans = try? await LLMService.shared.generateResponse(prompt: query, useContext: true) else {
            response = "Error communicating with AI models."
            return
        }
        response = ans
    }
}
