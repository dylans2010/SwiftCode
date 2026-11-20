import AppKit
import YcodeBuild
import YcodeIDECore
import YcodeIDEShell
import YcodeProject

public struct CuratedSwiftPackage: Identifiable, Hashable, Sendable {
    public var id: String { url }
    public let name: String
    public let owner: String
    public let url: String
    public let summary: String
    public let category: Category
    public let defaultVersion: String
    public let license: String
    public let symbol: String

    public enum Category: String, CaseIterable, Sendable {
        case apple = "Swift & Apple"
        case networking = "Networking"
        case architecture = "Data & State"
        case ui = "UI & Media"
        case parsing = "Parsing & CLI"
        case testing = "Testing & Logs"

        public var symbol: String {
            switch self {
            case .apple: "swift"
            case .networking: "network"
            case .architecture: "square.stack.3d.up"
            case .ui: "paintbrush"
            case .parsing: "terminal"
            case .testing: "checkmark.seal"
            }
        }
    }

    public static let catalog: [CuratedSwiftPackage] = [
        .init(name: "swift-collections", owner: "apple", url: "https://github.com/apple/swift-collections.git",
              summary: "Deque, OrderedSet, OrderedDictionary, Heap and BitSet data structures.", category: .apple, defaultVersion: "1.1.0", license: "Apache-2.0", symbol: "tray.full"),
        .init(name: "swift-algorithms", owner: "apple", url: "https://github.com/apple/swift-algorithms.git",
              summary: "Sequence and collection algorithms: chunked, windows, permutations and product.", category: .apple, defaultVersion: "1.2.0", license: "Apache-2.0", symbol: "function"),
        .init(name: "swift-async-algorithms", owner: "apple", url: "https://github.com/apple/swift-async-algorithms.git",
              summary: "AsyncSequence combinators including merge, zip, throttle, debounce and channel.", category: .apple, defaultVersion: "1.0.0", license: "Apache-2.0", symbol: "bolt.horizontal"),
        .init(name: "swift-argument-parser", owner: "apple", url: "https://github.com/apple/swift-argument-parser.git",
              summary: "Type-safe command-line flag, option and subcommand parsing.", category: .parsing, defaultVersion: "1.5.0", license: "Apache-2.0", symbol: "terminal"),
        .init(name: "swift-crypto", owner: "apple", url: "https://github.com/apple/swift-crypto.git",
              summary: "Cross-platform CryptoKit APIs for hashing, symmetric ciphers and signatures.", category: .apple, defaultVersion: "3.8.0", license: "Apache-2.0", symbol: "lock.shield"),
        .init(name: "swift-Numerics", owner: "apple", url: "https://github.com/apple/swift-numerics.git",
              summary: "Elementary functions, Real protocol and Complex number types for Swift.", category: .apple, defaultVersion: "1.0.2", license: "Apache-2.0", symbol: "sum"),
        .init(name: "swift-syntax", owner: "swiftlang", url: "https://github.com/swiftlang/swift-syntax.git",
              summary: "Swift source parser, syntax tree inspection, rewriting and macro authoring.", category: .parsing, defaultVersion: "600.0.1", license: "Apache-2.0", symbol: "curlybraces"),
        .init(name: "swift-markdown", owner: "swiftlang", url: "https://github.com/swiftlang/swift-markdown.git",
              summary: "Parse, inspect and transform CommonMark and GitHub-flavored Markdown.", category: .parsing, defaultVersion: "0.5.0", license: "Apache-2.0", symbol: "doc.richtext"),
        .init(name: "swift-log", owner: "apple", url: "https://github.com/apple/swift-log.git",
              summary: "Structured logging API package across Apple platforms and Linux.", category: .testing, defaultVersion: "1.6.0", license: "Apache-2.0", symbol: "list.bullet.rectangle"),
        .init(name: "swift-metrics", owner: "apple", url: "https://github.com/apple/swift-metrics.git",
              summary: "Counters, timers, gauges and recorders for instrumenting Swift services.", category: .testing, defaultVersion: "2.5.0", license: "Apache-2.0", symbol: "chart.xyaxis.line"),
        .init(name: "swift-nio", owner: "apple", url: "https://github.com/apple/swift-nio.git",
              summary: "Event-driven non-blocking network application framework for high-throughput servers.", category: .networking, defaultVersion: "2.75.0", license: "Apache-2.0", symbol: "server.rack"),
        .init(name: "Alamofire", owner: "Alamofire", url: "https://github.com/Alamofire/Alamofire.git",
              summary: "HTTP networking with request chaining, retry policies, Codable decoding and TLS pinning.", category: .networking, defaultVersion: "5.10.0", license: "MIT", symbol: "network"),
        .init(name: "async-http-client", owner: "swift-server", url: "https://github.com/swift-server/async-http-client.git",
              summary: "Async/await HTTP/1 and HTTP/2 client built on SwiftNIO.", category: .networking, defaultVersion: "1.23.0", license: "Apache-2.0", symbol: "arrow.left.arrow.right"),
        .init(name: "grpc-swift", owner: "grpc", url: "https://github.com/grpc/grpc-swift.git",
              summary: "Swift gRPC client and server runtime with structured concurrency.", category: .networking, defaultVersion: "1.24.0", license: "Apache-2.0", symbol: "point.3.connected.trianglepath.dotted"),
        .init(name: "GRDB.swift", owner: "groue", url: "https://github.com/groue/GRDB.swift.git",
              summary: "SQLite toolkit with migrations, Codable records, value observation and FTS5.", category: .architecture, defaultVersion: "6.29.3", license: "MIT", symbol: "cylinder.split.1x2"),
        .init(name: "ComposableArchitecture", owner: "pointfreeco", url: "https://github.com/pointfreeco/swift-composable-architecture.git",
              summary: "Unidirectional state management, composition, side effects and deterministic testing.", category: .architecture, defaultVersion: "1.15.0", license: "MIT", symbol: "square.stack.3d.up"),
        .init(name: "swift-dependencies", owner: "pointfreeco", url: "https://github.com/pointfreeco/swift-dependencies.git",
              summary: "Ergonomic dependency injection modeled after SwiftUI environment values.", category: .architecture, defaultVersion: "1.4.0", license: "MIT", symbol: "link"),
        .init(name: "Nuke", owner: "kean", url: "https://github.com/kean/Nuke.git",
              summary: "Fast asynchronous image loading, progressive decoding and memory/disk caching.", category: .ui, defaultVersion: "12.8.0", license: "MIT", symbol: "photo.stack"),
        .init(name: "Kingfisher", owner: "onevcat", url: "https://github.com/onevcat/Kingfisher.git",
              summary: "Image downloading, caching and SwiftUI view integration.", category: .ui, defaultVersion: "8.1.0", license: "MIT", symbol: "photo"),
        .init(name: "lottie-ios", owner: "airbnb", url: "https://github.com/airbnb/lottie-ios.git",
              summary: "Vector animation rendering engine for iOS, macOS, tvOS and visionOS.", category: .ui, defaultVersion: "4.5.0", license: "Apache-2.0", symbol: "sparkles.rectangle.stack"),
        .init(name: "Yams", owner: "jpsim", url: "https://github.com/jpsim/Yams.git",
              summary: "YAML 1.2 parser and emitter with Codable support.", category: .parsing, defaultVersion: "5.1.3", license: "MIT", symbol: "doc.text"),
        .init(name: "ZIPFoundation", owner: "weichsel", url: "https://github.com/weichsel/ZIPFoundation.git",
              summary: "Effortless ZIP archive reading, creation and streaming in pure Swift.", category: .parsing, defaultVersion: "0.9.19", license: "MIT", symbol: "doc.zipper"),
        .init(name: "swift-snapshot-testing", owner: "pointfreeco", url: "https://github.com/pointfreeco/swift-snapshot-testing.git",
              summary: "Delightful view, image, JSON and text snapshot assertions for Swift tests.", category: .testing, defaultVersion: "1.17.0", license: "MIT", symbol: "camera.viewfinder"),
        .init(name: "swift-custom-dump", owner: "pointfreeco", url: "https://github.com/pointfreeco/swift-custom-dump.git",
              summary: "Structured value printing and readable diffing for debugging and test failures.", category: .testing, defaultVersion: "1.3.3", license: "MIT", symbol: "text.magnifyingglass"),
    ]
}

@MainActor
public final class AddPackageController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSTextFieldDelegate {
    public enum Rule: Int, CaseIterable {
        case upToNextMajor, upToNextMinor, range, exact, branch, revision
        public var title: String {
            switch self {
            case .upToNextMajor: "Up to Next Major Version"
            case .upToNextMinor: "Up to Next Minor Version"
            case .range: "Range of Versions"
            case .exact: "Exact Version"
            case .branch: "Branch"
            case .revision: "Commit"
            }
        }
    }

    private enum SidebarItem: Equatable {
        case featured
        case category(CuratedSwiftPackage.Category)
        case githubSearch
        case favorites
        case recent

        var title: String {
            switch self {
            case .featured: "Featured"
            case .category(let c): c.rawValue
            case .githubSearch: "GitHub Search"
            case .favorites: "Favorites"
            case .recent: "Recently Used"
            }
        }

        var symbol: String {
            switch self {
            case .featured: "star.square"
            case .category(let c): c.symbol
            case .githubSearch: "magnifyingglass"
            case .favorites: "heart"
            case .recent: "clock.arrow.circlepath"
            }
        }

        static var all: [SidebarItem] {
            [.featured] + CuratedSwiftPackage.Category.allCases.map(SidebarItem.category) + [.githubSearch, .favorites, .recent]
        }
    }

    private struct ListedPackage: Equatable {
        var name: String
        var owner: String
        var url: String
        var summary: String
        var version: String
        var license: String
        var badge: String
        var symbol: String
    }

    public let locationField = NSSearchField()
    public let rulePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    public let valueField = NSTextField(string: "1.0.0")
    public let upperField = NSTextField(string: "2.0.0")
    public let targetPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    public let errorLabel = NSTextField(wrappingLabelWithString: "")
    public let addButton = NSButton(title: "Add Package", target: nil, action: nil)
    public private(set) var productChecks: [NSButton] = []
    private var productTargetPopUps: [NSPopUpButton] = []

    public var projectDirectory: URL?
    public var onFetch: ((String, SwiftPackageRequirement) async -> Result<[String], Error>)?
    public var onLink: (([String], String) -> Void)?
    public var onLinkProductTargets: (([(product: String, target: String)]) -> Void)?
    public private(set) var fetchedProducts: [String]?
    public private(set) var adding: Task<Void, Never>?

    private let targets: [String]
    private let discovery = PackageDiscoveryStore()
    private let sidebarTable = NSTableView()
    private let listTable = NSTableView()
    private let listHeaderLabel = NSTextField(labelWithString: "Featured Packages")
    private let listCountLabel = NSTextField(labelWithString: "")
    private let listEmptyLabel = NSTextField(wrappingLabelWithString: "")
    private let detailIcon = NSImageView()
    private let detailTitle = NSTextField(labelWithString: "Select or Enter a Package")
    private let detailSubtitle = NSTextField(labelWithString: "Paste a Git repository URL, owner/repo shorthand, or choose a package on the left.")
    private let detailSummary = NSTextField(wrappingLabelWithString: "")
    private let detailPills = NSStackView()
    private let favoriteButton = NSButton()
    private let openRepoButton = NSButton()
    private let addLocalButton = NSButton(title: "Add Local…", target: nil, action: nil)
    private let searchGitHubButton = NSButton(title: "Search GitHub", target: nil, action: nil)
    private let upperLabel = NSTextField(labelWithString: "to")
    private let ruleSection = NSStackView()
    private let localHintLabel = NSTextField(wrappingLabelWithString: "Local package — linked directly by relative path and rebuilt automatically when its sources change.")
    private let tagsPopUp = NSPopUpButton(frame: .zero, pullsDown: true)
    private let loadTagsButton = NSButton(title: "Load Versions", target: nil, action: nil)
    private let manifestField = NSTextField(labelWithString: "")
    private let copyManifestButton = NSButton(title: "Copy", target: nil, action: nil)
    private let configPane = NSStackView()
    private let productsPane = NSView()
    private let productStack = NSStackView()
    private let backButton = NSButton(title: "Back", target: nil, action: nil)
    private let spinner = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "")

    private var selectedSidebar: SidebarItem = .featured
    private var displayedPackages: [ListedPackage] = []
    private var selectedPackage: ListedPackage?
    private var searchTask: Task<Void, Never>?
    private var tagsTask: Task<Void, Never>?

    private static let recentDefaultsKey = "SwiftCodeRecentPackageURLs"

    public init(targets: [String], projectDirectory: URL? = nil) {
        self.targets = targets
        self.projectDirectory = projectDirectory
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public override func loadView() {
        let root = PanelBackgroundView(frame: NSRect(x: 0, y: 0, width: 880, height: 540))

        let headerIcon = NSImageView(image: NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil) ?? NSImage())
        headerIcon.symbolConfiguration = .init(pointSize: 16, weight: .semibold)
        headerIcon.contentTintColor = .controlAccentColor
        let headerTitle = NSTextField(labelWithString: "Add Package Dependency")
        headerTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        let headerStack = NSStackView(views: [headerIcon, headerTitle])
        headerStack.spacing = 7

        locationField.placeholderString = "Enter package URL, owner/repo, local path, or search packages…"
        locationField.delegate = self
        locationField.sendsSearchStringImmediately = true
        locationField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        searchGitHubButton.bezelStyle = .rounded
        searchGitHubButton.controlSize = .regular
        searchGitHubButton.target = self
        searchGitHubButton.action = #selector(searchGitHubClicked)
        searchGitHubButton.toolTip = "Search public Swift packages on GitHub"

        addLocalButton.bezelStyle = .rounded
        addLocalButton.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
        addLocalButton.imagePosition = .imageLeading
        addLocalButton.target = self
        addLocalButton.action = #selector(addLocalClicked)
        addLocalButton.toolTip = "Choose a local folder containing Package.swift"

        let topRow = NSStackView(views: [headerStack, NSView(), addLocalButton])
        topRow.alignment = .centerY
        let searchRow = NSStackView(views: [locationField, searchGitHubButton])
        searchRow.spacing = 8
        searchRow.alignment = .centerY

        let topBar = NSStackView(views: [topRow, searchRow])
        topBar.orientation = .vertical
        topBar.alignment = .leading
        topBar.spacing = 10
        topBar.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 12, right: 16)
        topRow.widthAnchor.constraint(equalTo: topBar.widthAnchor, constant: -32).isActive = true
        searchRow.widthAnchor.constraint(equalTo: topBar.widthAnchor, constant: -32).isActive = true

        let topDivider = NSBox()
        topDivider.boxType = .separator

        let sidebarCol = NSTableColumn(identifier: .init("sidebar"))
        sidebarTable.addTableColumn(sidebarCol)
        sidebarTable.headerView = nil
        sidebarTable.style = .sourceList
        sidebarTable.rowHeight = 26
        sidebarTable.dataSource = self
        sidebarTable.delegate = self
        let sidebarScroll = NSScrollView()
        sidebarScroll.documentView = sidebarTable
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.autohidesScrollers = true
        sidebarScroll.drawsBackground = false
        sidebarScroll.widthAnchor.constraint(equalToConstant: 176).isActive = true

        listHeaderLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        listHeaderLabel.textColor = .secondaryLabelColor
        listCountLabel.font = .systemFont(ofSize: 11)
        listCountLabel.textColor = .tertiaryLabelColor
        let listHeader = NSStackView(views: [listHeaderLabel, NSView(), listCountLabel])
        listHeader.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 6, right: 12)

        let pkgCol = NSTableColumn(identifier: .init("package"))
        listTable.addTableColumn(pkgCol)
        listTable.headerView = nil
        listTable.style = .inset
        listTable.rowHeight = 54
        listTable.intercellSpacing = NSSize(width: 0, height: 2)
        listTable.dataSource = self
        listTable.delegate = self
        listTable.doubleAction = #selector(packageDoubleClicked)
        listTable.target = self
        let listScroll = NSScrollView()
        listScroll.documentView = listTable
        listScroll.hasVerticalScroller = true
        listScroll.autohidesScrollers = true
        listScroll.drawsBackground = false

        listEmptyLabel.font = .systemFont(ofSize: 12)
        listEmptyLabel.textColor = .secondaryLabelColor
        listEmptyLabel.alignment = .center
        listEmptyLabel.isHidden = true

        let centerContainer = NSView()
        centerContainer.widthAnchor.constraint(equalToConstant: 310).isActive = true
        for v in [listHeader, listScroll, listEmptyLabel] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            centerContainer.addSubview(v)
        }
        NSLayoutConstraint.activate([
            listHeader.topAnchor.constraint(equalTo: centerContainer.topAnchor),
            listHeader.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
            listHeader.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor),
            listScroll.topAnchor.constraint(equalTo: listHeader.bottomAnchor),
            listScroll.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
            listScroll.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor),
            listScroll.bottomAnchor.constraint(equalTo: centerContainer.bottomAnchor),
            listEmptyLabel.centerXAnchor.constraint(equalTo: centerContainer.centerXAnchor),
            listEmptyLabel.centerYAnchor.constraint(equalTo: centerContainer.centerYAnchor),
            listEmptyLabel.widthAnchor.constraint(equalToConstant: 250),
        ])

        let rightContainer = buildRightPane()

        let vSep1 = NSBox(); vSep1.boxType = .separator
        let vSep2 = NSBox(); vSep2.boxType = .separator

        let bodyRow = NSStackView(views: [sidebarScroll, vSep1, centerContainer, vSep2, rightContainer])
        bodyRow.spacing = 0
        bodyRow.alignment = .top
        for v in [sidebarScroll, vSep1, centerContainer, vSep2, rightContainer] as [NSView] {
            v.heightAnchor.constraint(equalTo: bodyRow.heightAnchor).isActive = true
        }

        let bottomDivider = NSBox()
        bottomDivider.boxType = .separator

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle

        errorLabel.font = .systemFont(ofSize: 11, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.maximumNumberOfLines = 2
        errorLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        backButton.bezelStyle = .rounded
        backButton.target = self
        backButton.action = #selector(backClicked)
        backButton.isHidden = true

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"

        addButton.bezelStyle = .rounded
        addButton.hasDestructiveAction = false
        addButton.keyEquivalent = "\r"
        addButton.target = self
        addButton.action = #selector(addClicked)

        let footer = NSStackView(views: [spinner, statusLabel, errorLabel, NSView(), backButton, cancel, addButton])
        footer.spacing = 8
        footer.alignment = .centerY
        footer.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 12, right: 16)

        for v in [topBar, topDivider, bodyRow, bottomDivider, footer] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(v)
        }
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: root.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            topDivider.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            topDivider.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            topDivider.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bodyRow.topAnchor.constraint(equalTo: topDivider.bottomAnchor),
            bodyRow.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bodyRow.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bodyRow.bottomAnchor.constraint(equalTo: bottomDivider.topAnchor),
            bottomDivider.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bottomDivider.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bottomDivider.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        view = root
        sidebarTable.selectRowIndexes([0], byExtendingSelection: false)
        ruleChanged()
        reloadPackages()
        refreshInspector()
    }

    private func buildRightPane() -> NSView {
        let container = NSView()
        container.setContentHuggingPriority(.defaultLow, for: .horizontal)

        detailIcon.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil)
        detailIcon.symbolConfiguration = .init(pointSize: 22, weight: .medium)
        detailIcon.contentTintColor = .controlAccentColor
        detailIcon.widthAnchor.constraint(equalToConstant: 32).isActive = true
        detailIcon.heightAnchor.constraint(equalToConstant: 32).isActive = true

        detailTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        detailTitle.lineBreakMode = .byTruncatingTail
        detailSubtitle.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detailSubtitle.textColor = .secondaryLabelColor
        detailSubtitle.lineBreakMode = .byTruncatingMiddle
        detailSubtitle.isSelectable = true

        favoriteButton.bezelStyle = .inline
        favoriteButton.isBordered = false
        favoriteButton.image = NSImage(systemSymbolName: "heart", accessibilityDescription: "Favorite")
        favoriteButton.target = self
        favoriteButton.action = #selector(toggleFavoriteClicked)
        favoriteButton.toolTip = "Save to Favorites"

        openRepoButton.bezelStyle = .inline
        openRepoButton.isBordered = false
        openRepoButton.image = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: "Open Repository")
        openRepoButton.target = self
        openRepoButton.action = #selector(openRepositoryClicked)
        openRepoButton.toolTip = "Open repository in browser or Finder"

        let titleCol = NSStackView(views: [detailTitle, detailSubtitle])
        titleCol.orientation = .vertical
        titleCol.alignment = .leading
        titleCol.spacing = 2

        let headRow = NSStackView(views: [detailIcon, titleCol, NSView(), favoriteButton, openRepoButton])
        headRow.alignment = .centerY
        headRow.spacing = 8

        detailSummary.font = .systemFont(ofSize: 12)
        detailSummary.textColor = .secondaryLabelColor
        detailSummary.maximumNumberOfLines = 3

        detailPills.spacing = 6

        for r in Rule.allCases { rulePopUp.addItem(withTitle: r.title) }
        rulePopUp.target = self
        rulePopUp.action = #selector(ruleChanged)
        rulePopUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 210).isActive = true

        valueField.widthAnchor.constraint(equalToConstant: 116).isActive = true
        valueField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        valueField.delegate = self
        upperField.widthAnchor.constraint(equalToConstant: 116).isActive = true
        upperField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        upperField.delegate = self

        loadTagsButton.bezelStyle = .inline
        loadTagsButton.controlSize = .small
        loadTagsButton.target = self
        loadTagsButton.action = #selector(loadTagsClicked)
        loadTagsButton.toolTip = "Fetch published version tags from the remote repository"

        tagsPopUp.controlSize = .small
        tagsPopUp.isHidden = true
        tagsPopUp.target = self
        tagsPopUp.action = #selector(tagChosen)

        let versionRow = NSStackView(views: [valueField, upperLabel, upperField, loadTagsButton, tagsPopUp])
        versionRow.spacing = 6
        versionRow.alignment = .centerY

        ruleSection.orientation = .vertical
        ruleSection.alignment = .leading
        ruleSection.spacing = 8
        ruleSection.addArrangedSubview(sectionHeader("DEPENDENCY RULE"))
        ruleSection.addArrangedSubview(rulePopUp)
        ruleSection.addArrangedSubview(versionRow)

        localHintLabel.font = .systemFont(ofSize: 11)
        localHintLabel.textColor = .secondaryLabelColor
        localHintLabel.isHidden = true

        targetPopUp.addItems(withTitles: targets.isEmpty ? ["App"] : targets)
        targetPopUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        let targetSection = NSStackView(views: [sectionHeader("ADD TO TARGET"), targetPopUp])
        targetSection.orientation = .vertical
        targetSection.alignment = .leading
        targetSection.spacing = 6

        manifestField.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        manifestField.textColor = .secondaryLabelColor
        manifestField.lineBreakMode = .byTruncatingMiddle
        manifestField.isSelectable = true
        manifestField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        copyManifestButton.bezelStyle = .inline
        copyManifestButton.controlSize = .small
        copyManifestButton.target = self
        copyManifestButton.action = #selector(copyManifestClicked)

        let manifestBox = NSView()
        manifestBox.wantsLayer = true
        manifestBox.layer?.cornerRadius = 6
        manifestBox.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.55).cgColor
        manifestBox.layer?.borderWidth = 1
        manifestBox.layer?.borderColor = NSColor.separatorColor.cgColor
        let manifestRow = NSStackView(views: [manifestField, NSView(), copyManifestButton])
        manifestRow.alignment = .centerY
        manifestRow.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        manifestRow.translatesAutoresizingMaskIntoConstraints = false
        manifestBox.addSubview(manifestRow)
        NSLayoutConstraint.activate([
            manifestRow.topAnchor.constraint(equalTo: manifestBox.topAnchor),
            manifestRow.bottomAnchor.constraint(equalTo: manifestBox.bottomAnchor),
            manifestRow.leadingAnchor.constraint(equalTo: manifestBox.leadingAnchor),
            manifestRow.trailingAnchor.constraint(equalTo: manifestBox.trailingAnchor),
        ])

        let manifestSection = NSStackView(views: [sectionHeader("PACKAGE.SWIFT DECLARATION"), manifestBox])
        manifestSection.orientation = .vertical
        manifestSection.alignment = .leading
        manifestSection.spacing = 6

        let sep = NSBox(); sep.boxType = .separator

        configPane.orientation = .vertical
        configPane.alignment = .leading
        configPane.spacing = 14
        configPane.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        for v in [headRow, detailSummary, detailPills, sep, ruleSection, localHintLabel, targetSection, manifestSection] as [NSView] {
            configPane.addArrangedSubview(v)
        }
        for full in [headRow, sep, manifestSection, manifestBox] as [NSView] {
            full.widthAnchor.constraint(equalTo: configPane.widthAnchor, constant: -36).isActive = true
        }

        let prodTitle = NSTextField(labelWithString: "Choose Package Products")
        prodTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        let prodSub = NSTextField(wrappingLabelWithString: "Select the libraries, executables or plugins to link into your project targets.")
        prodSub.font = .systemFont(ofSize: 11)
        prodSub.textColor = .secondaryLabelColor

        let selectAllBtn = NSButton(title: "Select All", target: self, action: #selector(selectAllProducts))
        selectAllBtn.bezelStyle = .inline; selectAllBtn.controlSize = .small
        let selectNoneBtn = NSButton(title: "Deselect All", target: self, action: #selector(deselectAllProducts))
        selectNoneBtn.bezelStyle = .inline; selectNoneBtn.controlSize = .small
        let bulkRow = NSStackView(views: [sectionHeader("PRODUCTS"), NSView(), selectAllBtn, selectNoneBtn])
        bulkRow.alignment = .centerY

        productStack.orientation = .vertical
        productStack.alignment = .leading
        productStack.spacing = 8
        productStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let prodDoc = FlippedView()
        prodDoc.translatesAutoresizingMaskIntoConstraints = false
        productStack.translatesAutoresizingMaskIntoConstraints = false
        prodDoc.addSubview(productStack)
        let prodScroll = NSScrollView()
        prodScroll.documentView = prodDoc
        prodScroll.hasVerticalScroller = true
        prodScroll.autohidesScrollers = true
        prodScroll.drawsBackground = false
        prodScroll.borderType = .bezelBorder
        NSLayoutConstraint.activate([
            productStack.topAnchor.constraint(equalTo: prodDoc.topAnchor),
            productStack.leadingAnchor.constraint(equalTo: prodDoc.leadingAnchor),
            productStack.trailingAnchor.constraint(equalTo: prodDoc.trailingAnchor),
            productStack.bottomAnchor.constraint(equalTo: prodDoc.bottomAnchor),
            prodDoc.widthAnchor.constraint(equalTo: prodScroll.contentView.widthAnchor),
        ])

        productsPane.isHidden = true
        for v in [prodTitle, prodSub, bulkRow, prodScroll] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            productsPane.addSubview(v)
        }
        NSLayoutConstraint.activate([
            prodTitle.topAnchor.constraint(equalTo: productsPane.topAnchor, constant: 16),
            prodTitle.leadingAnchor.constraint(equalTo: productsPane.leadingAnchor, constant: 18),
            prodTitle.trailingAnchor.constraint(equalTo: productsPane.trailingAnchor, constant: -18),
            prodSub.topAnchor.constraint(equalTo: prodTitle.bottomAnchor, constant: 4),
            prodSub.leadingAnchor.constraint(equalTo: prodTitle.leadingAnchor),
            prodSub.trailingAnchor.constraint(equalTo: prodTitle.trailingAnchor),
            bulkRow.topAnchor.constraint(equalTo: prodSub.bottomAnchor, constant: 14),
            bulkRow.leadingAnchor.constraint(equalTo: prodTitle.leadingAnchor),
            bulkRow.trailingAnchor.constraint(equalTo: prodTitle.trailingAnchor),
            prodScroll.topAnchor.constraint(equalTo: bulkRow.bottomAnchor, constant: 6),
            prodScroll.leadingAnchor.constraint(equalTo: prodTitle.leadingAnchor),
            prodScroll.trailingAnchor.constraint(equalTo: prodTitle.trailingAnchor),
            prodScroll.bottomAnchor.constraint(equalTo: productsPane.bottomAnchor, constant: -16),
        ])

        for v in [configPane, productsPane] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: container.topAnchor),
                v.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                v.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            ])
        }
        configPane.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        productsPane.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        productsPane.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        return container
    }

    private func sectionHeader(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 10, weight: .semibold)
        l.textColor = .secondaryLabelColor
        return l
    }

    private func pill(_ text: String) -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 4
        box.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 10, weight: .medium)
        l.textColor = .secondaryLabelColor
        l.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(l)
        NSLayoutConstraint.activate([
            l.topAnchor.constraint(equalTo: box.topAnchor, constant: 2),
            l.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -2),
            l.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 6),
            l.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -6),
        ])
        return box
    }

    public var rule: Rule {
        get { Rule(rawValue: rulePopUp.indexOfSelectedItem) ?? .upToNextMajor }
        set { loadViewIfNeeded(); rulePopUp.selectItem(at: newValue.rawValue); ruleChanged() }
    }

    @objc private func ruleChanged() {
        upperLabel.isHidden = rule != .range
        upperField.isHidden = rule != .range
        switch rule {
        case .branch: if Version.isVersion(valueField.stringValue) { valueField.stringValue = "main" }
        case .revision: if Version.isVersion(valueField.stringValue) { valueField.stringValue = "" }
        default: if !Version.isVersion(valueField.stringValue) { valueField.stringValue = selectedPackage?.version.isEmpty == false ? selectedPackage!.version : "1.0.0" }
        }
        updateManifestPreview()
    }

    private enum Version { static func isVersion(_ s: String) -> Bool { s.first?.isNumber == true } }

    public var requirement: SwiftPackageRequirement {
        let v = valueField.stringValue.trimmingCharacters(in: .whitespaces)
        switch rule {
        case .upToNextMajor: return .upToNextMajor(from: v)
        case .upToNextMinor: return .upToNextMinor(from: v)
        case .range: return .range(from: v, to: upperField.stringValue.trimmingCharacters(in: .whitespaces))
        case .exact: return .exact(v)
        case .branch: return .branch(v)
        case .revision: return .revision(v)
        }
    }

    public func normalizedLocation(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.hasPrefix("https://swiftpackageindex.com/") {
            let repo = String(trimmed.dropFirst("https://swiftpackageindex.com/".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if repo.split(separator: "/").count == 2 { return "https://github.com/\(repo).git" }
        }
        if trimmed.hasPrefix("github.com/") {
            let repo = String(trimmed.dropFirst("github.com/".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return repo.hasSuffix(".git") ? "https://github.com/\(repo)" : "https://github.com/\(repo).git"
        }
        if !trimmed.contains("://"), !trimmed.contains("@"), !trimmed.hasPrefix("/"), !trimmed.hasPrefix("~"), !trimmed.hasPrefix(".") {
            let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false)
            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty {
                let candidateLocal = URL(fileURLWithPath: trimmed, relativeTo: projectDirectory).standardizedFileURL
                if FileManager.default.fileExists(atPath: candidateLocal.path) {
                    return trimmed
                }
                if let projectDirectory {
                    let inProject = projectDirectory.appendingPathComponent(trimmed)
                    if FileManager.default.fileExists(atPath: inProject.path) { return trimmed }
                    let repo = String(parts[1]).hasSuffix(".git") ? trimmed : "\(trimmed).git"
                    return "https://github.com/\(repo)"
                }
            }
        }
        return trimmed
    }

    private func isCurrentlyLocal(_ raw: String) -> Bool {
        let loc = normalizedLocation(raw)
        guard !loc.isEmpty else { return false }
        return PackageDependencyModel.isLocalPath(loc)
    }

    private func updateManifestPreview() {
        let raw = locationField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            manifestField.stringValue = ".package(url: \"https://github.com/owner/package.git\", from: \"1.0.0\")"
            return
        }
        let loc = normalizedLocation(raw)
        if PackageDependencyModel.isLocalPath(loc) {
            manifestField.stringValue = ".package(path: \"\(loc)\")"
            return
        }
        let v = valueField.stringValue.trimmingCharacters(in: .whitespaces)
        let u = upperField.stringValue.trimmingCharacters(in: .whitespaces)
        switch rule {
        case .upToNextMajor: manifestField.stringValue = ".package(url: \"\(loc)\", from: \"\(v)\")"
        case .upToNextMinor: manifestField.stringValue = ".package(url: \"\(loc)\", .upToNextMinor(from: \"\(v)\"))"
        case .range: manifestField.stringValue = ".package(url: \"\(loc)\", \"\(v)\"..<\"\(u)\")"
        case .exact: manifestField.stringValue = ".package(url: \"\(loc)\", exact: \"\(v)\")"
        case .branch: manifestField.stringValue = ".package(url: \"\(loc)\", branch: \"\(v)\")"
        case .revision: manifestField.stringValue = ".package(url: \"\(loc)\", revision: \"\(v)\")"
        }
    }

    private var recentURLs: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.recentDefaultsKey) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.prefix(20)), forKey: Self.recentDefaultsKey) }
    }

    private func recordRecent(_ url: String) {
        guard !url.isEmpty else { return }
        var current = recentURLs.filter { $0 != url }
        current.insert(url, at: 0)
        recentURLs = current
    }

    private func reloadPackages() {
        let query = locationField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let isURLOrPath = query.contains("://") || query.hasPrefix("/") || query.hasPrefix("~") || query.hasPrefix(".")
        let filterText = isURLOrPath ? "" : query.lowercased()

        func mapCurated(_ c: CuratedSwiftPackage) -> ListedPackage {
            ListedPackage(name: c.name, owner: c.owner, url: c.url, summary: c.summary, version: c.defaultVersion,
                          license: c.license, badge: c.category.rawValue, symbol: c.symbol)
        }
        var items: [ListedPackage]
        switch selectedSidebar {
        case .featured:
            listHeaderLabel.stringValue = "Featured Packages"
            items = CuratedSwiftPackage.catalog.map(mapCurated)
        case .category(let cat):
            listHeaderLabel.stringValue = cat.rawValue
            items = CuratedSwiftPackage.catalog.filter { $0.category == cat }.map(mapCurated)
        case .githubSearch:
            listHeaderLabel.stringValue = "GitHub Search"
            items = discovery.searchResults.map { m in
                ListedPackage(name: m.name, owner: m.owner, url: m.cloneUrl, summary: m.description ?? "Swift package on GitHub",
                              version: m.lastReleasedVersion.isEmpty ? "1.0.0" : m.lastReleasedVersion,
                              license: m.license ?? "GitHub", badge: "★ \(m.stars)", symbol: "shippingbox")
            }
        case .favorites:
            listHeaderLabel.stringValue = "Favorites"
            items = discovery.favoritePackages.map { url in
                if let c = CuratedSwiftPackage.catalog.first(where: { $0.url == url }) { return mapCurated(c) }
                let name = PackageResolver.identity(of: url)
                return ListedPackage(name: name, owner: PackageDiscoveryStore.repositoryPath(from: url)?.components(separatedBy: "/").first ?? "git",
                                     url: url, summary: url, version: "1.0.0", license: "Git", badge: "Saved", symbol: "heart.fill")
            }
        case .recent:
            listHeaderLabel.stringValue = "Recently Used"
            items = recentURLs.map { url in
                if let c = CuratedSwiftPackage.catalog.first(where: { $0.url == url }) { return mapCurated(c) }
                let local = PackageDependencyModel.isLocalPath(url)
                let name = (url as NSString).lastPathComponent.replacingOccurrences(of: ".git", with: "")
                return ListedPackage(name: name.isEmpty ? url : name, owner: local ? "Local" : "Git", url: url, summary: url,
                                     version: "1.0.0", license: local ? "Local" : "Git", badge: local ? "Local" : "Recent",
                                     symbol: local ? "folder" : "clock")
            }
        }
        if !filterText.isEmpty && selectedSidebar != .githubSearch {
            items = items.filter {
                $0.name.lowercased().contains(filterText) || $0.owner.lowercased().contains(filterText) || $0.summary.lowercased().contains(filterText)
            }
        }
        displayedPackages = items
        listCountLabel.stringValue = "\(items.count)"
        listTable.reloadData()
        if items.isEmpty {
            listEmptyLabel.isHidden = false
            switch selectedSidebar {
            case .githubSearch:
                listEmptyLabel.stringValue = discovery.isSearching ? "Searching GitHub…"
                    : (discovery.searchError ?? "Enter a search query above and click Search GitHub.")
            case .favorites:
                listEmptyLabel.stringValue = "Click the heart button on any package to save it here."
            case .recent:
                listEmptyLabel.stringValue = "Packages you add to projects will appear here."
            default:
                listEmptyLabel.stringValue = "No matching packages in this section. Click Search GitHub to search online."
            }
        } else {
            listEmptyLabel.isHidden = true
        }
    }

    private func refreshInspector() {
        let raw = locationField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedLocation(raw)
        let local = isCurrentlyLocal(raw)
        ruleSection.isHidden = local
        localHintLabel.isHidden = !local
        detailPills.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let pkg = selectedPackage, pkg.url == raw || pkg.url == normalized {
            detailIcon.image = NSImage(systemSymbolName: pkg.symbol, accessibilityDescription: nil)
            detailTitle.stringValue = pkg.name
            detailSubtitle.stringValue = pkg.url
            detailSummary.stringValue = pkg.summary
            for label in [pkg.owner, pkg.license, pkg.badge] where !label.isEmpty {
                detailPills.addArrangedSubview(pill(label))
            }
        } else if !raw.isEmpty {
            detailIcon.image = NSImage(systemSymbolName: local ? "folder.fill" : "link", accessibilityDescription: nil)
            let last = (normalized as NSString).lastPathComponent.replacingOccurrences(of: ".git", with: "")
            detailTitle.stringValue = last.isEmpty ? normalized : last
            detailSubtitle.stringValue = normalized
            detailSummary.stringValue = local ? "Local Swift package directory." : "Remote Git package repository."
            detailPills.addArrangedSubview(pill(local ? "Local Package" : "Git Repository"))
        } else {
            detailIcon.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil)
            detailTitle.stringValue = "Select or Enter a Package"
            detailSubtitle.stringValue = "Paste a Git URL, owner/repo shorthand, or pick from the catalog."
            detailSummary.stringValue = "SwiftCode resolves versions with Git, writes Package.resolved, and links selected products to your target."
        }
        let favURL = normalized.isEmpty ? (selectedPackage?.url ?? "") : normalized
        let isFav = !favURL.isEmpty && discovery.favoritePackages.contains(favURL)
        favoriteButton.image = NSImage(systemSymbolName: isFav ? "heart.fill" : "heart", accessibilityDescription: "Favorite")
        favoriteButton.contentTintColor = isFav ? .systemPink : .secondaryLabelColor
        favoriteButton.isEnabled = !favURL.isEmpty
        openRepoButton.isEnabled = !favURL.isEmpty
        loadTagsButton.isEnabled = !normalized.isEmpty && !local
        updateManifestPreview()
    }


    public func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === sidebarTable ? SidebarItem.all.count : displayedPackages.count
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === sidebarTable {
            let item = SidebarItem.all[row]
            let cell = NSTableCellView()
            let iv = NSImageView(image: NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil) ?? NSImage())
            iv.symbolConfiguration = .init(pointSize: 12, weight: .medium)
            iv.contentTintColor = .secondaryLabelColor
            iv.widthAnchor.constraint(equalToConstant: 16).isActive = true
            let tf = NSTextField(labelWithString: item.title)
            tf.font = .systemFont(ofSize: 12)
            tf.lineBreakMode = .byTruncatingTail
            let stack = NSStackView(views: [iv, tf])
            stack.spacing = 7
            stack.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }
        guard row < displayedPackages.count else { return nil }
        let pkg = displayedPackages[row]
        let cell = NSTableCellView()
        let icon = NSImageView(image: NSImage(systemSymbolName: pkg.symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 14, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let title = NSTextField(labelWithString: pkg.name)
        title.font = .systemFont(ofSize: 12.5, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        let owner = NSTextField(labelWithString: pkg.owner)
        owner.font = .systemFont(ofSize: 10.5)
        owner.textColor = .tertiaryLabelColor
        let badge = NSTextField(labelWithString: pkg.badge)
        badge.font = .systemFont(ofSize: 10, weight: .medium)
        badge.textColor = .secondaryLabelColor
        let topLine = NSStackView(views: [title, owner, NSView(), badge])
        topLine.spacing = 6
        topLine.alignment = .firstBaseline

        let summary = NSTextField(labelWithString: pkg.summary)
        summary.font = .systemFont(ofSize: 11)
        summary.textColor = .secondaryLabelColor
        summary.lineBreakMode = .byTruncatingTail

        let textCol = NSStackView(views: [topLine, summary])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 2
        topLine.widthAnchor.constraint(equalTo: textCol.widthAnchor).isActive = true
        summary.widthAnchor.constraint(equalTo: textCol.widthAnchor).isActive = true

        let rowStack = NSStackView(views: [icon, textCol])
        rowStack.spacing = 9
        rowStack.alignment = .centerY
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            rowStack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            rowStack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTableView else { return }
        if tv === sidebarTable {
            let r = sidebarTable.selectedRow
            guard r >= 0, r < SidebarItem.all.count else { return }
            selectedSidebar = SidebarItem.all[r]
            reloadPackages()
            return
        }
        let r = listTable.selectedRow
        guard r >= 0, r < displayedPackages.count, fetchedProducts == nil else { return }
        let pkg = displayedPackages[r]
        selectedPackage = pkg
        locationField.stringValue = pkg.url
        tagsPopUp.isHidden = true
        if rule == .upToNextMajor || rule == .upToNextMinor || rule == .exact || rule == .range {
            if !pkg.version.isEmpty { valueField.stringValue = pkg.version }
        }
        errorLabel.stringValue = ""
        refreshInspector()
    }


    public func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === locationField {
            errorLabel.stringValue = ""
            tagsPopUp.isHidden = true
            if let match = CuratedSwiftPackage.catalog.first(where: { $0.url == locationField.stringValue.trimmingCharacters(in: .whitespaces) }) {
                selectedPackage = ListedPackage(name: match.name, owner: match.owner, url: match.url, summary: match.summary,
                                                version: match.defaultVersion, license: match.license, badge: match.category.rawValue, symbol: match.symbol)
            }
            reloadPackages()
            refreshInspector()
        } else {
            updateManifestPreview()
        }
    }

    @objc private func searchGitHubClicked() {
        let q = locationField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = SidebarItem.all.firstIndex(of: .githubSearch) {
            sidebarTable.selectRowIndexes([idx], byExtendingSelection: false)
        }
        selectedSidebar = .githubSearch
        guard !q.isEmpty else { reloadPackages(); return }
        searchTask?.cancel()
        reloadPackages()
        searchTask = Task { [weak self] in
            guard let self else { return }
            await self.discovery.executeGitHubSearch(query: q)
            self.reloadPackages()
        }
    }

    @objc private func addLocalClicked() {
        let panel = NSOpenPanel()
        panel.title = "Choose Local Swift Package"
        panel.message = "Select a folder containing a Package.swift manifest."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = projectDirectory
        let apply: (URL) -> Void = { [weak self] url in
            guard let self else { return }
            self.resetFetchedStep()
            self.selectedPackage = ListedPackage(name: url.lastPathComponent, owner: "Local", url: url.path,
                                                 summary: "Local Swift package at \(url.path)", version: "", license: "Local",
                                                 badge: "Local", symbol: "folder.fill")
            self.locationField.stringValue = url.path
            self.refreshInspector()
        }
        if let w = view.window, w.isVisible {
            panel.beginSheetModal(for: w) { r in
                if r == .OK, let u = panel.url { apply(u) }
            }
        } else if panel.runModal() == .OK, let u = panel.url {
            apply(u)
        }
    }

    @objc private func loadTagsClicked() {
        let loc = normalizedLocation(locationField.stringValue)
        guard !loc.isEmpty, !PackageDependencyModel.isLocalPath(loc) else { return }
        tagsTask?.cancel()
        loadTagsButton.isEnabled = false
        statusLabel.stringValue = "Fetching remote tags…"
        spinner.startAnimation(nil)
        tagsTask = Task { [weak self] in
            let result = await Task.detached { Result { try PackageResolver.availableVersions(url: loc) } }.value
            guard let self else { return }
            self.spinner.stopAnimation(nil)
            self.loadTagsButton.isEnabled = true
            switch result {
            case .success(let list):
                let sorted = list.sorted { $0.0 > $1.0 }
                self.tagsPopUp.removeAllItems()
                self.tagsPopUp.addItem(withTitle: sorted.isEmpty ? "No semver tags" : "Versions (\(sorted.count))")
                for (ver, _) in sorted.prefix(40) {
                    self.tagsPopUp.addItem(withTitle: ver.description)
                }
                self.tagsPopUp.isHidden = false
                if let latest = sorted.first?.0.description {
                    self.valueField.stringValue = latest
                    self.statusLabel.stringValue = "Latest tag: \(latest)"
                    self.updateManifestPreview()
                } else {
                    self.statusLabel.stringValue = "No semantic version tags found"
                }
            case .failure(let err):
                self.statusLabel.stringValue = ""
                self.errorLabel.stringValue = "\(err)"
            }
        }
    }

    @objc private func tagChosen() {
        guard tagsPopUp.indexOfSelectedItem > 0, let title = tagsPopUp.titleOfSelectedItem else { return }
        valueField.stringValue = title
        updateManifestPreview()
    }

    @objc private func toggleFavoriteClicked() {
        let url = normalizedLocation(locationField.stringValue)
        let target = url.isEmpty ? (selectedPackage?.url ?? "") : url
        guard !target.isEmpty else { return }
        discovery.toggleFavorite(url: target)
        reloadPackages()
        refreshInspector()
    }

    @objc private func openRepositoryClicked() {
        let loc = normalizedLocation(locationField.stringValue)
        let target = loc.isEmpty ? (selectedPackage?.url ?? "") : loc
        guard !target.isEmpty else { return }
        if PackageDependencyModel.isLocalPath(target) {
            let u = URL(fileURLWithPath: (target as NSString).expandingTildeInPath, relativeTo: projectDirectory).standardizedFileURL
            NSWorkspace.shared.activateFileViewerSelecting([u])
            return
        }
        let web = target.hasSuffix(".git") ? String(target.dropLast(4)) : target
        if let u = URL(string: web) { NSWorkspace.shared.open(u) }
    }

    @objc private func copyManifestClicked() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(manifestField.stringValue, forType: .string)
        statusLabel.stringValue = "Copied Package.swift entry"
    }

    @objc private func packageDoubleClicked() {
        guard listTable.clickedRow >= 0, fetchedProducts == nil else { return }
        addClicked()
    }

    @objc private func selectAllProducts() { productChecks.forEach { $0.state = .on } }
    @objc private func deselectAllProducts() { productChecks.forEach { $0.state = .off } }

    @objc private func backClicked() { resetFetchedStep() }

    private func resetFetchedStep() {
        fetchedProducts = nil
        productChecks = []
        productTargetPopUps = []
        productStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        productsPane.isHidden = true
        configPane.isHidden = false
        backButton.isHidden = true
        locationField.isEnabled = true
        rulePopUp.isEnabled = true
        addLocalButton.isEnabled = true
        addButton.title = "Add Package"
        statusLabel.stringValue = ""
    }

    @objc public func addClicked() {
        guard adding == nil else { return }
        adding = Task { [weak self] in
            await self?.add()
            self?.adding = nil
        }
    }

    public func add() async {
        loadViewIfNeeded()
        if fetchedProducts == nil {
            let location = normalizedLocation(locationField.stringValue)
            guard !location.isEmpty else {
                errorLabel.stringValue = "Enter a package repository URL or choose a package first."
                return
            }
            locationField.stringValue = location
            addButton.isEnabled = false
            spinner.startAnimation(nil)
            statusLabel.stringValue = "Resolving package…"
            defer {
                addButton.isEnabled = true
                spinner.stopAnimation(nil)
            }
            switch await onFetch?(location, requirement) ?? .success([]) {
            case .success(let products):
                fetchedProducts = products
                recordRecent(location)
                errorLabel.stringValue = ""
                statusLabel.stringValue = products.isEmpty ? "No library products declared" : "\(products.count) product\(products.count == 1 ? "" : "s") found"
                buildProductRows(products)
                configPane.isHidden = true
                productsPane.isHidden = false
                backButton.isHidden = false
                locationField.isEnabled = false
                rulePopUp.isEnabled = false
                addLocalButton.isEnabled = false
                addButton.title = "Add Package"
            case .failure(let e):
                statusLabel.stringValue = ""
                errorLabel.stringValue = "\(e)"
            }
            return
        }
        let defaultTarget = targetPopUp.titleOfSelectedItem ?? targets.first ?? ""
        var pairs: [(product: String, target: String)] = []
        for (idx, check) in productChecks.enumerated() where check.state == .on {
            let chosenTarget = idx < productTargetPopUps.count ? (productTargetPopUps[idx].titleOfSelectedItem ?? defaultTarget) : defaultTarget
            if chosenTarget != "None" {
                pairs.append((check.title, chosenTarget))
            }
        }
        if let onLinkProductTargets {
            onLinkProductTargets(pairs)
        } else {
            let chosen = pairs.map(\.product)
            onLink?(chosen, defaultTarget)
        }
        if presentingViewController != nil { dismiss(nil) }
    }

    private func buildProductRows(_ products: [String]) {
        productStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        productChecks = []
        productTargetPopUps = []
        let defaultTarget = targetPopUp.titleOfSelectedItem ?? targets.first ?? "App"
        let targetOptions = (targets.isEmpty ? [defaultTarget] : targets) + ["None"]
        for product in products {
            let check = NSButton(checkboxWithTitle: product, target: nil, action: nil)
            check.state = .on
            check.font = .systemFont(ofSize: 12, weight: .medium)
            let icon = NSImageView(image: NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil) ?? NSImage())
            icon.symbolConfiguration = .init(pointSize: 12, weight: .regular)
            icon.contentTintColor = .secondaryLabelColor
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            popup.controlSize = .small
            popup.addItems(withTitles: targetOptions)
            popup.selectItem(withTitle: defaultTarget)
            popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true

            let row = NSStackView(views: [check, icon, NSView(), NSTextField(labelWithString: "Target:"), popup])
            row.spacing = 8
            row.alignment = .centerY
            productStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: productStack.widthAnchor, constant: -16).isActive = true
            productChecks.append(check)
            productTargetPopUps.append(popup)
        }
    }

    @objc private func cancelClicked() { if presentingViewController != nil { dismiss(nil) } }
}
