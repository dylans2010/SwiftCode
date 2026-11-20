import AppKit
import SwiftUI
import YcodeIDECore
import YcodePlist
import YcodeProject

extension ProjectEditorController {

    static func sectionKey(_ title: String) -> String {
        if let r = title.range(of: " (", options: .backwards), title.hasSuffix(")") { return String(title[..<r.lowerBound]) }
        return title
    }

    func section(_ title: String, _ body: NSView, accessory: [NSView] = []) -> CollapsibleSection {
        let key = Self.sectionKey(title)
        let s = CollapsibleSection(title: title, body: body, collapsed: collapsedSections.contains(key), accessory: accessory)
        s.onToggle = { [weak self] collapsed in
            if collapsed { self?.collapsedSections.insert(key) } else { self?.collapsedSections.remove(key) }
        }
        sectionViews[key] = s
        return s
    }

    public func toggleSection(_ title: String) {
        sectionViews[Self.sectionKey(title)]?.setCollapsed(!(sectionViews[Self.sectionKey(title)]?.isCollapsed ?? false))
    }

    func table(_ key: String, columns: [String], rows: [[NSView]], empty: String? = nil, plus: Selector? = nil, minus: Selector? = nil,
               width: CGFloat = 520) -> NSView {
        let t = StaticTable(columns: columns, rows: rows, emptyText: empty, plusMinus: (plus != nil || minus != nil) || empty != nil ? (self, plus, minus) : nil,
                            width: width)
        tables[key] = t
        return t.container
    }

    func page(_ views: [NSView]) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 24, bottom: 20, right: 24)
        let flipped = FlippedView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        flipped.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: flipped.topAnchor), stack.leadingAnchor.constraint(equalTo: flipped.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: flipped.trailingAnchor), stack.bottomAnchor.constraint(equalTo: flipped.bottomAnchor),
        ])
        let scroll = NSScrollView()
        scroll.documentView = flipped
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        flipped.translatesAutoresizingMaskIntoConstraints = false
        flipped.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        return scroll
    }

    func grid(_ rows: [(String, NSView)]) -> NSGridView {
        let g = NSGridView(views: rows.map { [label($0.0), $0.1] })
        g.column(at: 0).xPlacement = .trailing
        g.rowAlignment = .firstBaseline
        g.rowSpacing = 8
        return g
    }

    func settingField(_ key: String, target t: String, placeholder: String? = nil, width: CGFloat = 300) -> NSTextField {
        let f = NSTextField(string: resolved(key, target: t))
        f.identifier = .init(key)
        f.placeholderString = placeholder
        f.delegate = self
        f.widthAnchor.constraint(equalToConstant: width).isActive = true
        return f
    }

    func generalView(_ t: String) -> NSView {
        var sections: [NSView] = []
        let devices = model.deploymentInfoDevices(target: t, configuration: configuration)
        for title in model.generalSections(target: t, configuration: configuration) {
            let body: NSView
            switch title {
            case "Supported Destinations":
                let dests = model.supportedDestinations(target: t, configuration: configuration)
                let rows = dests.map { [NSTextField.cell($0.name), NSTextField.cell($0.sdk)] as [NSView] }
                body = table(title, columns: ["Destination", "SDK"], rows: rows, plus: #selector(destinationPlusClicked(_:)),
                             minus: #selector(destinationMinusClicked(_:)))
                tables[title]?.itemIDs = dests.map(\.name)
            case "Minimum Deployments":
                body = grid(model.minimumDeployments(target: t, configuration: configuration).map { d in
                    let combo = NSComboBox()
                    combo.addItems(withObjectValues: ProjectEditorModel.deploymentVersions)
                    combo.stringValue = d.value
                    combo.identifier = .init(d.setting)
                    combo.delegate = self
                    combo.widthAnchor.constraint(equalToConstant: 100).isActive = true
                    let plus = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Add platform")!, target: self,
                                        action: #selector(deploymentPlusClicked(_:)))
                    plus.isBordered = false
                    plus.identifier = .init("addDeploymentPlatform")
                    plus.isEnabled = !model.addableDeploymentSDKs(target: t, configuration: configuration).isEmpty
                    return (d.sdk, NSStackView(views: [combo, plus]))
                })
            case "Identity":
                body = identityBody(t)
            case "Deployment Info":
                var rows: [(String, NSView)] = []
                let isIOS = model.hasIOSDestination(target: t, configuration: configuration)
                let depSetting = isIOS ? "IPHONEOS_DEPLOYMENT_TARGET" : "MACOSX_DEPLOYMENT_TARGET"
                let targetVersionPop = NSPopUpButton(frame: .zero, pullsDown: false)
                let versions = isIOS ? ["15.0", "16.0", "17.0", "18.0", "18.1", "18.2"] : ["13.0", "14.0", "15.0", "15.1", "15.2", "26.0"]
                targetVersionPop.addItems(withTitles: versions)
                let currentVer = resolved(depSetting, target: t)
                if versions.contains(currentVer) { targetVersionPop.selectItem(withTitle: currentVer) }
                else if !currentVer.isEmpty { targetVersionPop.addItem(withTitle: currentVer); targetVersionPop.selectItem(withTitle: currentVer) }
                targetVersionPop.target = self
                targetVersionPop.action = #selector(deploymentTargetChanged(_:))
                targetVersionPop.identifier = .init(depSetting)
                rows.append(("Deployment Target", targetVersionPop))

                let supportsIPhone = NSButton(checkboxWithTitle: "iPhone", target: self, action: #selector(deviceSupportToggled(_:)))
                supportsIPhone.identifier = .init("support:1")
                let supportsIPad = NSButton(checkboxWithTitle: "iPad", target: self, action: #selector(deviceSupportToggled(_:)))
                supportsIPad.identifier = .init("support:2")
                let supportsMac = NSButton(checkboxWithTitle: "Mac", target: self, action: #selector(deviceSupportToggled(_:)))
                supportsMac.identifier = .init("support:mac")
                let currentFam = resolved("TARGETED_DEVICE_FAMILY", target: t)
                supportsIPhone.state = (currentFam.contains("1") || currentFam.isEmpty) ? .on : .off
                supportsIPad.state = currentFam.contains("2") ? .on : .off
                supportsMac.state = resolved("SUPPORTED_PLATFORMS", target: t).contains("macosx") ? .on : .off
                let devStack = NSStackView(views: [supportsIPhone, supportsIPad, supportsMac])
                rows.append(("Device Support", devStack))

                let catalystToggle = NSButton(checkboxWithTitle: "Enable Mac Catalyst", target: self, action: #selector(catalystToggled(_:)))
                catalystToggle.state = resolved("SUPPORTS_MACCATALYST", target: t) == "YES" ? .on : .off
                rows.append(("Mac Catalyst", catalystToggle))

                let targetDevices = devices.isEmpty ? ["iPhone", "iPad"] : devices
                for device in targetDevices {
                    let on = model.orientations(device: device, target: t, configuration: configuration)
                    let boxes = ProjectEditorModel.orientations.map { o -> NSView in
                        let b = NSButton(checkboxWithTitle: o.title, target: self, action: #selector(orientationToggled(_:)))
                        b.identifier = .init("\(device):\(o.value)")
                        b.state = on.contains(o.value) ? .on : .off
                        return b
                    }
                    let col = NSStackView(views: boxes)
                    col.orientation = .vertical
                    col.alignment = .leading
                    rows.append(("\(device) Orientation", col))
                }
                let style = NSPopUpButton(frame: .zero, pullsDown: false)
                style.addItems(withTitles: ["Default", "Dark Content", "Light Content"])
                let currentStyleRaw = resolved("INFOPLIST_KEY_UIStatusBarStyle", target: t)
                let currentStyle = ["UIStatusBarStyleDarkContent": "Dark Content", "UIStatusBarStyleLightContent": "Light Content"][currentStyleRaw] ?? "Default"
                style.selectItem(withTitle: currentStyle)
                style.target = self
                style.action = #selector(statusBarStyleChosen(_:))
                style.identifier = .init("INFOPLIST_KEY_UIStatusBarStyle")
                let hide = NSButton(checkboxWithTitle: "Hide during application launch", target: self, action: #selector(statusBarHiddenToggled(_:)))
                hide.state = resolved("INFOPLIST_KEY_UIStatusBarHidden", target: t) == "YES" ? .on : .off
                let scene = NSButton(title: "Scene manifest \u{2192}", target: self, action: #selector(openInfoPlistInEditor))
                scene.isBordered = false
                scene.toolTip = "Open Info.plist to edit the scene manifest"
                rows += [("Status Bar Style", NSStackView(views: [style, hide])), ("", scene)]
                body = grid(rows)
            case "App Icons and Launch Screen":
                let iconPop = NSPopUpButton(frame: .zero, pullsDown: false)
                iconPop.addItems(withTitles: ["AppIcon", "AppIcon-Dark", "AppIcon-Tinted", "AppIcon-Alternate"])
                let currentIcon = resolved("ASSETCATALOG_COMPILER_APPICON_NAME", target: t)
                if !currentIcon.isEmpty && !iconPop.itemTitles.contains(currentIcon) {
                    iconPop.addItem(withTitle: currentIcon)
                }
                if !currentIcon.isEmpty { iconPop.selectItem(withTitle: currentIcon) }
                iconPop.target = self
                iconPop.action = #selector(appIconChosen(_:))
                iconPop.identifier = .init("ASSETCATALOG_COMPILER_APPICON_NAME")

                let source = NSButton(checkboxWithTitle: "Include all app icon assets", target: self, action: #selector(includeAllIconsToggled(_:)))
                source.state = resolved("ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS", target: t) == "YES" ? .on : .off
                let launch = NSComboBox()
                launch.placeholderString = "Storyboard Base Name"
                launch.stringValue = resolved("INFOPLIST_KEY_UILaunchStoryboardName", target: t)
                launch.identifier = .init("INFOPLIST_KEY_UILaunchStoryboardName")
                launch.delegate = self
                launch.widthAnchor.constraint(equalToConstant: 260).isActive = true
                var iconRows: [(String, NSView)] = [
                    ("App Icon Set", iconPop),
                    ("App Icons Source", source)
                ]
                if model.hasIOSDestination(target: t, configuration: configuration) { iconRows.append(("Launch Screen File", launch)) }
                iconRows.append(("Global Accent Color", settingField("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", target: t, width: 260)))
                if let projectDir = model.projectDirectoryURL(), let preview = AppIconResolver.largestAppIcon(in: projectDir) {
                    let imageView = NSImageView(image: preview)
                    imageView.imageScaling = NSImageScaling.scaleProportionallyUpOrDown
                    imageView.widthAnchor.constraint(equalToConstant: 64).isActive = true
                    imageView.heightAnchor.constraint(equalToConstant: 64).isActive = true
                    imageView.wantsLayer = true
                    imageView.layer?.cornerRadius = 14
                    imageView.layer?.masksToBounds = true
                    imageView.toolTip = "Resolved from the project's .appiconset"
                    iconRows.append(("Icon Preview", imageView))
                }
                let composerButton = NSButton(title: "Open in Icon Composer…", target: self, action: #selector(openIconComposerClicked))
                composerButton.bezelStyle = .rounded
                iconRows.append(("Icon Composer", composerButton))
                body = grid(iconRows)
            case "Frameworks, Libraries, and Embedded Content":
                let link = model.phaseSections(target: t).first { $0.title == "Link Binary With Libraries" }
                let embedded = model.embeddedAndSigned(target: t)
                let rows = (link?.items ?? []).map { item -> [NSView] in
                    let embed = NSPopUpButton(frame: .zero, pullsDown: false)
                    embed.addItems(withTitles: ["Do Not Embed", "Embed & Sign", "Embed Without Signing"])
                    embed.selectItem(withTitle: embedded.contains(item.name) ? "Embed & Sign" : "Do Not Embed")
                    embed.controlSize = .small
                    let statusLabel = NSTextField(labelWithString: embedded.contains(item.name) ? "Embedded & Signed" : "Linked Only")
                    statusLabel.font = .systemFont(ofSize: 11)
                    statusLabel.textColor = .secondaryLabelColor
                    return [NSTextField.cell(item.name), embed, statusLabel]
                }
                let addFrameworkBtn = NSButton(title: "+ Add Framework…", target: self, action: #selector(addFrameworkClicked))
                addFrameworkBtn.bezelStyle = .rounded
                let removeFrameworkBtn = NSButton(title: "Remove Framework", target: self, action: #selector(removeFrameworkClicked))
                removeFrameworkBtn.bezelStyle = .rounded
                let searchPaths = settingField("FRAMEWORK_SEARCH_PATHS", target: t, placeholder: "$(inherited) $(PROJECT_DIR)/Frameworks", width: 340)
                let frameworkTable = table(title, columns: ["Framework / Library", "Embed Option", "Status"], rows: rows, empty: ProjectEditorModel.generalEmptyTexts[title],
                             plus: #selector(addFrameworkClicked), minus: #selector(removeFrameworkClicked))
                let frameworkSection = NSStackView(views: [
                    frameworkTable,
                    NSStackView(views: [addFrameworkBtn, removeFrameworkBtn]),
                    grid([("Framework Search Paths", searchPaths)])
                ])
                frameworkSection.orientation = .vertical
                frameworkSection.alignment = .leading
                frameworkSection.spacing = 8
                body = frameworkSection
            case "Development Assets":
                let devAssetPaths = settingField("DEVELOPMENT_ASSET_PATHS", target: t, placeholder: "\"$(PROJECT_DIR)/Preview Content\"", width: 340)
                let previewAssetsDirectory = settingField("PREVIEW_ASSET_DIRECTORY", target: t, placeholder: "Preview Assets", width: 260)
                body = grid([
                    ("Preview Asset Paths", devAssetPaths),
                    ("Development Directory", previewAssetsDirectory),
                    ("Status", NSTextField.cell("Preview assets are excluded from production release builds."))
                ])
            case "Version & Build":
                let marketing = settingField("MARKETING_VERSION", target: t, placeholder: "1.0", width: 120)
                let build = settingField("CURRENT_PROJECT_VERSION", target: t, placeholder: "1", width: 120)
                let bundleVersion = settingField("CFBundleVersion", target: t, placeholder: "1", width: 120)
                let shortVersion = settingField("CFBundleShortVersionString", target: t, placeholder: "1.0", width: 120)
                body = grid([("Marketing Version", marketing), ("Current Project Version", build), ("Bundle Version", bundleVersion), ("Short Version String", shortVersion)])
            case "Localization":
                let langs = model.projectLocalizations()
                let devLang = model.projectDocumentSection.organization
                body = grid([("Known Regions", NSTextField.cell(langs.isEmpty ? "English (Development)" : langs.joined(separator: ", "))), ("Development Language", NSTextField.cell(devLang.isEmpty ? "en" : devLang)), ("Base Internationalization", NSTextField.cell("Enabled"))])
            case "Target Dependencies":
                let deps = model.targetDependencies(target: t)
                let depBody: NSView = deps.isEmpty
                    ? NSTextField(labelWithString: "No target dependencies.")
                    : grid(deps.map { ("Depends on", NSTextField.cell($0)) })
                body = depBody
            case "Resources & Entitlements":
                let entFile = resolved("CODE_SIGN_ENTITLEMENTS", target: t)
                let plistFile = resolved("INFOPLIST_FILE", target: t)
                body = grid([("Entitlements File", NSTextField.cell(entFile.isEmpty ? "None" : entFile)), ("Info.plist", NSTextField.cell(plistFile.isEmpty ? "Generated" : plistFile)), ("Asset Catalogs", NSTextField.cell("See .xcassets in the project navigator"))])
            default:
                body = NSTextField(labelWithString: "Nothing to configure here.")
            }
            sections.append(section(title, body))
        }
        return page(sections)
    }

    @objc func orientationToggled(_ b: NSButton) {
        let parts = (b.identifier?.rawValue ?? "").split(separator: ":").map(String.init)
        guard parts.count == 2 else { return }
        setOrientation(parts[1], device: parts[0], on: b.state == .on)
    }

    public func setOrientation(_ value: String, device: String, on: Bool) {
        guard let t = selectedTarget else { return }
        model.setOrientation(value, device: device, on: on, target: t, configuration: configuration)
        onChange?(model.proj)
        showTab()
    }

    @objc func statusBarHiddenToggled(_ b: NSButton) { setSetting("INFOPLIST_KEY_UIStatusBarHidden", b.state == .on ? "YES" : "") }

    @objc func statusBarStyleChosen(_ p: NSPopUpButton) {
        guard let title = p.selectedItem?.title else { return }
        let value: String
        switch title {
        case "Dark Content": value = "UIStatusBarStyleDarkContent"
        case "Light Content": value = "UIStatusBarStyleLightContent"
        default: value = ""
        }
        setSetting("INFOPLIST_KEY_UIStatusBarStyle", value)
    }

    @objc func deploymentTargetChanged(_ p: NSPopUpButton) {
        guard let title = p.selectedItem?.title, let key = p.identifier?.rawValue else { return }
        setSetting(key, title)
    }

    @objc func deviceSupportToggled(_ b: NSButton) {
        guard let id = b.identifier?.rawValue else { return }
        if id == "support:mac" {
            let cur = resolved("SUPPORTED_PLATFORMS", target: selectedTarget ?? "")
            var platforms = Set(cur.split(separator: " ").map(String.init))
            if b.state == .on { platforms.insert("macosx") } else { platforms.remove("macosx") }
            setSetting("SUPPORTED_PLATFORMS", platforms.joined(separator: " "))
        } else if id.starts(with: "support:") {
            let famID = String(id.dropFirst("support:".count))
            let cur = resolved("TARGETED_DEVICE_FAMILY", target: selectedTarget ?? "")
            var fams = Set(cur.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            if b.state == .on { fams.insert(famID) } else { fams.remove(famID) }
            setSetting("TARGETED_DEVICE_FAMILY", fams.sorted().joined(separator: ","))
        }
    }

    @objc func catalystToggled(_ b: NSButton) {
        setSetting("SUPPORTS_MACCATALYST", b.state == .on ? "YES" : "NO")
    }

    @objc func appIconChosen(_ p: NSPopUpButton) {
        guard let title = p.selectedItem?.title else { return }
        setSetting("ASSETCATALOG_COMPILER_APPICON_NAME", title)
    }

    @objc func includeAllIconsToggled(_ b: NSButton) {
        setSetting("ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS", b.state == .on ? "YES" : "NO")
    }

    @objc func addFrameworkClicked() {
        guard let t = selectedTarget, let w = view.window, w.isVisible else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = []
        panel.prompt = "Add Framework"
        panel.beginSheetModal(for: w) { [weak self] response in
            if response == .OK, let self {
                for url in panel.urls {
                    _ = self.model.addFile(url.lastPathComponent, toPhase: "Link Binary With Libraries")
                }
                self.onChange?(self.model.proj)
                self.showTab()
            }
        }
    }

    @objc func removeFrameworkClicked() {
        guard let t = selectedTarget else { return }
        if let link = model.phaseSections(target: t).first(where: { $0.title == "Link Binary With Libraries" }),
           let item = link.items.last {
            model.removeBuildFile(item.id)
            onChange?(model.proj)
            showTab()
        }
    }

    @objc func chooseEntitlementsFile() {
        guard let w = view.window, w.isVisible else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.prompt = "Select Entitlements"
        panel.beginSheetModal(for: w) { [weak self] response in
            if response == .OK, let url = panel.url, let self {
                let rel = url.lastPathComponent
                self.setSetting("CODE_SIGN_ENTITLEMENTS", rel)
                self.showTab()
            }
        }
    }

    @objc func openEntitlementsInEditor() {
        guard let t = selectedTarget else { return }
        let url = model.entitlementsURL(target: t, configuration: signingConfiguration)
            ?? model.entitlementsURL(target: t, configuration: configuration)
        if let url, let onOpenFile {
            onOpenFile(url)
        } else {
            revealSetting("CODE_SIGN_ENTITLEMENTS")
        }
    }

    
    
    
    
    
    func entitlementsView(_ t: String) -> NSView {
        let existingURL = model.entitlementsURL(target: t, configuration: signingConfiguration)
            ?? model.entitlementsURL(target: t, configuration: configuration)
        let defaultURL: URL? = {
            guard let dir = model.projectDirectoryURL() else { return nil }
            let subdir = dir.appendingPathComponent(t)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: subdir.path, isDirectory: &isDir), isDir.boolValue {
                return subdir.appendingPathComponent("\(t).entitlements")
            }
            return dir.appendingPathComponent("\(t).entitlements")
        }()
        let host = NSHostingView(rootView: EntitlementsEditorView(
            fileURL: existingURL,
            defaultCreateURL: defaultURL,
            onFileCreated: { [weak self] createdURL in
                guard let self else { return }
                let base = (self.model.projectDirectoryURL()?.standardizedFileURL.path ?? "") + "/"
                let full = createdURL.standardizedFileURL.path
                let rel = full.hasPrefix(base) ? String(full.dropFirst(base.count)) : createdURL.lastPathComponent
                if self.signingResolved("CODE_SIGN_ENTITLEMENTS", target: t).isEmpty {
                    self.setSetting("CODE_SIGN_ENTITLEMENTS", rel)
                }
            }
        ))
        host.translatesAutoresizingMaskIntoConstraints = false
        return host
    }

    func infoPlistFileURL(target t: String) -> URL? {
        let file = resolved("INFOPLIST_FILE", target: t)
        if !file.isEmpty {
            let url = file.hasPrefix("/") ? URL(fileURLWithPath: file) : model.projectDirectoryURL()?.appendingPathComponent(file)
            if let url, FileManager.default.fileExists(atPath: url.path) { return url }
        }
        guard let dir = model.projectDirectoryURL() else { return nil }
        for rel in ["\(t)/Info.plist", "Info.plist"] {
            let url = dir.appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    @objc func openInfoPlistInEditor() {
        guard let t = selectedTarget else { return }
        if let url = infoPlistFileURL(target: t), let onOpenFile {
            onOpenFile(url)
        } else {
            revealSetting("INFOPLIST_FILE")
        }
    }

    @objc func profileChosen(_ p: NSPopUpButton) {
        guard let title = p.selectedItem?.title else { return }
        setSetting("PROVISIONING_PROFILE_SPECIFIER", title.contains("Managed") ? "" : title)
    }

    @objc func certificateChosen(_ p: NSPopUpButton) {
        guard let title = p.selectedItem?.title else { return }
        setSetting("CODE_SIGN_IDENTITY", title.contains("Sign to Run Locally") ? "-" : title)
    }

    func infoView(_ t: String) -> NSView {
        var rows: [[NSView]] = []
        func add(_ item: ProjectEditorModel.InfoItem, path: String, depth: Int) {
            let indent = String(repeating: "    ", count: depth)
            let keyView: NSView
            if item.isContainer {
                let open = expandedInfoKeys.contains(path)
                let d = NSButton(title: indent + (open ? "\u{25BE} " : "\u{25B8} ") + item.key, target: self, action: #selector(infoKeyDisclosureClicked(_:)))
                d.isBordered = false
                d.alignment = .left
                d.identifier = .init(path)
                d.toolTip = item.rawKey
                keyView = d
            } else {
                let f = NSTextField.cell(indent + item.key)
                f.toolTip = item.rawKey
                keyView = f
            }
            rows.append([keyView, NSTextField.cell(item.type), NSTextField.cell(item.value)])
            infoRowPaths.append(path)
            if item.isContainer, expandedInfoKeys.contains(path) {
                for c in item.children { add(c, path: path + "/" + c.rawKey, depth: depth + 1) }
            }
        }
        infoRowPaths = []
        for item in model.infoItems(target: t, configuration: configuration) { add(item, path: item.rawKey, depth: 0) }
        let title = model.infoSectionTitle(target: t, configuration: configuration)
        let openPlist = NSButton(title: "Open Info.plist", target: self, action: #selector(openInfoPlistInEditor))
        openPlist.bezelStyle = .rounded
        let plistPath = infoPlistFileURL(target: t)?.path ?? resolved("INFOPLIST_FILE", target: t)
        let pathLabel = NSTextField(labelWithString: plistPath.isEmpty ? "No Info.plist file — INFOPLIST_FILE is unset" : plistPath)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        let infoBar = NSStackView(views: [openPlist, pathLabel])
        infoBar.spacing = 8
        var views: [NSView] = [infoBar, section(title, table(title, columns: ["Key", "Type", "Value"], rows: rows, width: 640))]
        for (s, (title, key)) in zip(model.infoTypeSections(target: t, configuration: configuration), ProjectEditorModel.infoTypeKeys) {
            views.append(section(s, infoTypeSection(title: title, key: key, target: t)))
        }
        return page(views)
    }

    public func toggleInfoKey(_ path: String) {
        if expandedInfoKeys.contains(path) { expandedInfoKeys.remove(path) } else { expandedInfoKeys.insert(path) }
        if tab == .info { showTab() }
    }

    @objc func infoKeyDisclosureClicked(_ b: NSButton) { if let p = b.identifier?.rawValue { toggleInfoKey(p) } }

    var signingConfiguration: String { signingScope == "All" ? configuration : signingScope }

    public func setSigningScope(_ scope: String) {
        guard scope == "All" || model.configurations(of: selectedTarget).names.contains(scope) else { return }
        signingScope = scope
        if tab == .signing { showTab() }
    }

    @objc func signingScopeChosen(_ s: NSSegmentedControl) { setSigningScope(s.label(forSegment: s.selectedSegment) ?? "All") }

    func signingResolved(_ name: String, target t: String) -> String {
        model.resolve(target: t, configuration: signingConfiguration)?.settings[name] ?? ""
    }

    func signingView(_ t: String) -> NSView {
        let cfg = signingConfiguration
        let addCap = NSButton(title: "+ Capability", target: self, action: #selector(addCapabilityClicked))
        let scopes = ["All"] + model.configurations(of: t).names
        let scope = NSSegmentedControl(labels: scopes, trackingMode: .selectOne, target: self, action: #selector(signingScopeChosen(_:)))
        scope.selectedSegment = scopes.firstIndex(of: signingScope) ?? 0
        scope.identifier = .init("signingScope")
        let bar = NSStackView(views: [addCap, scope])

        let auto = NSButton(checkboxWithTitle: "Automatically manage signing", target: self, action: #selector(autoSigningToggled(_:)))
        auto.state = signingResolved("CODE_SIGN_STYLE", target: t) != "Manual" ? .on : .off
        let caption = NSTextField(labelWithString: ProjectEditorModel.automaticSigningCaption)
        caption.textColor = .secondaryLabelColor
        caption.font = .systemFont(ofSize: 11)
        let autoStack = NSStackView(views: [auto, caption])
        autoStack.orientation = .vertical
        autoStack.alignment = .leading

        let team = NSComboBox()
        team.addItems(withObjectValues: model.teams)
        team.stringValue = signingResolved("DEVELOPMENT_TEAM", target: t)
        team.placeholderString = "None"
        team.identifier = .init("DEVELOPMENT_TEAM")
        team.delegate = self
        team.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let bundleID = signingResolved("PRODUCT_BUNDLE_IDENTIFIER", target: t)
        let bundle = NSTextField(string: bundleID)
        bundle.identifier = .init("PRODUCT_BUNDLE_IDENTIFIER")
        bundle.delegate = self
        bundle.widthAnchor.constraint(equalToConstant: 280).isActive = true
        let isValidBundleID = !bundleID.isEmpty && bundleID.contains(".") && !bundleID.hasPrefix(".") && !bundleID.hasSuffix(".")
        let bundleBadge = NSTextField(labelWithString: isValidBundleID ? "✓ Valid reverse-DNS" : "⚠ Enter reverse-DNS (e.g. com.company.app)")
        bundleBadge.font = .systemFont(ofSize: 11)
        bundleBadge.textColor = isValidBundleID ? .systemGreen : .systemOrange
        let bundleStack = NSStackView(views: [bundle, bundleBadge])

        
        let profileSpecifier = signingResolved("PROVISIONING_PROFILE_SPECIFIER", target: t)
        let profilePop = NSPopUpButton(frame: .zero, pullsDown: false)
        profilePop.addItems(withTitles: ["Xcode Managed Profile", "Apple Development", "Apple Distribution", "Developer ID Application", "Custom Profile…"])
        if !profileSpecifier.isEmpty && !profilePop.itemTitles.contains(profileSpecifier) {
            profilePop.addItem(withTitle: profileSpecifier)
        }
        if !profileSpecifier.isEmpty { profilePop.selectItem(withTitle: profileSpecifier) }
        profilePop.target = self
        profilePop.action = #selector(profileChosen(_:))
        profilePop.identifier = .init("PROVISIONING_PROFILE_SPECIFIER")

        let isManaged = signingResolved("CODE_SIGN_STYLE", target: t) != "Manual"
        let statusBadge = NSTextField(labelWithString: isManaged ? "● Managed" : (profileSpecifier.isEmpty ? "○ Missing" : "● Valid"))
        statusBadge.font = .boldSystemFont(ofSize: 11)
        statusBadge.textColor = isManaged ? .systemGreen : (profileSpecifier.isEmpty ? .systemYellow : .systemGreen)
        let profileStack = NSStackView(views: [profilePop, statusBadge])

        
        let certPop = NSPopUpButton(frame: .zero, pullsDown: false)
        certPop.addItems(withTitles: ["Apple Development", "Apple Distribution", "Developer ID Application", "Sign to Run Locally (-)"])
        let currentCert = signingResolved("CODE_SIGN_IDENTITY", target: t)
        if !currentCert.isEmpty && !certPop.itemTitles.contains(currentCert) {
            certPop.addItem(withTitle: currentCert)
        }
        if !currentCert.isEmpty { certPop.selectItem(withTitle: currentCert) }
        certPop.target = self
        certPop.action = #selector(certificateChosen(_:))
        certPop.identifier = .init("CODE_SIGN_IDENTITY")

        
        let entField = settingField("CODE_SIGN_ENTITLEMENTS", target: t, placeholder: "\(t)/\(t).entitlements", width: 220)
        let browseEntBtn = NSButton(title: "Choose…", target: self, action: #selector(chooseEntitlementsFile))
        browseEntBtn.bezelStyle = .rounded
        let editEntBtn = NSButton(title: "Edit in Code Editor", target: self, action: #selector(openEntitlementsInEditor))
        editEntBtn.bezelStyle = .rounded
        let entRow = NSStackView(views: [entField, browseEntBtn, editEntBtn])

        var signingViews: [NSView] = [grid([
            ("", autoStack),
            ("Team", team),
            ("Bundle Identifier", bundleStack),
            ("Provisioning Profile", profileStack),
            ("Signing Certificate", certPop),
            ("Entitlements File", entRow)
        ])]

        for b in model.signingBoxes(target: t, configuration: cfg) {
            let box = NSBox()
            box.title = b.platform
            var rows: [(String, NSView)] = [("Provisioning Profile", NSTextField.cell(b.provisioningProfile)),
                                            ("Signing Certificate", NSTextField.cell(b.certificate))]
            if !b.status.isEmpty {
                let icon = NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")!)
                icon.contentTintColor = .systemYellow
                let text = NSTextField(wrappingLabelWithString: b.status.joined(separator: "\n"))
                text.preferredMaxLayoutWidth = 360
                rows.append(("Status", NSStackView(views: [icon, text])))
            }
            let g = grid(rows)
            g.translatesAutoresizingMaskIntoConstraints = false
            box.contentView?.addSubview(g)
            if let cv = box.contentView {
                NSLayoutConstraint.activate([g.topAnchor.constraint(equalTo: cv.topAnchor, constant: 8), g.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 8),
                                             g.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -8), g.trailingAnchor.constraint(lessThanOrEqualTo: cv.trailingAnchor, constant: -8)])
            }
            box.identifier = .init("signingBox:" + b.platform)
            signingViews.append(box)
        }
        let signingBody = NSStackView(views: signingViews)
        signingBody.orientation = .vertical
        signingBody.alignment = .leading
        var views: [NSView] = [bar, section("Signing", signingBody)]

        let caps = model.capabilities(target: t, configuration: cfg)
        if caps.isEmpty {
            let empty = NSTextField(labelWithString: ProjectEditorModel.emptyCapabilitiesText)
            empty.textColor = .secondaryLabelColor
            views.append(empty)
        }
        for c in caps {
            let body = capabilityDetailView(c, target: t, configuration: cfg)
            let remove = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete capability")!,
                                  target: self, action: #selector(removeCapabilityClicked(_:)))
            remove.isBordered = false
            remove.identifier = .init(c.rawValue)
            views.append(section(c.rawValue, body, accessory: [remove]))
        }
        
        let entEntries = model.entitlements(target: t, configuration: cfg)
        let entBody: NSView = entEntries.isEmpty
            ? NSTextField(labelWithString: "No entitlements file. Capabilities will create one automatically.")
            : grid(entEntries.prefix(20).map { ($0.key, NSTextField.cell($0.value.summary)) })
        views.append(section("Entitlements Summary", entBody))
        return page(views)
    }

    func capabilityDetailView(_ c: Capability, target t: String, configuration cfg: String) -> NSView {
        let entries = Dictionary(model.entitlements(target: t, configuration: cfg).map { ($0.key, $0.value) },
                                 uniquingKeysWith: { a, _ in a })
        var rows: [(String, NSView)] = c.settings.map { name in
            (name, NSTextField.cell(model.resolve(target: t, configuration: cfg)?.settings[name] ?? ""))
        }
        for key in c.entitlements {
            rows.append((key, NSTextField.cell(entries[key]?.summary ?? "Not set")))
        }
        if c == .backgroundModes {
            let modes = model.resolve(target: t, configuration: cfg)?.settings["INFOPLIST_KEY_UIBackgroundModes"] ?? ""
            rows.append(("INFOPLIST_KEY_UIBackgroundModes", NSTextField.cell(modes.isEmpty ? "Not set" : modes)))
        }
        if rows.isEmpty {
            let note = NSTextField(labelWithString: "This capability writes no entitlements or build settings.")
            note.textColor = .secondaryLabelColor
            note.font = .systemFont(ofSize: 11)
            return note
        }
        return grid(rows)
    }

    @discardableResult
    public func capabilityLibrary() -> CapabilityLibraryController {
        let t = selectedTarget
        let present = Set(t.map { model.capabilities(target: $0, configuration: signingConfiguration) } ?? [])
        let lib = CapabilityLibraryController(present: present, error: t.flatMap { model.capabilityLibraryError(target: $0, configuration: signingConfiguration) })
        lib.onAdd = { [weak self] c in
            do { try self?.addCapability(c); return nil } catch { return "\(error)" }
        }
        if let w = view.window, w.isVisible {
            let panel = NSPanel(contentViewController: lib)
            panel.title = ProjectEditorModel.capabilityLibraryTitle
            panel.styleMask = [.titled, .closable, .resizable, .utilityWindow]
            panel.isReleasedWhenClosed = false
            panel.setFrameAutosaveName("")
            w.beginSheet(panel)
        }
        return lib
    }

    func phasesView(_ t: String) -> NSView {
        let menu = NSPopUpButton(frame: .zero, pullsDown: true)
        menu.addItem(withTitle: "+")
        menu.autoenablesItems = false
        for m in model.addPhaseMenu(target: t) {
            let item = NSMenuItem(title: m.title, action: #selector(addPhaseChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = m.isa
            item.isEnabled = m.enabled
            menu.menu?.addItem(item)
            if m.separatorAfter { menu.menu?.addItem(.separator()) }
        }
        menu.identifier = .init("addPhaseMenu")
        let filter = NSSearchField()
        filter.placeholderString = "Filter"
        filter.widthAnchor.constraint(equalToConstant: 180).isActive = true
        var views: [NSView] = [NSStackView(views: [menu, filter])]
        let synced = model.synchronizedPhaseItems(target: t)
        for s in model.phaseSections(target: t) {
            let extra = s.title == "Compile Sources" ? synced.sources : s.title == "Copy Bundle Resources" ? synced.resources : []
            let names = extra + s.items.map(\.name)
            let body: NSView
            if let shell = s.shell {
                let script = NSTextField(wrappingLabelWithString: s.script ?? "")
                script.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
                script.preferredMaxLayoutWidth = 500
                let v = NSStackView(views: [NSTextField.cell("Shell: " + shell), script])
                v.orientation = .vertical
                v.alignment = .leading
                body = v
            } else {
                let columns = s.title == "Compile Sources" ? ["Name", "Compiler Flags"] : ["Name"]
                let rows = names.map { n -> [NSView] in columns.count == 2 ? [NSTextField.cell(n), NSTextField(string: "")] : [NSTextField.cell(n)] }
                let key = s.phaseID ?? s.title
                body = table(key, columns: columns, rows: rows, empty: "Add items here",
                             plus: s.phaseID == nil ? nil : #selector(phasePlusClicked(_:)), minus: s.phaseID == nil ? nil : #selector(phaseMinusClicked(_:)))
                if let pid = s.phaseID, let st = tables[key] {
                    st.identifier = pid
                    st.itemIDs = Array(repeating: "", count: extra.count) + s.items.map(\.id)
                }
            }
            var accessory: [NSView] = []
            if let pid = s.phaseID, ProjectEditorModel.phaseIsRemovable(s.title) {
                let trash = PhaseButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete phase")!, target: self,
                                        action: #selector(removePhaseClicked(_:)))
                trash.isBordered = false
                trash.value = pid
                accessory.append(trash)
            }
            views.append(section(ProjectEditorModel.phaseTitle(s.title, count: names.count), body, accessory: accessory))
        }
        return page(views)
    }

    @objc func addPhaseChosen(_ item: NSMenuItem) {
        if let isa = item.representedObject as? String { addBuildPhase(isa: isa) }
    }

    @objc func removePhaseClicked(_ b: PhaseButton) { removeBuildPhase(b.value) }

    func staticTable(of button: NSButton) -> StaticTable? {
        tables.values.first { $0.plusButton === button || $0.minusButton === button }
    }

    @objc func phasePlusClicked(_ b: NSButton) {
        guard let st = staticTable(of: b), let pid = st.identifier else { return }
        let pb = PhaseButton()
        pb.value = pid
        addPhaseItem(pb)
    }

    @objc func phaseMinusClicked(_ b: NSButton) {
        guard let st = staticTable(of: b), st.table.selectedRow >= 0, st.table.selectedRow < st.itemIDs.count else { return }
        let id = st.itemIDs[st.table.selectedRow]
        if !id.isEmpty { removeBuildFile(id) }
    }

    @discardableResult
    public func addBuildPhase(isa: String) -> String? {
        guard let t = selectedTarget, model.addPhaseMenu(target: t).contains(where: { $0.isa == isa && $0.enabled }) else { return nil }
        let id = model.addBuildPhase(isa: isa, target: t)
        onChange?(model.proj)
        if tab == .buildPhases { showTab() }
        return id
    }

    public func removeBuildPhase(_ id: String) {
        model.removeBuildPhase(id)
        onChange?(model.proj)
        if tab == .buildPhases { showTab() }
    }

    func buildSettingsView() -> NSView {
        let plus = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Add setting")!, target: nil, action: nil)
        plus.bezelStyle = .smallSquare
        let filterControl = NSSegmentedControl(labels: ProjectEditorModel.Filter.allCases.map(\.rawValue), trackingMode: .selectOne,
                                               target: self, action: #selector(filterChosen(_:)))
        filterControl.selectedSegment = ProjectEditorModel.Filter.allCases.firstIndex(of: filter) ?? 1
        let viewControl = NSSegmentedControl(labels: ["Combined", "Levels"], trackingMode: .selectOne, target: self, action: #selector(viewChosen(_:)))
        viewControl.selectedSegment = settingsView.rawValue
        let namesControl = NSSegmentedControl(labels: ["Names", "Titles"], trackingMode: .selectOne, target: self, action: #selector(namesChosen(_:)))
        namesControl.selectedSegment = showsTitles ? 1 : 0
        let defsControl = NSSegmentedControl(labels: ["Definitions", "Values"], trackingMode: .selectOne, target: self, action: #selector(definitionsChosen(_:)))
        defsControl.selectedSegment = showsDefinitions ? 0 : 1
        let searchField = NSSearchField()
        searchField.stringValue = search
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        searchField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        let bar = NSStackView(views: [plus, filterControl, viewControl, namesControl, defsControl, searchField])
        bar.spacing = 10
        settingsTable.tableColumns.forEach(settingsTable.removeTableColumn)
        settingsTable.dataSource = self
        settingsTable.delegate = self
        settingsTable.usesAlternatingRowBackgroundColors = true
        settingsTable.rowSizeStyle = .small
        let scroll = NSScrollView()
        scroll.documentView = settingsTable
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        let stack = NSStackView(views: [bar, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
        reloadSettings()
        return stack
    }

    @objc func namesChosen(_ s: NSSegmentedControl) { showsTitles = s.selectedSegment == 1 }
    @objc func definitionsChosen(_ s: NSSegmentedControl) { showsDefinitions = s.selectedSegment == 0 }

    public func displayName(_ name: String) -> String {
        showsTitles ? (ProjectEditorModel.settingTitles[name] ?? name) : name
    }

    func settingSections() -> [ProjectEditorModel.SettingSection] {
        let q = search.lowercased()
        func matches(_ n: String) -> Bool {
            q.isEmpty || n.lowercased().contains(q) || (ProjectEditorModel.settingTitles[n]?.lowercased().contains(q) ?? false)
        }
        if filter == .basic {
            return model.basicSettingSections(target: selectedTarget, configuration: configuration)
                .map { .init(title: $0.title, names: $0.names.filter(matches)) }.filter { !$0.names.isEmpty }
        }
        let names = model.settingRows(target: selectedTarget, configuration: configuration, filter: filter).map(\.name).filter(matches)
        var left = Set(names)
        var out: [ProjectEditorModel.SettingSection] = []
        for b in ProjectEditorModel.basicSections {
            let inSection = b.settings.map(\.name).filter(left.contains)
            if !inSection.isEmpty { out.append(.init(title: b.section, names: inSection)); left.subtract(inSection) }
        }
        if !left.isEmpty { out.append(.init(title: "User-Defined", names: left.sorted())) }
        return out
    }

    func reloadSettings() {
        guard isViewLoaded else { return }
        let sections = settingSections()
        let names = sections.flatMap(\.names)
        settingRows = model.settingRows(names: names, target: selectedTarget, configuration: configuration)
        rowByName = Dictionary(settingRows.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        perConfiguration = [:]
        configurationNames = model.configurations(of: selectedTarget).names
        if settingsView == .levels {
            for c in configurationNames {
                perConfiguration[c] = Dictionary(model.settingRows(names: names, target: selectedTarget, configuration: c).map { ($0.name, $0) },
                                                 uniquingKeysWith: { a, _ in a })
            }
        }
        settingsLines = []
        for s in sections {
            settingsLines.append(.section(s.title))
            guard !collapsedSettingSections.contains(s.title) else { continue }
            for n in s.names {
                settingsLines.append(.setting(n))
                if hasMultipleValues(n), expandedSettings.contains(n) {
                    settingsLines += configurationNames.map { .configuration(setting: n, name: $0) }
                }
            }
        }
        configureSettingColumns()
        settingsTable.reloadData()
    }

    public func hasMultipleValues(_ name: String) -> Bool {
        settingsView == .levels && Set(configurationNames.map { perConfiguration[$0]?[name]?.resolved ?? "" }).count > 1
    }

    func configureSettingColumns() {
        var cols: [(String, String, CGFloat)]
        if settingsView == .combined {
            cols = [("name", "Setting", 300), ("resolved", ProjectEditorModel.levelsColumnTitle(selectedTarget ?? model.projectName), 360)]
        } else {
            let titles = model.levelsColumnTitles(target: selectedTarget)
            cols = [("name", titles[0], 240), ("resolved", titles[1], 140)]
            let anyTargetXC = settingRows.contains { $0.targetXCConfig != nil }, anyProjectXC = settingRows.contains { $0.projectXCConfig != nil }
            if let t = selectedTarget {
                cols.append(("target", t, 120))
                if anyTargetXC { cols.append(("targetXCConfig", "Target xcconfig", 100)) }
            }
            cols.append(("project", model.projectName, 120))
            if anyProjectXC { cols.append(("projectXCConfig", "Project xcconfig", 100)) }
            cols.append(("defaults", titles.last ?? "Defaults", 120))
        }
        levelColumns = cols.map { ($0.0, $0.1) }
        guard settingsTable.tableColumns.map({ $0.identifier.rawValue }) != cols.map(\.0)
                || settingsTable.tableColumns.map(\.title) != cols.map(\.1) else { return }
        settingsTable.tableColumns.forEach(settingsTable.removeTableColumn)
        for (id, title, w) in cols {
            let c = NSTableColumn(identifier: .init(id))
            c.title = title
            c.width = w
            settingsTable.addTableColumn(c)
        }
    }

    public func settingIsBold(_ name: String) -> Bool {
        guard let r = rowByName[name] else { return false }
        return selectedTarget == nil ? (r.project != nil || r.projectXCConfig != nil) : (r.target != nil || r.targetXCConfig != nil)
    }

    public func settingsCellText(row: Int, column id: String) -> String? {
        switch settingsLines[row] {
        case .section(let t): return id == "name" ? t : nil
        case .setting(let n):
            guard let s = rowByName[n] else { return nil }
            if id == "name" { return displayName(n) }
            if hasMultipleValues(n) && (id == "resolved" || settingsView == .combined) { return ProjectEditorModel.multipleValues }
            return levelText(s, id)
        case .configuration(let n, let c):
            if id == "name" { return c }
            return perConfiguration[c]?[n].flatMap { levelText($0, id) }
        }
    }

    func levelText(_ s: ProjectEditorModel.SettingRow, _ id: String) -> String? {
        switch id {
        case "resolved":
            if showsDefinitions, let level = s.providingLevel { return levelText(s, level) }
            return s.resolved
        case "target": return s.target
        case "targetXCConfig": return s.targetXCConfig
        case "project": return s.project
        case "projectXCConfig": return s.projectXCConfig
        default: return s.defaults
        }
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === sidebar ? sidebarRowCount : settingsLines.count
    }

    public func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        if tableView === sidebar { return sidebarIsHeader(row) }
        if case .section = settingsLines[row] { return true }
        return false
    }

    public func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if tableView === sidebar { return !sidebarIsHeader(row) }
        if case .section = settingsLines[row] { return false }
        return true
    }

    public func tableViewSelectionDidChange(_ n: Notification) {
        guard (n.object as? NSTableView) === sidebar, sidebar.selectedRow >= 0 else { return }
        sidebarSelected(sidebar.selectedRow)
    }

    public func tableView(_ tableView: NSTableView, viewFor c: NSTableColumn?, row: Int) -> NSView? {
        if tableView === sidebar { return sidebarCell(row) }
        switch settingsLines[row] {
        case .section(let title):
            let d = SettingDisclosure(title: "", target: self, action: #selector(settingSectionToggled(_:)))
            d.bezelStyle = .disclosure
            d.setButtonType(.pushOnPushOff)
            d.state = collapsedSettingSections.contains(title) ? .off : .on
            d.value = title
            let l = NSTextField(labelWithString: title)
            l.font = .boldSystemFont(ofSize: 11)
            return NSStackView(views: [d, l])
        case .setting(let n):
            guard let s = rowByName[n] else { return nil }
            let id = c?.identifier.rawValue ?? ""
            let text = settingsCellText(row: row, column: id)
            let multiple = hasMultipleValues(n)
            let editable = !multiple && ((settingsView == .combined && id == "resolved") || (id == (selectedTarget == nil ? "project" : "target")))
            let f = cellField(text, editable: editable, identifier: n, id: id)
            let bold = settingIsBold(n)
            if bold && (id == "name" || id == "resolved") { f.font = .boldSystemFont(ofSize: 11) }
            if settingsView == .levels, id == s.providingLevel, !multiple { outline(f) }
            if id == "name", multiple {
                let d = SettingDisclosure(title: "", target: self, action: #selector(settingExpansionToggled(_:)))
                d.bezelStyle = .disclosure
                d.setButtonType(.pushOnPushOff)
                d.state = expandedSettings.contains(n) ? .on : .off
                d.value = n
                return NSStackView(views: [d, f])
            }
            return f
        case .configuration(let n, let cfg):
            let id = c?.identifier.rawValue ?? ""
            let editable = id == (selectedTarget == nil ? "project" : "target")
            let f = cellField(settingsCellText(row: row, column: id), editable: editable, identifier: "cfg:\(cfg):\(n)", id: id)
            if id == "name" { f.stringValue = "      " + cfg }
            if id == perConfiguration[cfg]?[n]?.providingLevel { outline(f) }
            return f
        }
    }

    func cellField(_ text: String?, editable: Bool, identifier: String, id: String) -> NSTextField {
        let f = editable ? NSTextField(string: text ?? "") : NSTextField(labelWithString: text ?? "")
        f.font = id == "name" ? .systemFont(ofSize: 11) : Theme.font
        f.lineBreakMode = .byTruncatingMiddle
        f.cell?.truncatesLastVisibleLine = true
        f.toolTip = (text?.isEmpty ?? true) ? nil : text
        if editable {
            f.isBordered = false
            f.drawsBackground = false
            f.identifier = .init(identifier)
            f.delegate = self
        }
        return f
    }

    func outline(_ f: NSTextField) {
        f.wantsLayer = true
        f.layer?.borderWidth = 1
        f.layer?.borderColor = Theme.accentColor.cgColor
        f.layer?.cornerRadius = 3
        f.identifier = f.identifier ?? .init("providing")
        f.setAccessibilityHelp("Supplies the resolved value")
    }

    final class SettingDisclosure: NSButton { var value = "" }

    @objc func settingSectionToggled(_ b: SettingDisclosure) {
        if collapsedSettingSections.contains(b.value) { collapsedSettingSections.remove(b.value) } else { collapsedSettingSections.insert(b.value) }
    }

    @objc func settingExpansionToggled(_ b: SettingDisclosure) {
        if expandedSettings.contains(b.value) { expandedSettings.remove(b.value) } else { expandedSettings.insert(b.value) }
    }
}
