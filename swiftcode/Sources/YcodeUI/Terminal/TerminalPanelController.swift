import AppKit

@MainActor
public final class TerminalSessionController {
    public let id = UUID()
    public let emulator: TerminalEmulator
    public let view: TerminalScreenView
    public let process = PseudoTerminalProcess()
    public private(set) var shell: String
    public private(set) var directory: String
    public private(set) var exitCode: Int32?
    public var customTitle: String?
    public var onChange: (() -> Void)?
    public var onBell: (() -> Void)?
    private let initialCommand: String?

    public init(settings: TerminalSettings, shell: String? = nil, directory: String, command: String? = nil) {
        self.shell = shell ?? settings.resolvedShell
        self.directory = directory
        initialCommand = command
        emulator = TerminalEmulator(columns: 80, rows: 24)
        emulator.scrollbackLimit = settings.scrollbackLines
        view = TerminalScreenView(emulator: emulator, settings: settings)
        emulator.onResponse = { [weak self] reply in self?.process.write(reply) }
        emulator.onTitle = { [weak self] _ in self?.onChange?() }
        emulator.onWorkingDirectory = { [weak self] _ in self?.onChange?() }
        emulator.onBell = { [weak self] in self?.onBell?() }
        view.onInput = { [weak self] data in self?.input(data) }
        view.onResize = { [weak self] columns, rows in self?.process.resize(columns: columns, rows: rows) }
        view.currentDirectory = { [weak self] in self?.workingDirectory }
        process.onOutput = { [weak self] data in
            guard let self else { return }
            self.emulator.feed(data)
            self.view.contentDidChange()
        }
        process.onExit = { [weak self] code in self?.exited(code) }
    }

    public var isRunning: Bool { process.isRunning }

    public var workingDirectory: String {
        emulator.workingDirectory ?? process.currentDirectory ?? directory
    }

    public var title: String {
        if let customTitle, !customTitle.isEmpty { return customTitle }
        let name = process.foregroundProcessName ?? (shell as NSString).lastPathComponent
        let folder = (workingDirectory as NSString).lastPathComponent
        return folder.isEmpty ? name : "\(name) — \(folder)"
    }

    public func start() {
        exitCode = nil
        do {
            try process.start(executable: shell, loginShell: view.settings.loginShell, environment: PseudoTerminalProcess.environment(),
                              workingDirectory: directory, columns: emulator.columns, rows: emulator.rows)
            if let initialCommand, !initialCommand.isEmpty { process.write(initialCommand + "\n") }
        } catch {
            emulator.feed("\u{1B}[31m\(error)\u{1B}[0m\r\n")
            view.contentDidChange()
            exitCode = -1
        }
        onChange?()
    }

    private func input(_ data: Data) {
        if process.isRunning {
            process.write(data)
        } else if data == Data([0x0D]) {
            restart()
        }
    }

    private func exited(_ code: Int32) {
        exitCode = code
        emulator.feed("\r\n\u{1B}[0m\u{1B}[2m[Process completed with exit code \(code). Press Return to restart.]\u{1B}[0m\r\n")
        view.contentDidChange()
        onChange?()
    }

    public func restart() {
        if process.isRunning { process.terminate() }
        directory = workingDirectory
        emulator.feed("\u{1B}c")
        emulator.clearScrollback()
        view.contentDidChange()
        if process.isRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.restart() }
            return
        }
        start()
    }

    public func run(_ command: String) {
        guard process.isRunning else { return }
        view.scrollToBottom()
        process.write(command + "\n")
    }

    public func clear() {
        emulator.clearAll()
        view.clearSelection()
        view.clearSearch()
        view.contentDidChange()
        if process.isRunning, !emulator.usingAlternateScreen { process.write("\u{0C}") }
    }

    public func terminate() {
        process.onExit = nil
        process.terminate()
    }

    public var fullText: String {
        emulator.text(from: TerminalPosition(line: 0, column: 0), to: TerminalPosition(line: emulator.totalLines - 1, column: emulator.columns - 1))
    }
}

@MainActor
final class TerminalTab {
    let id = UUID()
    var sessions: [TerminalSessionController]
    var activeIndex = 0
    let splitView = NSSplitView()

    init(session: TerminalSessionController) {
        sessions = [session]
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(session.view)
    }

    var active: TerminalSessionController { sessions[min(activeIndex, sessions.count - 1)] }

    func add(_ session: TerminalSessionController) {
        sessions.append(session)
        splitView.addArrangedSubview(session.view)
        splitView.adjustSubviews()
        let width = splitView.bounds.width / CGFloat(sessions.count)
        for i in 0..<(sessions.count - 1) { splitView.setPosition(width * CGFloat(i + 1), ofDividerAt: i) }
        activeIndex = sessions.count - 1
    }

    func remove(_ session: TerminalSessionController) {
        guard let i = sessions.firstIndex(where: { $0 === session }) else { return }
        session.terminate()
        session.view.removeFromSuperview()
        sessions.remove(at: i)
        activeIndex = min(activeIndex, max(0, sessions.count - 1))
        splitView.adjustSubviews()
    }
}

final class TerminalTabButton: NSControl {
    let tabID: UUID
    var isActive = false { didSet { needsDisplay = true } }
    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?
    var onRename: (() -> Void)?
    private let label = NSTextField(labelWithString: "")
    private let close = NSButton()
    private let icon = NSImageView()

    init(id: UUID) {
        tabID = id
        super.init(frame: .zero)
        icon.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: 10, weight: .medium)
        icon.contentTintColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 11)
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Tab")
        close.symbolConfiguration = .init(pointSize: 8, weight: .bold)
        close.isBordered = false
        close.contentTintColor = .secondaryLabelColor
        close.target = self
        close.action = #selector(closeClicked)
        close.toolTip = "Close this terminal"
        let stack = NSStackView(views: [icon, label, close])
        stack.spacing = 5
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 22), widthAnchor.constraint(lessThanOrEqualToConstant: 200),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])
        setAccessibilityRole(.radioButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var title: String {
        get { label.stringValue }
        set {
            label.stringValue = newValue
            toolTip = newValue
            setAccessibilityLabel(newValue)
        }
    }

    var exited = false { didSet { icon.contentTintColor = exited ? .systemRed : .secondaryLabelColor } }

    override func draw(_ dirtyRect: NSRect) {
        guard isActive else { return }
        NSColor.labelColor.withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onRename?() } else { onSelect?() }
    }

    @objc private func closeClicked() { onClose?() }
}

@MainActor
public final class TerminalPanelController: NSViewController, NSSearchFieldDelegate, NSMenuDelegate {
    public private(set) var settings = TerminalSettings.load()
    public var workspaceFolder: URL?
    public var onClose: (() -> Void)?
    public var onToggleMaximize: (() -> Void)?
    public var onOpenPath: ((String, Int?) -> Bool)?
    public var showsPanelControls = true

    private var tabs: [TerminalTab] = []
    private var activeTabID: UUID?
    private let tabStack = NSStackView()
    private let content = NSView()
    private let header = NSView()
    private let findBar = NSStackView()
    private let findField = NSSearchField()
    private let findCount = NSTextField(labelWithString: "")
    private var findHeight: NSLayoutConstraint!
    private var titleTimer: Timer?
    private let gearMenu = NSMenu()
    private let runMenu = NSMenu()
    private let shellMenu = NSMenu()

    public init(workspaceFolder: URL? = nil) {
        self.workspaceFolder = workspaceFolder
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public var sessionCount: Int { tabs.reduce(0) { $0 + $1.sessions.count } }
    public var tabCount: Int { tabs.count }
    public var activeSession: TerminalSessionController? { activeTab?.active }
    private var activeTab: TerminalTab? { tabs.first { $0.id == activeTabID } }

    private func button(_ symbol: String, _ tip: String, _ action: Selector) -> NSButton {
        let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage(), target: self, action: action)
        b.isBordered = false
        b.symbolConfiguration = .init(pointSize: 12, weight: .regular)
        b.contentTintColor = .secondaryLabelColor
        b.toolTip = tip
        b.setAccessibilityLabel(tip)
        b.widthAnchor.constraint(equalToConstant: 24).isActive = true
        return b
    }

    private func pullDown(_ symbol: String, _ tip: String, _ menu: NSMenu, width: CGFloat = 24) -> NSPopUpButton {
        let p = NSPopUpButton(frame: .zero, pullsDown: true)
        p.isBordered = false
        p.imagePosition = .imageOnly
        (p.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        menu.delegate = self
        menu.autoenablesItems = false
        let first = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        first.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)?.withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
        menu.addItem(first)
        p.menu = menu
        p.toolTip = tip
        p.setAccessibilityLabel(tip)
        p.widthAnchor.constraint(equalToConstant: width).isActive = true
        return p
    }

    public override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 260))
        tabStack.orientation = .horizontal
        tabStack.spacing = 2
        let tabScroll = NSScrollView()
        tabScroll.drawsBackground = false
        tabScroll.hasHorizontalScroller = false
        tabScroll.documentView = tabStack
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        tabScroll.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var trailing: [NSView] = [
            pullDown("play.rectangle", "Run a project command or saved snippet", runMenu),
            button("magnifyingglass", "Find in terminal output (⌘F)", #selector(toggleFind(_:))),
            button("rectangle.split.2x1", "Split terminal (⌘D)", #selector(splitTerminal(_:))),
            button("clear", "Clear terminal (⌘K)", #selector(clearTerminal(_:))),
            button("arrow.clockwise", "Restart the shell in this terminal", #selector(restartTerminal(_:))),
            pullDown("gearshape", "Terminal settings", gearMenu),
        ]
        if showsPanelControls {
            trailing.append(button("arrow.up.left.and.arrow.down.right", "Maximize or restore the terminal panel", #selector(maximizeClicked(_:))))
            trailing.append(button("xmark", "Hide the terminal panel", #selector(closeClicked(_:))))
        }
        let newTab = button("plus", "New terminal (⌘T)", #selector(newTerminal(_:)))
        let shells = pullDown("chevron.down", "New terminal with a specific shell", shellMenu, width: 18)
        let bar = NSStackView(views: [tabScroll, newTab, shells, NSView()] + trailing)
        bar.orientation = .horizontal
        bar.spacing = 2
        bar.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        bar.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(bar)
        let separator = NSBox()
        separator.boxType = .separator

        findField.placeholderString = "Find in output"
        findField.delegate = self
        findField.target = self
        findField.action = #selector(findNext(_:))
        findField.controlSize = .small
        findField.widthAnchor.constraint(equalToConstant: 240).isActive = true
        findCount.font = .systemFont(ofSize: 11)
        findCount.textColor = .secondaryLabelColor
        let done = NSButton(title: "Done", target: self, action: #selector(toggleFind(_:)))
        done.controlSize = .small
        done.bezelStyle = .rounded
        for v in [findField, button("chevron.up", "Previous match", #selector(findPrevious(_:))), button("chevron.down", "Next match", #selector(findNext(_:))),
                  findCount, NSView(), done] as [NSView] { findBar.addArrangedSubview(v) }
        findBar.orientation = .horizontal
        findBar.spacing = 6
        findBar.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        findBar.isHidden = true

        for v in [header, separator, findBar, content] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(v)
        }
        findHeight = findBar.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor), header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor), header.heightAnchor.constraint(equalToConstant: 30),
            bar.leadingAnchor.constraint(equalTo: header.leadingAnchor), bar.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            bar.topAnchor.constraint(equalTo: header.topAnchor), bar.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            tabScroll.heightAnchor.constraint(equalToConstant: 24),
            tabStack.topAnchor.constraint(equalTo: tabScroll.contentView.topAnchor), tabStack.bottomAnchor.constraint(equalTo: tabScroll.contentView.bottomAnchor),
            tabStack.leadingAnchor.constraint(equalTo: tabScroll.contentView.leadingAnchor),
            tabScroll.widthAnchor.constraint(lessThanOrEqualTo: tabStack.widthAnchor),
            separator.topAnchor.constraint(equalTo: header.bottomAnchor), separator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            findBar.topAnchor.constraint(equalTo: separator.bottomAnchor), findBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            findBar.trailingAnchor.constraint(equalTo: root.trailingAnchor), findHeight,
            content.topAnchor.constraint(equalTo: findBar.bottomAnchor), content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor), content.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        view = root
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange(_:)), name: TerminalSettings.didChange, object: nil)
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.refreshTitles() } }
        RunLoop.main.add(timer, forMode: .common)
        titleTimer = timer
    }

    public var startsAutomatically = true

    public override func viewDidAppear() {
        super.viewDidAppear()
        if startsAutomatically { ensureSession() }
    }

    public func ensureSession() {
        if tabs.isEmpty { newTab() }
    }

    public func shutdown() {
        titleTimer?.invalidate()
        titleTimer = nil
        for tab in tabs { tab.sessions.forEach { $0.terminate() } }
        tabs.removeAll()
    }

    private var defaultDirectory: String { workspaceFolder?.path ?? NSHomeDirectory() }

    private func makeSession(shell: String? = nil, directory: String? = nil, command: String? = nil) -> TerminalSessionController {
        let session = TerminalSessionController(settings: settings, shell: shell, directory: directory ?? defaultDirectory, command: command)
        session.onChange = { [weak self] in self?.refreshTitles() }
        session.onBell = { [weak self] in if self?.settings.audibleBell == true { NSSound.beep() } }
        session.view.onOpenPath = { [weak self] path, line in self?.onOpenPath?(path, line) ?? false }
        session.view.onCommand = { [weak self] command in self?.perform(command) ?? false }
        session.view.onFocus = { [weak self, weak session] in
            guard let self, let session, let tab = self.tabs.first(where: { $0.sessions.contains { $0 === session } }) else { return }
            tab.activeIndex = tab.sessions.firstIndex { $0 === session } ?? 0
            if self.activeTabID != tab.id { self.select(tab.id) } else { self.refreshTitles() }
        }
        session.view.contextMenuItems = { [weak self] in self?.contextItems() ?? [] }
        return session
    }

    @discardableResult
    public func newTab(shell: String? = nil, directory: String? = nil, command: String? = nil) -> TerminalSessionController {
        loadViewIfNeeded()
        let session = makeSession(shell: shell, directory: directory, command: command)
        let tab = TerminalTab(session: session)
        tabs.append(tab)
        rebuildTabs()
        select(tab.id)
        view.layoutSubtreeIfNeeded()
        session.start()
        return session
    }

    private func select(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        activeTabID = id
        content.subviews.forEach { $0.removeFromSuperview() }
        let split = tab.splitView
        split.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(split)
        NSLayoutConstraint.activate([
            split.topAnchor.constraint(equalTo: content.topAnchor), split.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            split.leadingAnchor.constraint(equalTo: content.leadingAnchor), split.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        refreshTitles()
        if !findBar.isHidden { runFind(advance: false) }
        focus()
    }

    public func focus() {
        guard let session = activeSession, let window = view.window, window.firstResponder !== session.view else { return }
        window.makeFirstResponder(session.view)
    }

    private func rebuildTabs() {
        tabStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tab in tabs {
            let b = TerminalTabButton(id: tab.id)
            b.onSelect = { [weak self] in self?.select(tab.id) }
            b.onClose = { [weak self] in self?.close(tab: tab.id) }
            b.onRename = { [weak self] in self?.rename(tab: tab.id) }
            tabStack.addArrangedSubview(b)
        }
        refreshTitles()
    }

    private func refreshTitles() {
        for case let b as TerminalTabButton in tabStack.arrangedSubviews {
            guard let tab = tabs.first(where: { $0.id == b.tabID }) else { continue }
            let base = tab.active.title
            b.title = tab.sessions.count > 1 ? "\(base) (\(tab.sessions.count))" : base
            b.isActive = tab.id == activeTabID
            b.exited = tab.sessions.allSatisfy { !$0.isRunning }
        }
    }

    public func close(tab id: UUID) {
        guard let i = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[i].sessions.forEach { $0.terminate() }
        tabs[i].splitView.removeFromSuperview()
        tabs.remove(at: i)
        rebuildTabs()
        if tabs.isEmpty {
            activeTabID = nil
            if let onClose, showsPanelControls { onClose() } else { newTab() }
        } else if activeTabID == id {
            select(tabs[min(i, tabs.count - 1)].id)
        }
    }

    private func closeActivePane() {
        guard let tab = activeTab else { return }
        if tab.sessions.count > 1 {
            tab.remove(tab.active)
            refreshTitles()
            focus()
        } else {
            close(tab: tab.id)
        }
    }

    private func rename(tab id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }), let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Rename Terminal"
        alert.informativeText = "Leave the name empty to show the running command and folder."
        let field = NSTextField(string: tab.active.customTitle ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 22)
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            tab.active.customTitle = field.stringValue.trimmingCharacters(in: .whitespaces)
            self?.refreshTitles()
        }
    }

    private func perform(_ command: TerminalViewCommand) -> Bool {
        switch command {
        case .newTab: newTab()
        case .closePane: closeActivePane()
        case .split: splitTerminal(nil)
        case .clear: clearTerminal(nil)
        case .find: showFind()
        case .nextTab: cycle(1)
        case .previousTab: cycle(-1)
        case .biggerFont: changeFontSize(by: 1)
        case .smallerFont: changeFontSize(by: -1)
        case .resetFont: update { $0.fontSize = TerminalSettings().fontSize }
        }
        return true
    }

    private func cycle(_ delta: Int) {
        guard tabs.count > 1, let i = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        select(tabs[(i + delta + tabs.count) % tabs.count].id)
    }

    @objc public func newTerminal(_ sender: Any?) { newTab() }

    @objc func newTerminalWithShell(_ sender: NSMenuItem) {
        guard let shell = sender.representedObject as? String else { return }
        newTab(shell: shell)
    }

    @objc public func splitTerminal(_ sender: Any?) {
        guard let tab = activeTab else { newTab(); return }
        guard tab.sessions.count < 4 else { return NSSound.beep() }
        let session = makeSession(directory: tab.active.workingDirectory)
        tab.add(session)
        view.layoutSubtreeIfNeeded()
        session.start()
        refreshTitles()
        focus()
    }

    @objc public func clearTerminal(_ sender: Any?) { activeSession?.clear() }
    @objc public func restartTerminal(_ sender: Any?) { activeSession?.restart() }
    @objc func closeClicked(_ sender: Any?) { onClose?() }
    @objc func maximizeClicked(_ sender: Any?) { onToggleMaximize?() }

    @objc func closePaneClicked(_ sender: Any?) { closeActivePane() }

    @objc func interruptClicked(_ sender: Any?) { activeSession?.process.send(signal: SIGINT) }

    @objc func killClicked(_ sender: Any?) {
        guard let session = activeSession, session.isRunning else { return }
        session.process.send(signal: SIGKILL)
    }

    public func run(_ command: String) {
        loadViewIfNeeded()
        if let session = activeSession, session.isRunning, !session.process.hasForegroundJob {
            session.run(command)
        } else {
            newTab(command: command)
        }
        focus()
    }

    public func changeDirectory(to path: String) {
        run("cd " + TerminalProjectCommands.quote(path))
    }

    private func update(_ change: (inout TerminalSettings) -> Void) {
        var next = settings
        change(&next)
        guard next != settings else { return }
        settings = next
        next.save()
    }

    @objc private func settingsDidChange(_ note: Notification) { reloadSettings() }

    private func reloadSettings() {
        settings = TerminalSettings.load()
        for tab in tabs { tab.sessions.forEach { $0.view.settings = settings } }
    }

    private func changeFontSize(by delta: Double) {
        update { $0.fontSize = min(max($0.fontSize + delta, TerminalSettings.fontSizeRange.lowerBound), TerminalSettings.fontSizeRange.upperBound) }
    }

    private func showFind() {
        findBar.isHidden = false
        findHeight.constant = 28
        view.window?.makeFirstResponder(findField)
    }

    @objc public func toggleFind(_ sender: Any?) {
        if findBar.isHidden {
            showFind()
        } else {
            findBar.isHidden = true
            findHeight.constant = 0
            tabs.forEach { $0.sessions.forEach { $0.view.clearSearch() } }
            focus()
        }
    }

    private func runFind(backwards: Bool = false, advance: Bool = true) {
        guard let session = activeSession else { return }
        let query = findField.stringValue
        guard !query.isEmpty else {
            session.view.clearSearch()
            findCount.stringValue = ""
            return
        }
        let r = session.view.search(query, backwards: backwards, advance: advance)
        findCount.stringValue = r.total == 0 ? "No matches" : "\(r.current) of \(r.total)"
    }

    @objc func findNext(_ sender: Any?) { runFind() }
    @objc func findPrevious(_ sender: Any?) { runFind(backwards: true) }

    public func controlTextDidChange(_ note: Notification) {
        activeSession?.view.clearSearch()
        runFind(backwards: true)
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            toggleFind(nil)
            return true
        }
        return false
    }

    private func item(_ title: String, _ action: Selector?, on: Bool = false, enabled: Bool = true, object: Any? = nil) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        i.state = on ? .on : .off
        i.isEnabled = enabled && action != nil
        i.representedObject = object
        return i
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        items.forEach(menu.addItem)
        parent.submenu = menu
        return parent
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        while menu.items.count > 1 { menu.removeItem(at: 1) }
        if menu === gearMenu {
            gearItems().forEach(menu.addItem)
        } else if menu === runMenu {
            runItems().forEach(menu.addItem)
        } else if menu === shellMenu {
            for shell in PseudoTerminalProcess.availableShells() {
                menu.addItem(item("New \((shell as NSString).lastPathComponent) Terminal  (\(shell))", #selector(newTerminalWithShell(_:)), object: shell))
            }
        }
    }

    private func gearItems() -> [NSMenuItem] {
        let themes = [item("Match Appearance", #selector(themeChosen(_:)), on: settings.themeID == TerminalTheme.systemID, object: TerminalTheme.systemID), .separator()]
            + TerminalTheme.all.map { item($0.name, #selector(themeChosen(_:)), on: settings.themeID == $0.id, object: $0.id) }
        let cursor = TerminalCursorShape.allCases.map { item($0.title, #selector(cursorChosen(_:)), on: settings.cursorShape == $0, object: $0.rawValue) }
            + [.separator(), item("Blink", #selector(toggleBlink(_:)), on: settings.cursorBlink)]
        let scrollback = [1000, 10000, 50000, 200000].map {
            item("\($0.formatted()) lines", #selector(scrollbackChosen(_:)), on: settings.scrollbackLines == $0, object: $0)
        }
        let shells = [item("Login Shell Default", #selector(defaultShellChosen(_:)), on: settings.shellPath.isEmpty, object: "")]
            + PseudoTerminalProcess.availableShells().map { item($0, #selector(defaultShellChosen(_:)), on: settings.shellPath == $0, object: $0) }
        let running = activeSession?.isRunning == true
        return [
            submenu("Theme", themes),
            submenu("Font Size", [item("Bigger  ⌘+", #selector(biggerFont(_:))), item("Smaller  ⌘−", #selector(smallerFont(_:))),
                                  item("Reset to Default  ⌘0", #selector(resetFont(_:))), .separator(),
                                  item("Choose Font…", #selector(chooseFont(_:)))]),
            submenu("Cursor", cursor),
            submenu("Scrollback", scrollback),
            submenu("Default Shell", shells),
            .separator(),
            item("Use Option as Meta Key", #selector(toggleMeta(_:)), on: settings.optionAsMeta),
            item("Copy on Select", #selector(toggleCopyOnSelect(_:)), on: settings.copyOnSelect),
            item("Audible Bell", #selector(toggleBell(_:)), on: settings.audibleBell),
            item("Start Shells as Login Shells", #selector(toggleLogin(_:)), on: settings.loginShell),
            .separator(),
            item("Send Interrupt (⌃C)", #selector(interruptClicked(_:)), enabled: running),
            item("Kill Foreground Process", #selector(killClicked(_:)), enabled: running),
            item("Clear Scrollback", #selector(clearScrollback(_:))),
            item("Save Output As…", #selector(saveOutput(_:))),
            item("Reveal Working Directory in Finder", #selector(revealDirectory(_:))),
        ]
    }

    private func runItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let folder = activeSession.map { URL(fileURLWithPath: $0.workingDirectory) } ?? workspaceFolder
        let suggestions = TerminalProjectCommands.suggestions(in: folder)
        if !suggestions.isEmpty {
            let heading = NSMenuItem(title: "In \(folder?.lastPathComponent ?? "Folder")", action: nil, keyEquivalent: "")
            heading.isEnabled = false
            items.append(heading)
            items += suggestions.map { item($0.name, #selector(runSnippet(_:)), object: $0.command) }
            items.append(.separator())
        }
        if !settings.snippets.isEmpty {
            let heading = NSMenuItem(title: "Saved Snippets", action: nil, keyEquivalent: "")
            heading.isEnabled = false
            items.append(heading)
            items += settings.snippets.map { item($0.name, #selector(runSnippet(_:)), object: $0.command) }
            items.append(.separator())
        }
        items.append(item("New Snippet…", #selector(newSnippet(_:))))
        if !settings.snippets.isEmpty {
            items.append(submenu("Remove Snippet", settings.snippets.map { item($0.name, #selector(removeSnippet(_:)), object: $0.id) }))
        }
        if let root = workspaceFolder {
            items.append(.separator())
            items.append(item("Go to Project Folder", #selector(goToProject(_:)), object: root.path))
        }
        return items
    }

    private func contextItems() -> [NSMenuItem] {
        [item("Clear", #selector(clearTerminal(_:))), item("Find…", #selector(toggleFind(_:))), .separator(),
         item("Split Terminal", #selector(splitTerminal(_:))), item("New Terminal", #selector(newTerminal(_:))),
         item("Close Terminal", #selector(closePaneClicked(_:))), .separator(),
         item("Restart Shell", #selector(restartTerminal(_:))),
         item("Reveal Working Directory in Finder", #selector(revealDirectory(_:)))]
    }

    @objc func themeChosen(_ sender: NSMenuItem) { update { $0.themeID = sender.representedObject as? String ?? TerminalTheme.systemID } }
    @objc func cursorChosen(_ sender: NSMenuItem) {
        update { $0.cursorShape = TerminalCursorShape(rawValue: sender.representedObject as? Int ?? 0) ?? .block }
    }
    @objc func toggleBlink(_ sender: Any?) { update { $0.cursorBlink.toggle() } }
    @objc func scrollbackChosen(_ sender: NSMenuItem) { update { $0.scrollbackLines = sender.representedObject as? Int ?? 10000 } }
    @objc func defaultShellChosen(_ sender: NSMenuItem) { update { $0.shellPath = sender.representedObject as? String ?? "" } }
    @objc func biggerFont(_ sender: Any?) { changeFontSize(by: 1) }
    @objc func smallerFont(_ sender: Any?) { changeFontSize(by: -1) }
    @objc func resetFont(_ sender: Any?) { update { $0.fontSize = TerminalSettings().fontSize; $0.fontName = "" } }
    @objc func toggleMeta(_ sender: Any?) { update { $0.optionAsMeta.toggle() } }
    @objc func toggleCopyOnSelect(_ sender: Any?) { update { $0.copyOnSelect.toggle() } }
    @objc func toggleBell(_ sender: Any?) { update { $0.audibleBell.toggle() } }
    @objc func toggleLogin(_ sender: Any?) { update { $0.loginShell.toggle() } }

    @objc func chooseFont(_ sender: Any?) {
        let manager = NSFontManager.shared
        manager.target = self
        manager.action = #selector(fontPanelChanged(_:))
        manager.setSelectedFont(settings.font, isMultiple: false)
        manager.orderFrontFontPanel(self)
    }

    @objc func fontPanelChanged(_ sender: NSFontManager) {
        let font = sender.convert(settings.font)
        guard font.isFixedPitch else { return NSSound.beep() }
        update {
            $0.fontName = font.fontName
            $0.fontSize = min(max(Double(font.pointSize), TerminalSettings.fontSizeRange.lowerBound), TerminalSettings.fontSizeRange.upperBound)
        }
    }

    @objc func clearScrollback(_ sender: Any?) {
        guard let session = activeSession else { return }
        session.emulator.clearScrollback()
        session.view.contentDidChange()
    }

    @objc func saveOutput(_ sender: Any?) {
        guard let session = activeSession, let window = view.window else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "terminal-output.txt"
        let text = session.fullText
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do { try text.write(to: url, atomically: true, encoding: .utf8) } catch { NSApp.presentError(error) }
        }
    }

    @objc func revealDirectory(_ sender: Any?) {
        guard let session = activeSession else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: session.workingDirectory)])
    }

    @objc func runSnippet(_ sender: NSMenuItem) {
        guard let command = sender.representedObject as? String else { return }
        run(command)
    }

    @objc func goToProject(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        changeDirectory(to: path)
    }

    @objc func removeSnippet(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        update { $0.snippets.removeAll { $0.id == id } }
    }

    @objc func newSnippet(_ sender: Any?) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "New Terminal Snippet"
        alert.informativeText = "Saved snippets appear in the Run menu of every terminal."
        let name = NSTextField(string: "")
        name.placeholderString = "Name"
        let command = NSTextField(string: "")
        command.placeholderString = "Command, for example: swift build -c release"
        command.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        let stack = NSStackView(views: [name, command])
        stack.orientation = .vertical
        stack.frame = NSRect(x: 0, y: 0, width: 340, height: 52)
        for f in [name, command] { f.widthAnchor.constraint(equalToConstant: 340).isActive = true }
        alert.accessoryView = stack
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = name
        alert.beginSheetModal(for: window) { [weak self] response in
            let text = command.stringValue.trimmingCharacters(in: .whitespaces)
            guard response == .alertFirstButtonReturn, !text.isEmpty else { return }
            let title = name.stringValue.trimmingCharacters(in: .whitespaces)
            self?.update { $0.snippets.append(TerminalSnippet(name: title.isEmpty ? text : title, command: text)) }
        }
    }
}
