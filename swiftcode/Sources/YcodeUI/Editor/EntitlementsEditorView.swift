import AppKit
import Foundation
import SwiftUI
import YcodeIDECore
import YcodeIDEShell
import YcodeSigning

struct EntitlementsEditorView: View {
    private enum DisplayMode: String, CaseIterable, Identifiable {
        case enabled = "Enabled"
        case catalog = "All Capabilities"
        case xml = "Raw XML"
        var id: String { rawValue }
    }

    @Bindable var model: EntitlementsEditorModel
    var defaultCreateURL: URL?
    var onFileCreated: ((URL) -> Void)?

    @Environment(\.colorScheme) private var scheme
    @Environment(WorkspaceViewModel.self) private var workspaceViewModel: WorkspaceViewModel?
    @State private var mode: DisplayMode = .enabled
    @State private var status: String?
    @State private var customKey = ""
    @State private var customKeyType = "Boolean"
    @State private var rawText = ""
    @State private var showingAddSheet = false
    @State private var showingInspectorSheet = false
    @State private var addSheetSearch = ""
    @State private var addSheetSection: EntitlementCapabilitySection = .all
    @State private var addSheetCustomKey = ""
    @State private var addSheetCustomKeyType = "boolean"
    @FocusState private var addSearchFocused: Bool

    private static let starterKeys = [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "aps-environment",
        "com.apple.developer.applesignin",
        "com.apple.developer.icloud-services",
        "com.apple.security.application-groups",
        "com.apple.developer.associated-domains",
        "keychain-access-groups",
    ]

    init(model: EntitlementsEditorModel, defaultCreateURL: URL? = nil, onFileCreated: ((URL) -> Void)? = nil) {
        self._model = Bindable(wrappedValue: model)
        self.defaultCreateURL = defaultCreateURL
        self.onFileCreated = onFileCreated
    }

    init(fileURL: URL?, defaultCreateURL: URL? = nil, onFileCreated: ((URL) -> Void)? = nil) {
        let m = (try? EntitlementsEditorModel(url: fileURL)) ?? EntitlementsEditorModel(entitlements: [:])
        self._model = Bindable(wrappedValue: m)
        self.defaultCreateURL = defaultCreateURL
        self.onFileCreated = onFileCreated
    }

    private var enabledDefinitions: [CapabilityDefinition] {
        EntitlementCapabilityCatalog.definitions.filter { model.isCapabilityOn($0) && model.capabilityMatchesSearch($0) }
    }

    private var totalEnabledCount: Int {
        EntitlementCapabilityCatalog.definitions.filter { model.isCapabilityOn($0) }.count + model.uncoveredKeys.count
    }

    var body: some View {
        let c = ShellColors(scheme)
        VStack(spacing: 0) {
            toolbar(c)
            Hairline(color: c.separator)
            if let p = model.problem { ProblemBanner(message: p) { model.clearProblem() } }
            if model.url == nil { unconfiguredBanner(c) }
            switch mode {
            case .enabled:
                enabledWorkspace(c)
            case .catalog:
                catalogWorkspace(c)
            case .xml:
                rawXMLWorkspace(c)
            }
        }
        .background(c.content)
        .shellTarget("entitlements editor")
        .sheet(isPresented: $showingAddSheet) {
            addCapabilitySheet
        }
        .sheet(isPresented: $showingInspectorSheet) {
            inspectorSheetView
        }
        .onChange(of: mode) { _, next in
            if next == .xml { rawText = model.xmlText() }
        }
    }

    private func persistChange(_ message: String? = nil) {
        if model.url == nil {
            let candidate = defaultCreateURL ?? ProjectSessionStore.shared.activeProject.map {
                EntitlementsFileTemplate.defaultURL(in: $0.directoryURL, projectName: $0.name)
            }
            if let candidate {
                do {
                    try model.bindAndSave(to: candidate)
                    onFileCreated?(candidate)
                    status = message ?? "Created \(candidate.lastPathComponent)"
                } catch {
                    model.setProblem("Could not create entitlements file: \(error.localizedDescription)")
                }
                return
            }
        }
        if model.url != nil {
            do {
                try model.save()
                if let message { status = message }
            } catch {
                model.setProblem("Could not save entitlements: \(error.localizedDescription)")
            }
        } else if let message {
            status = message
        }
    }

    private func toggleCapability(_ def: CapabilityDefinition, on: Bool) {
        model.setCapability(def, on: on)
        persistChange(on ? "Enabled \(def.name)" : "Removed \(def.name)")
    }

    private func unconfiguredBanner(_ c: ShellColors) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.teal)
            Text(defaultCreateURL.map { "Toggle any capability below to create \($0.lastPathComponent) automatically." }
                 ?? "Toggle capabilities below to configure entitlements, then save to a .entitlements file.")
                .font(.callout)
                .foregroundStyle(c.secondaryLabel)
            Spacer()
            Button(defaultCreateURL != nil ? "Create File Now" : "Save As…") {
                createOrSaveAs()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.teal.opacity(0.08))
    }

    private func createOrSaveAs() {
        if let targetURL = defaultCreateURL ?? ProjectSessionStore.shared.activeProject.map({
            EntitlementsFileTemplate.defaultURL(in: $0.directoryURL, projectName: $0.name)
        }) {
            do {
                try model.bindAndSave(to: targetURL)
                onFileCreated?(targetURL)
                status = "Created \(targetURL.lastPathComponent)"
                if let project = ProjectSessionStore.shared.activeProject {
                    ProjectSessionStore.shared.refreshFileTree(for: project)
                    Task {
                        await workspaceViewModel?.editor.updateActiveConfigurationURLs(for: project)
                    }
                }
            } catch {
                model.setProblem("Failed to create entitlements: \(error.localizedDescription)")
            }
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "App.entitlements"
        if panel.runModal() == .OK, let u = panel.url {
            do {
                try model.bindAndSave(to: u)
                onFileCreated?(u)
                status = "Saved \(u.lastPathComponent)"
            } catch {
                model.setProblem("Failed to save entitlements: \(error.localizedDescription)")
            }
        }
    }

    private func toolbar(_ c: ShellColors) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(c.secondaryLabel)
                TextField("Filter capabilities or keys…", text: $model.searchText)
                    .textFieldStyle(.plain)
                if !model.searchText.isEmpty {
                    Button { model.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(c.secondaryLabel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(c.content, in: RoundedRectangle(cornerRadius: 7))
            .frame(width: 230)

            Picker("", selection: $mode) {
                Text("Enabled (\(totalEnabledCount))").tag(DisplayMode.enabled)
                Text("All (\(EntitlementCapabilityCatalog.definitions.count))").tag(DisplayMode.catalog)
                Text("XML").tag(DisplayMode.xml)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 250)

            Spacer()

            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(c.secondaryLabel)
                    .lineLimit(1)
            } else if let url = model.url {
                HStack(spacing: 4) {
                    Circle()
                        .fill(model.isDirty ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(c.secondaryLabel)
                }
            }

            Menu {
                Section("Quick Presets") {
                    ForEach(EntitlementsPreset.allCases, id: \.rawValue) { preset in
                        Button(preset.rawValue) {
                            model.applyPreset(preset)
                            persistChange("Applied \(preset.rawValue)")
                        }
                    }
                }
                Divider()
                Button("Copy Raw XML") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.xmlText(), forType: .string)
                    status = "Copied XML"
                }
                if let url = model.url {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    Button("Revert from Disk") {
                        try? model.revert()
                        status = "Reverted"
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 26)

            Button {
                showingAddSheet = true
            } label: {
                Label("Capability", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(c.sidebar)
    }

    private func enabledWorkspace(_ c: ShellColors) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                validationPanel(c)

                if totalEnabledCount == 0 && model.searchText.isEmpty {
                    quickStarterGrid(c)
                } else {
                    let active = enabledDefinitions
                    if active.isEmpty && model.uncoveredKeys.isEmpty {
                        ContentUnavailableView(
                            "No Matching Capabilities",
                            systemImage: "magnifyingglass",
                            description: Text("Try searching All Capabilities or click + Capability.")
                        )
                        .padding(.vertical, 32)
                    } else {
                        ForEach(active) { def in
                            capabilityCard(def, c)
                        }
                    }

                    if !model.uncoveredKeys.isEmpty {
                        uncoveredKeysSection(c)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func quickStarterGrid(_ c: ShellColors) -> some View {
        let starters = Self.starterKeys.compactMap { EntitlementCapabilityCatalog.definition(for: $0) }
            + EntitlementCapabilityCatalog.definitions.prefix(8).filter { d in !Self.starterKeys.contains(d.rawKey) }
        let items = Array(starters.prefix(8))
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Get Straight Into Capabilities")
                    .font(.title3.weight(.semibold))
                Text("Turn on common capabilities in one click, or browse all \(EntitlementCapabilityCatalog.definitions.count) entitlements.")
                    .font(.callout)
                    .foregroundStyle(c.secondaryLabel)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(items) { def in
                    Button {
                        toggleCapability(def, on: true)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.12))
                                Image(systemName: def.symbol)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(def.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(def.explanation)
                                    .font(.caption)
                                    .foregroundStyle(c.secondaryLabel)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(11)
                        .background(c.sidebar, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.separator.opacity(0.6), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Search & Add Capabilities…", systemImage: "magnifyingglass")
                }
                .buttonStyle(.bordered)

                ForEach(EntitlementsPreset.allCases, id: \.rawValue) { preset in
                    Button(preset.rawValue) {
                        model.applyPreset(preset)
                        persistChange("Applied \(preset.rawValue)")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.top, 2)
        }
    }

    private func catalogWorkspace(_ c: ShellColors) -> some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(EntitlementCapabilitySection.allCases.filter { $0 != .other }) { sec in
                        let selected = model.selectedSection == sec
                        Button {
                            model.selectedSection = sec
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: sec.icon)
                                    .font(.caption2)
                                Text(sec.rawValue)
                                    .font(.caption.weight(selected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(selected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            Hairline(color: c.separator)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(model.visibleSections) { section in
                        let defs = EntitlementCapabilityCatalog.definitions(in: section)
                            .filter { model.capabilityMatchesSearch($0) }
                        if !defs.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.fullTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(c.secondaryLabel)
                                    .padding(.top, 4)
                                VStack(spacing: 1) {
                                    ForEach(defs) { def in
                                        compactCapabilityRow(def, c)
                                    }
                                }
                                .background(c.sidebar, in: RoundedRectangle(cornerRadius: 10))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
    }

    private func compactCapabilityRow(_ def: CapabilityDefinition, _ c: ShellColors) -> some View {
        let isOn = model.isCapabilityOn(def)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: def.symbol)
                    .frame(width: 20)
                    .foregroundStyle(isOn ? Color.accentColor : c.secondaryLabel)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(def.name)
                            .font(.body.weight(.medium))
                        if def.requiresSpecialApproval {
                            Text("Approval")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(def.explanation)
                        .font(.caption)
                        .foregroundStyle(c.secondaryLabel)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    model.selectedKey = def.rawKey
                    showingInspectorSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(c.secondaryLabel)
                }
                .buttonStyle(.plain)
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { toggleCapability(def, on: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
            if isOn {
                capabilityPayloadEditor(def, c)
                    .padding(.leading, 30)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func validationPanel(_ c: ShellColors) -> some View {
        let issues = model.validate()
        return Group {
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(issues.count) Validation Issue\(issues.count == 1 ? "" : "s")")
                            .font(.subheadline.weight(.semibold))
                    }
                    ForEach(issues) { issue in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle()
                                .fill(issue.severity == .error ? c.error : c.warning)
                                .frame(width: 6, height: 6)
                            Text(issue.message)
                                .font(.caption)
                            Spacer()
                            Text(issue.rawKey)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(c.secondaryLabel)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func capabilityCard(_ def: CapabilityDefinition, _ c: ShellColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor.opacity(0.12))
                    Image(systemName: def.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(def.name).font(.subheadline.weight(.semibold))
                        if def.requiresSpecialApproval {
                            Text("Special approval")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.14), in: Capsule())
                                .foregroundStyle(c.warning)
                        }
                    }
                    Text(def.rawKey)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(c.secondaryLabel)
                }
                Spacer()
                Button {
                    model.selectedKey = def.rawKey
                    showingInspectorSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(c.secondaryLabel)
                }
                .buttonStyle(.plain)
                .help(def.explanation)

                Toggle("", isOn: Binding(
                    get: { model.isCapabilityOn(def) },
                    set: { toggleCapability(def, on: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
            if case .none = def.payload {
                Text(def.explanation)
                    .font(.caption)
                    .foregroundStyle(c.secondaryLabel)
            } else if model.isCapabilityOn(def) {
                capabilityPayloadEditor(def, c)
            }
        }
        .padding(13)
        .background(c.sidebar, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.separator.opacity(0.5), lineWidth: 0.5))
    }

    @ViewBuilder
    private func capabilityPayloadEditor(_ def: CapabilityDefinition, _ c: ShellColors) -> some View {
        switch def.payload {
        case .none:
            EmptyView()
        case .idList(let placeholder):
            IDListEditor(ids: Binding(
                get: { model.stringArray(forKey: def.rawKey) },
                set: { model.setStringArray($0, forKey: def.rawKey); persistChange() }
            ), placeholder: placeholder)
        case .fixedValueList(let allowed):
            FixedValueListEditor(values: Binding(
                get: { model.stringArray(forKey: def.rawKey) },
                set: { model.setStringArray($0, forKey: def.rawKey); persistChange() }
            ), allowed: allowed)
        case .choice(let options):
            Picker("Environment", selection: Binding(
                get: { model.string(forKey: def.rawKey, fallback: options.first ?? "") },
                set: { model.setString($0, forKey: def.rawKey); persistChange() }
            )) {
                ForEach(options, id: \.self) { option in Text(option).tag(option) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        case .stringValue(let placeholder):
            TextField(placeholder, text: Binding(
                get: { model.string(forKey: def.rawKey, fallback: "") },
                set: { model.setString($0, forKey: def.rawKey); persistChange() }
            ))
            .textFieldStyle(.roundedBorder)
        case .prefixedList(let prefixes, let placeholder):
            AssociatedDomainsEditor(domains: Binding(
                get: { model.stringArray(forKey: def.rawKey) },
                set: { model.setStringArray($0, forKey: def.rawKey); persistChange() }
            ), prefixes: prefixes, placeholder: placeholder)
        case .iCloudComposite:
            ICloudCompositeEditor(model: model)
        }
    }

    private func uncoveredKeysSection(_ c: ShellColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Entitlement Keys")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(c.secondaryLabel)
            ForEach(model.uncoveredKeys, id: \.self) { key in
                EntitlementRowView(
                    key: key,
                    value: model.entitlements[key]?.propertyList ?? "",
                    onSelect: {
                        model.selectedKey = key
                        showingInspectorSheet = true
                    },
                    onDuplicate: {
                        let val = model.entitlements[key]
                        var copyKey = "\(key).copy"
                        var n = 2
                        while model.entitlements[copyKey] != nil {
                            copyKey = "\(key).copy\(n)"
                            n += 1
                        }
                        model.set(val, forKey: copyKey)
                        persistChange("Duplicated to \(copyKey)")
                    },
                    onDelete: {
                        model.set(nil, forKey: key)
                        if model.selectedKey == key { model.selectedKey = nil }
                        persistChange("Removed \(key)")
                    },
                    onValueChange: { newVal in
                        guard let converted = EntitlementValue(propertyList: newVal) else { return }
                        model.set(converted, forKey: key)
                        persistChange()
                    }
                )
                .background(c.sidebar, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func rawXMLWorkspace(_ c: ShellColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Entitlements Property List XML")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(c.secondaryLabel)
                Spacer()
                Button("Copy XML") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(rawText, forType: .string)
                    status = "Copied XML"
                }
                .controlSize(.small)
                Button("Format & Reload") { rawText = model.xmlText() }
                    .controlSize(.small)
                Button("Apply Changes") {
                    do {
                        try model.setXMLText(rawText)
                        persistChange("Applied XML")
                    } catch {
                        model.setProblem("Invalid entitlements XML: \(error.localizedDescription)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            TextEditor(text: $rawText)
                .font(.system(.callout, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(c.sidebar, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(c.separator, lineWidth: 0.5))
        }
        .padding(16)
    }

    private var addCapabilitySheet: some View {
        let query = addSheetSearch.trimmingCharacters(in: .whitespaces)
        let matching = EntitlementCapabilityCatalog.definitions.filter { def in
            if addSheetSection != .all && query.isEmpty && def.section != addSheetSection {
                return false
            }
            guard !query.isEmpty else { return true }
            let q = query.lowercased()
            return def.name.lowercased().contains(q) || def.rawKey.lowercased().contains(q) || def.explanation.lowercased().contains(q)
        }
        let sortedMatching = matching.sorted { a, b in
            let aStarter = Self.starterKeys.contains(a.rawKey)
            let bStarter = Self.starterKeys.contains(b.rawKey)
            if aStarter != bStarter && query.isEmpty && addSheetSection == .all { return aStarter }
            return a.name < b.name
        }
        let canAddCustom = !query.isEmpty && query.contains(".") && model.entitlements[query] == nil
            && !EntitlementCapabilityCatalog.definitions.contains(where: { $0.rawKey == query })

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search capabilities or type a custom key (com.example.feature)…", text: $addSheetSearch)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($addSearchFocused)
                if !addSheetSearch.isEmpty {
                    Button { addSheetSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button("Done") {
                    showingAddSheet = false
                    addSheetSearch = ""
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(EntitlementCapabilitySection.allCases.filter { $0 != .other }) { cat in
                        let isSelected = addSheetSection == cat && query.isEmpty
                        Button {
                            addSheetSection = cat
                            addSheetSearch = ""
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.caption2)
                                Text(cat.rawValue)
                                    .font(.caption.weight(isSelected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if canAddCustom {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Add custom key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(query)
                            .font(.system(.callout, design: .monospaced).weight(.semibold))
                    }
                    Spacer()
                    Picker("", selection: $addSheetCustomKeyType) {
                        Text("Boolean").tag("boolean")
                        Text("String").tag("string")
                        Text("Array").tag("array")
                    }
                    .labelsHidden()
                    .frame(width: 96)
                    Button("Add Custom") {
                        switch addSheetCustomKeyType {
                        case "string": model.setString("", forKey: query)
                        case "array": model.setStringArray([], forKey: query)
                        default: model.setBool(true, forKey: query)
                        }
                        persistChange("Added \(query)")
                        addSheetSearch = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            List(sortedMatching) { def in
                let isOn = model.isCapabilityOn(def)
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill((isOn ? Color.accentColor : Color.secondary).opacity(0.12))
                        Image(systemName: def.symbol)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isOn ? Color.accentColor : .secondary)
                    }
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(def.name)
                                .font(.body.weight(.medium))
                            if def.requiresSpecialApproval {
                                Text("Approval")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Text(def.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(def.rawKey)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { isOn },
                        set: { toggleCapability(def, on: $0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                }
                .padding(.vertical, 3)
            }
            .listStyle(.inset)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .frame(width: 620, height: 520)
        .onAppear { addSearchFocused = true }
    }

    private var inspectorSheetView: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Capability Details", systemImage: "lock.shield")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    showingInspectorSheet = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if let key = model.selectedKey {
                let meta = EntitlementsCatalog.all.first(where: { $0.rawKey == key })
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meta?.displayName ?? key)
                                .font(.title3.bold())
                            Text(key)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        if let desc = meta?.entitlementDescription, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        if let meta {
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                inspectorDetailRow(label: "Category", value: meta.category.rawValue)
                                inspectorDetailRow(
                                    label: "Platforms",
                                    value: meta.supportedPlatforms.map(\.rawValue).joined(separator: ", ")
                                )
                                inspectorDetailRow(label: "Minimum OS", value: meta.minimumOS)
                                inspectorDetailRow(label: "Value Type", value: meta.valueType.rawValue)
                                if !meta.validationRules.isEmpty {
                                    inspectorDetailRow(label: "Validation", value: meta.validationRules)
                                }
                                if !meta.recommendedUsage.isEmpty {
                                    inspectorDetailRow(label: "Recommended Usage", value: meta.recommendedUsage)
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Configured Value:")
                                .font(.subheadline.bold())
                            Text(model.entitlements[key].map(entitlementSummary) ?? "(not set)")
                                .font(.system(.body, design: .monospaced))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView("No Capability Selected", systemImage: "lock.shield")
            }
        }
        .frame(width: 480, height: 440)
    }

    private func inspectorDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.callout)
            Spacer()
        }
    }
}

private struct IDListEditor: View {
    @Binding var ids: [String]
    let placeholder: String
    @State private var newID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(ids, id: \.self) { id in
                HStack {
                    Text(id)
                    Spacer()
                    Button("Remove") { ids.removeAll { $0 == id } }
                }
            }
            HStack {
                TextField(placeholder, text: $newID)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addID() }
                Button("Add") { addID() }
                    .disabled(newID.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addID() {
        let value = newID.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, !ids.contains(value) else { return }
        ids.append(value)
        newID = ""
    }
}

private struct FixedValueListEditor: View {
    @Binding var values: [String]
    let allowed: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(allowed, id: \.self) { option in
                Toggle(option, isOn: Binding(
                    get: { values.contains(option) },
                    set: { on in
                        if on, !values.contains(option) { values.append(option) }
                        if !on { values.removeAll { $0 == option } }
                    }
                ))
            }
        }
    }
}

private struct AssociatedDomainsEditor: View {
    @Binding var domains: [String]
    let prefixes: [String]
    let placeholder: String
    @State private var selectedPrefix = 0
    @State private var host = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(domains, id: \.self) { domain in
                HStack {
                    Text(domain)
                    Spacer()
                    Button("Remove") { domains.removeAll { $0 == domain } }
                }
            }
            HStack {
                Picker("Prefix", selection: $selectedPrefix) {
                    ForEach(prefixes.indices, id: \.self) { i in Text(prefixes[i]).tag(i) }
                }
                .frame(width: 190)
                TextField(placeholder, text: $host)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addDomain() }
                Button("Add") { addDomain() }
                    .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addDomain() {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        let domain = prefixes[selectedPrefix] + host
        guard !domains.contains(domain) else { return }
        domains.append(domain)
        self.host = ""
    }
}

private struct ICloudCompositeEditor: View {
    @Bindable var model: EntitlementsEditorModel
    @State private var newContainer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Container Identifiers").font(.subheadline)
            IDListEditor(ids: Binding(
                get: { model.iCloudContainers() },
                set: { model.setICloudContainers($0) }
            ), placeholder: "iCloud.$(CFBundleIdentifier)")
            HStack {
                Text("Key-Value Store")
                TextField("$(TeamIdentifierPrefix)$(CFBundleIdentifier)", text: Binding(
                    get: { model.iCloudKVStore() },
                    set: { model.setICloudKVStore($0) }
                ))
                .textFieldStyle(.roundedBorder)
            }
            Text("Ubiquitous Containers").font(.subheadline)
            ForEach(model.ubiquitousContainers(), id: \.id) { container in
                HStack {
                    Text(container.id)
                    Spacer()
                    TextField("Name", text: Binding(
                        get: { container.name },
                        set: { model.setUbiquitousContainer(id: container.id, name: $0, isPublic: container.isPublic, folderLevels: container.folderLevels) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    Toggle("Public", isOn: Binding(
                        get: { container.isPublic },
                        set: { model.setUbiquitousContainer(id: container.id, name: container.name, isPublic: $0, folderLevels: container.folderLevels) }
                    ))
                    Button("Remove") { model.removeUbiquitousContainer(id: container.id) }
                }
            }
            HStack {
                TextField("New container identifier", text: $newContainer)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addContainer() }
                Button("Add Container") { addContainer() }
                    .disabled(newContainer.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addContainer() {
        let id = newContainer.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        model.setUbiquitousContainer(id: id, name: id, isPublic: false, folderLevels: "")
        newContainer = ""
    }
}

struct EntitlementIDListEditor: View {
    @Binding var ids: [String]
    let placeholder: String
    @State private var newID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if ids.isEmpty {
                Text("No identifiers yet. Add one below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(ids, id: \.self) { id in
                HStack {
                    Image(systemName: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(id)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button {
                        ids.removeAll { $0 == id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove identifier")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            }
            HStack {
                TextField(placeholder, text: $newID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addID() }
                Button("Add") { addID() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(addDisabled)
            }
            if duplicateWarning {
                Text("That identifier is already in the list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trimmedNewID: String {
        newID.trimmingCharacters(in: .whitespaces)
    }

    private var duplicateWarning: Bool {
        !trimmedNewID.isEmpty && ids.contains(trimmedNewID)
    }

    private var addDisabled: Bool {
        trimmedNewID.isEmpty || ids.contains(trimmedNewID)
    }

    private func addID() {
        guard !addDisabled else { return }
        ids.append(trimmedNewID)
        newID = ""
    }
}

struct UbiquitousContainersEditor: View {
    @Binding var containers: [String: [String: Any]]
    @State private var newID = ""

    private enum Keys {
        static let name = "NSUbiquitousContainerName"
        static let isPublic = "NSUbiquitousContainerIsDocumentScopePublic"
        static let folderLevels = "NSUbiquitousContainerSupportedFolderLevels"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ubiquitous Containers (NSUbiquitousContainers)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if containers.isEmpty {
                Text("No ubiquitous containers configured. Add one below if the app declares document containers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(containers.keys.sorted(), id: \.self) { id in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "shippingbox")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(id)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            containers.removeValue(forKey: id)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove container")
                    }
                    TextField("Display name", text: nameBinding(for: id))
                        .textFieldStyle(.roundedBorder)
                    Toggle("Document scope is public", isOn: publicBinding(for: id))
                    Picker("Folder levels", selection: folderLevelsBinding(for: id)) {
                        Text("None").tag("None")
                        Text("One").tag("One")
                        Text("Any").tag("Any")
                    }
                    .pickerStyle(.segmented)
                    Divider()
                }
            }
            HStack {
                TextField("iCloud.com.example.container", text: $newID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addContainer() }
                Button("Add") { addContainer() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(trimmedNewID.isEmpty || containers[trimmedNewID] != nil)
            }
        }
    }

    private var trimmedNewID: String {
        newID.trimmingCharacters(in: .whitespaces)
    }

    private func addContainer() {
        guard !trimmedNewID.isEmpty, containers[trimmedNewID] == nil else { return }
        containers[trimmedNewID] = [
            Keys.name: "",
            Keys.isPublic: false,
            Keys.folderLevels: "None"
        ]
        newID = ""
    }

    private func nameBinding(for id: String) -> Binding<String> {
        Binding(
            get: { containers[id]?[Keys.name] as? String ?? "" },
            set: {
                var entry = containers[id] ?? [:]
                entry[Keys.name] = $0
                containers[id] = entry
            }
        )
    }

    private func publicBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { containers[id]?[Keys.isPublic] as? Bool ?? false },
            set: {
                var entry = containers[id] ?? [:]
                entry[Keys.isPublic] = $0
                containers[id] = entry
            }
        )
    }

    private func folderLevelsBinding(for id: String) -> Binding<String> {
        Binding(
            get: { containers[id]?[Keys.folderLevels] as? String ?? "None" },
            set: {
                var entry = containers[id] ?? [:]
                entry[Keys.folderLevels] = $0
                containers[id] = entry
            }
        )
    }
}

struct EntitlementDictionaryEditor: View {
    @Binding var entries: [String: String]
    @State private var newKey = ""
    @State private var newValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entries.isEmpty {
                Text("Empty dictionary.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries.keys.sorted(), id: \.self) { key in
                HStack {
                    Image(systemName: "curlybraces")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    TextField("Value", text: Binding(
                        get: { entries[key] ?? "" },
                        set: { entries[key] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    Button {
                        entries.removeValue(forKey: key)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove entry")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            }
            HStack {
                TextField("Key", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                TextField("Value", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addEntry() }
                Button("Add") { addEntry() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(trimmedKey.isEmpty || entries[trimmedKey] != nil)
            }
        }
    }

    private var trimmedKey: String {
        newKey.trimmingCharacters(in: .whitespaces)
    }

    private func addEntry() {
        guard !trimmedKey.isEmpty, entries[trimmedKey] == nil else { return }
        entries[trimmedKey] = newValue
        newKey = ""
        newValue = ""
    }
}

struct EntitlementRowView: View {
    let key: String
    let value: Any
    let onSelect: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onValueChange: (Any) -> Void

    private var typeIcon: String {
        if value is Bool { return "switch.2" }
        if value is [String] { return "list.bullet" }
        if value is [Any] { return "list.bullet" }
        if value is [String: Any] { return "curlybraces" }
        return "textformat"
    }

    private var typeName: String {
        if value is Bool { return "Boolean" }
        if value is [String] { return "Array of Strings" }
        if value is [Any] { return "Array" }
        if value is [String: String] { return "Dictionary (String values)" }
        if value is [String: Any] { return "Dictionary" }
        if value is String { return "String" }
        return "Value"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: typeIcon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(key)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .lineLimit(1)
                    if let meta = EntitlementsCatalog.all.first(where: { $0.rawKey == key }) {
                        Text(meta.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(typeName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(minWidth: 220, alignment: .leading)

                Spacer()

                if let boolVal = value as? Bool {
                    Toggle("", isOn: Binding(
                        get: { boolVal },
                        set: { onValueChange($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                Button(action: onSelect) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Inspect Capability")

                Button(action: onDuplicate) {
                    Image(systemName: "plus.square.on.square")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Duplicate Capability")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove Capability")
            }

            valueEditor
                .padding(.leading, 36)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var valueEditor: some View {
        if value is Bool {
            EmptyView()
        } else if value is [String] {
            EntitlementIDListEditor(
                ids: Binding(
                    get: { value as? [String] ?? [] },
                    set: { onValueChange($0) }
                ),
                placeholder: "value"
            )
        } else if let arrVal = value as? [Any] {
            Text("\(arrVal.count) entries (non-string array — remove and re-add to edit inline)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
        } else if value is [String: String] {
            EntitlementDictionaryEditor(
                entries: Binding(
                    get: { value as? [String: String] ?? [:] },
                    set: { onValueChange($0) }
                )
            )
        } else if let dictVal = value as? [String: Any] {
            Text("Dictionary with \(dictVal.count) entries (non-string values — remove and re-add to edit inline)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
        } else {
            TextField("", text: Binding(
                get: { String(describing: value) },
                set: { onValueChange($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .frame(minWidth: 160, maxWidth: 400)
        }
    }
}
