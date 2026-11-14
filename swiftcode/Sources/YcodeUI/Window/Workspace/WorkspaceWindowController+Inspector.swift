import AppKit
import YcodeIDECore
import YcodeProject
import YcodeSyntax

extension WorkspaceWindowController {
    func wireInspector() {
        inspector.fileInfo = { [weak self] url in self?.fileInspectorInfo(url) ?? FileInspectorInfo() }
        inspector.symbolsProvider = { [weak self] url in self?.fileSymbols(url) ?? [] }
        inspector.onSelectSymbol = { [weak self] url, line in self?.open(path: url.path, line: line) }
        inspector.onSetMembership = { [weak self] url, target, member in self?.setTargetMembership(of: url, target: target, member: member) }
        inspector.historyProvider = { [weak self] url in
            guard let self, Preferences.shared.sourceControlEnabled, let repo = self.repository else { return [] }
            return await Task.detached { repo.history(ofFile: url.path) }.value
        }
        inspector.onSelectHistoryCommit = { [weak self] url, commit in self?.showHistoryCommit(commit, of: url) }
        inspector.onSearchDocumentation = { [weak self] in self?.searchDocumentationForSelection(nil) }
    }

    
    
    
    func fileSymbols(_ url: URL) -> [SymbolScanner.Symbol] {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber, size.int64Value <= 1_048_576,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let language = SyntaxLanguage(fileName: url.lastPathComponent)
        guard language.isCode else { return [] }
        return SymbolScanner.symbols(in: text, language: language)
    }

    public func fileInspectorInfo(_ url: URL) -> FileInspectorInfo {
        var info = FileInspectorInfo()
        let path = url.standardizedFileURL.path
        if Preferences.shared.sourceControlEnabled, let repo = repository {
            let root = repo.root.standardizedFileURL.path
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
            for p in [path, resolved] where p.hasPrefix(root + "/") {
                info.workingCopy = root
                info.relativePath = String(p.dropFirst(root.count + 1))
                break
            }
            info.gitStatus = sourceControlFileStatus(for: path) ?? sourceControlFileStatus(for: resolved)
        }
        switch session.model.kind {
        case .package:
            let base = session.model.url.standardizedFileURL.path
            info.isPackageFile = path.hasPrefix(base + "/")
            for dir in ["Sources", "Tests"] where path.hasPrefix(base + "/\(dir)/") {
                let parts = path.dropFirst(base.count + dir.count + 2).split(separator: "/")
                if parts.count >= 2 {
                    info.memberships = [TargetMembership(targetID: String(parts[0]), name: String(parts[0]), isMember: true, isEditable: false)]
                }
            }
        default:
            if let (projPath, proj) = project(holding: path) {
                info.memberships = proj.memberships
                let dir = proj.project.projectDirectory(xcodeprojURL: URL(fileURLWithPath: projPath))
                if case .synchronized? = proj.project.place(ofFile: path, projectDirectory: dir) { info.inSynchronizedFolder = true }
                if let member = proj.memberships.first(where: \.isMember),
                   let settings = targetBuildSettings(proj: proj.project, targetID: member.targetID) {
                    info.buildSettingsTarget = settings.name
                    info.buildConfigurations = settings.configurations
                    info.buildSettings = settings.settings
                    info.activeBuildConfiguration = session.launchConfiguration
                }
            }
        }
        return info
    }

    
    
    
    func sourceControlFileStatus(for path: String) -> GitRepository.FileStatus? {
        if let s = sourceControl.lastStatus[path] { return s }
        return sourceControl.snapshot.changes.first { $0.path == path }?.status
    }

    
    
    
    func targetBuildSettings(proj: PBXProj, targetID: String) -> (name: String, configurations: [String], settings: [String: [String: String]])? {
        guard let target = proj[targetID] else { return nil }
        let name = target.string("name") ?? targetID
        let listID = target.string("buildConfigurationList") ?? ""
        guard let list = proj.objects(isa: "XCConfigurationList").first(where: { $0.id == listID }) else { return nil }
        let configs = proj.objects(isa: "XCBuildConfiguration")
        var configurations: [String] = []
        var settings: [String: [String: String]] = [:]
        for configID in list.references("buildConfigurations") {
            guard let config = configs.first(where: { $0.id == configID }),
                  let configName = config.string("name"), !configName.isEmpty else { continue }
            var flat: [String: String] = [:]
            if let buildSettings = config.attributes["buildSettings"]?.dictionary {
                for (key, value) in buildSettings where FileInspectorInfo.buildSettingKeys.contains(key) {
                    if let s = value.string { flat[key] = s }
                }
            }
            configurations.append(configName)
            settings[configName] = flat
        }
        guard !configurations.isEmpty else { return nil }
        return (name, configurations, settings)
    }

    func project(holding path: String) -> (String, (project: PBXProj, memberships: [TargetMembership]))? {
        for (projPath, proj) in session.model.projects.sorted(by: { $0.key < $1.key }) {
            let dir = proj.projectDirectory(xcodeprojURL: URL(fileURLWithPath: projPath))
            guard proj.place(ofFile: path, projectDirectory: dir) != nil else { continue }
            return (projPath, (proj, proj.targetMemberships(ofFile: path, projectDirectory: dir)))
        }
        return nil
    }

    @discardableResult
    public func setTargetMembership(of url: URL, target: String, member: Bool) -> Bool {
        let path = url.standardizedFileURL.path
        guard let (projPath, found) = project(holding: path) else { NSSound.beep(); return false }
        var proj = found.project
        let dir = proj.projectDirectory(xcodeprojURL: URL(fileURLWithPath: projPath))
        guard proj.setMembership(ofFile: path, target: target, member: member, projectDirectory: dir) else { NSSound.beep(); return false }
        projectChanged(path: projPath, proj)
        inspector.refresh()
        return true
    }

    public func showHistoryCommit(_ commit: GitRepository.Commit, of url: URL) {
        if editor.fileURL?.standardizedFileURL != url.standardizedFileURL { open(path: url.path, line: nil) }
        endEditorModes(except: .codeReview)
        editor.setReviewSource(.commit(hash: commit.hash, title: "\(commit.shortHash) \(commit.subject)"), left: false)
        endCodeReview()
        startCodeReview()
        updateToolbarState()
    }
}
