import AppKit
import Foundation
import SwiftUI
import YcodeIDECore
import YcodeIDEShell
import YcodeSigning

struct EntitlementsEditorView: View {
    @Bindable var model: EntitlementsEditorModel
    @Environment(\.colorScheme) private var scheme
    @Environment(WorkspaceViewModel.self) private var workspaceViewModel: WorkspaceViewModel?
    @State private var status: String?
    @State private var customKey = ""
    @State private var customKeyType = "Boolean"
    @State private var rawText = ""
    @State private var showingRaw = false
    @State private var showingAddSheet = false
    @State private var showingInspectorSheet = false
    @State private var addSheetSearch = ""
    @State private var addSheetSection: EntitlementCapabilitySection = .all
    @State private var addSheetCustomKey = ""
    @State private var addSheetCustomKeyType = "boolean"
    @State private var isCreating = false
    @State private var creationError: String?

    init(model: EntitlementsEditorModel) {
        self._model = Bindable(wrappedValue: model)
    }

    init(fileURL: URL?) {
        let m = (try? EntitlementsEditorModel(url: fileURL)) ?? EntitlementsEditorModel(entitlements: [:])
        self._model = Bindable(wrappedValue: m)
    }

    var body: some View {
        let c = ShellColors(scheme)
        if model.url == nil {
            VStack(spacing: 20) {
                ContentUnavailableView {
                    Label("No Entitlements Configured", systemImage: "lock.shield")
                } description: {
                    Text("The currently selected target does not contain an Entitlements configuration file.\n\nYou can create a standard entitlements file in your project workspace.")
                }

                if let error = creationError {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                Button {
                    createEntitlements()
                } label: {
                    Label(isCreating ? "Creating..." : "Create Entitlements", systemImage: "plus")
                        .font(.headline)
                        .frame(minWidth: 160)
                }
                .buttonStyle(.bordered)
                .disabled(isCreating)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(c.content)
        } else {
            VStack(spacing: 0) {
                toolbar(c)
                Hairline(color: c.separator)
                if let p = model.problem { ProblemBanner(message: p) { model.clearProblem() } }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        fileStatusCard(c)
                        validationPanel(c)
                        ForEach(model.visibleSections) { section in
                            capabilitySection(section, c)
                        }
                        uncoveredKeysSection(c)
                        if showingRaw { rawXMLSection(c) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        }
    }

    private func createEntitlements() {
        guard let project = ProjectSessionStore.shared.activeProject else {
            creationError = "No active project found in session."
            return
        }

        isCreating = true
        creationError = nil

        let targetURL = EntitlementsFileTemplate.defaultURL(in: project.directoryURL, projectName: project.name)

        Task {
            do {
                try EntitlementsFileTemplate.writeDefaultEntitlements(to: targetURL)
                ProjectSessionStore.shared.refreshFileTree(for: project)
                if let workspaceViewModel {
                    await workspaceViewModel.editor.openFile(url: targetURL)
                    await workspaceViewModel.editor.updateActiveConfigurationURLs(for: project)
                }
                isCreating = false
            } catch {
                isCreating = false
                creationError = "Failed to create Entitlements: \(error.localizedDescription)"
            }
        }
    }

    private func toolbar(_ c: ShellColors) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(c.secondaryLabel)
                TextField("Search capabilities", text: $model.searchText)
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
            .padding(.vertical, 6)
            .background(c.content, in: RoundedRectangle(cornerRadius: 8))
            .frame(width: 260)
            Picker("Section", selection: $model.selectedSection) {
                ForEach(EntitlementCapabilitySection.allCases) { section in
                    Text(section.fullTitle).tag(section)
                }
            }
            .frame(width: 200)
            Spacer()
            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(c.secondaryLabel)
                    .lineLimit(1)
            }
            Menu {
                Menu("Presets") {
                    ForEach(EntitlementsPreset.allCases, id: \.rawValue) { preset in
                        Button(preset.rawValue) {
                            model.applyPreset(preset)
                            status = "Applied \(preset.rawValue)"
                        }
                    }
                }
                Button("Validate") {
                    let issues = model.validate()
                    status = issues.isEmpty ? "All capabilities are valid."
                        : "Validation: \(issues.map(\.message).joined(separator: "; "))"
                }
                Button("Copy Raw XML") {
                    status = "Raw XML is shown below."
                    showingRaw = true
                    rawText = model.xmlText()
                }
                Divider()
                Button("Revert") {
                    do {
                        try model.revert()
                        status = "Reverted unsaved changes."
                    } catch {
                        model.setProblem("Could not re-read entitlements file: \(error.localizedDescription)")
                    }
                }
                .disabled(!model.isDirty)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            Button("Add Capability") {
                showingAddSheet = true
            }
            .buttonStyle(.bordered)
            Button("Save") {
                do {
                    try model.save()
                    status = "Successfully saved entitlements to disk."
                } catch {
                    model.setProblem("Error saving entitlements: \(error.localizedDescription)")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.isDirty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(c.sidebar)
    }

    private func fileStatusCard(_ c: ShellColors) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.teal.opacity(0.12))
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(.teal)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.url?.lastPathComponent ?? "Entitlements")
                    .font(.headline)
                    .lineLimit(1)
                Text(model.url?.path ?? "")
                    .font(.caption)
                    .foregroundStyle(c.secondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(model.entitlements.count) active")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(c.content, in: Capsule())
                if let date = model.lastModified {
                    Text("Modified \(date, style: .date)")
                        .font(.caption)
                        .foregroundStyle(c.secondaryLabel)
                }
                Text(model.sandboxIsOn ? "Sandbox on" : "Sandbox off")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(model.sandboxIsOn ? .green : c.secondaryLabel)
            }
        }
        .padding(16)
        .background(c.sidebar, in: RoundedRectangle(cornerRadius: 10))
    }

    private func validationPanel(_ c: ShellColors) -> some View {
        let issues = model.validate()
        return Group {
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Entitlement Issues (\(issues.count))")
                            .font(.headline)
                        Spacer()
                        Text("Fix the entries below or remove the conflicting key.")
                            .font(.caption)
                            .foregroundStyle(c.secondaryLabel)
                    }
                    ForEach(issues) { issue in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(issue.severity == .error ? c.error : c.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.message)
                                    .font(.callout)
                                Text(issue.rawKey)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(c.secondaryLabel)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(14)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func capabilitySection(_ section: EntitlementCapabilitySection, _ c: ShellColors) -> some View {
        let defs = EntitlementCapabilityCatalog.definitions(in: section)
            .filter { model.capabilityMatchesSearch($0) }
        return Group {
            if !defs.isEmpty {
                Text(section.fullTitle).font(.headline)
                ForEach(defs) { def in
                    capabilityCard(def, c)
                }
            }
        }
    }

    private func capabilityCard(_ def: CapabilityDefinition, _ c: ShellColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: def.symbol)
                    .foregroundStyle(c.secondaryLabel)
                VStack(alignment: .leading, spacing: 2) {
                    Text(def.name).font(.headline)
                    Text(def.rawKey)
                        .font(.caption)
                        .foregroundStyle(c.secondaryLabel)
                }
                Spacer()
                if def.requiresSpecialApproval {
                    Text("Special approval")
                        .font(.caption)
                        .foregroundStyle(c.warning)
                }
                Toggle("", isOn: Binding(
                    get: { model.isCapabilityOn(def) },
                    set: { model.setCapability(def, on: $0) }
                ))
                .labelsHidden()
            }
            Text(def.explanation)
                .font(.callout)
                .foregroundStyle(c.secondaryLabel)
            if model.isCapabilityOn(def) {
                capabilityPayloadEditor(def, c)
            }
        }
        .padding(14)
        .background(c.sidebar, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func capabilityPayloadEditor(_ def: CapabilityDefinition, _ c: ShellColors) -> some View {
        switch def.payload {
        case .none:
            EmptyView()
        case .idList(let placeholder):
            IDListEditor(ids: Binding(
                get: { model.stringArray(forKey: def.rawKey) },
                set: { model.setStringArray($0, forKey: def.rawKey) }
            ), placeholder: placeholder)
        case .fixedValueList(let allowed):
            FixedValueListEditor(values: Binding(
                get: { model.stringArray(forKey: def.rawKey) },
                set: { model.setStringArray($0, forKey: def.rawKey) }
            ), allowed: allowed)
        case .choice(let options):
            Picker("Value", selection: Binding(
                get: { model.string(forKey: def.rawKey, fallback: options.first ?? "") },
                set: { model.setString($0, forKey: def.rawKey) }
            )) {
                ForEach(options, id: \.self) { option in Text(option).tag(option) }
            }
        case .stringValue(let placeholder):
            TextField(placeholder, text: Binding(
                get: { model.string(forKey: def.rawKey, fallback: "") },
                set: { model.setString($0, forKey: def.rawKey) }
            ))
            .textFieldStyle(.roundedBorder)
        case .prefixedList(let prefixes, let placeholder):
            AssociatedDomainsEditor(domains: Binding(
                get: { model.stringArray(forKey: def.rawKey) },
                set: { model.setStringArray($0, forKey: def.rawKey) }
            ), prefixes: prefixes, placeholder: placeholder)
        case .iCloudComposite:
            ICloudCompositeEditor(model: model)
        }
    }

    private func uncoveredKeysSection(_ c: ShellColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(EntitlementCapabilitySection.other.fullTitle, systemImage: EntitlementCapabilitySection.other.icon)
                .font(.headline)
                .foregroundStyle(c.secondaryLabel)
            Text("Entitlement keys present in the file that no capability toggle manages. Select one to inspect it, edit it in place, duplicate it, or remove it.")
                .font(.callout)
                .foregroundStyle(c.secondaryLabel)
            if model.uncoveredKeys.isEmpty {
                Text("No unmanaged keys.")
                    .font(.caption)
                    .foregroundStyle(c.secondaryLabel)
            }
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
                        status = "Duplicated to \(copyKey)"
                    },
                    onDelete: {
                        model.set(nil, forKey: key)
                        if model.selectedKey == key { model.selectedKey = nil }
                    },
                    onValueChange: { newVal in
                        guard let converted = EntitlementValue(propertyList: newVal) else {
                            status = "Could not store that value for \(key)."
                            return
                        }
                        model.set(converted, forKey: key)
                    }
                )
                .padding(.vertical, 2)
            }
            HStack {
                TextField("Add a key, e.g. com.example.custom", text: $customKey)
                    .textFieldStyle(.roundedBorder)
                Picker("Type", selection: $customKeyType) {
                    ForEach(["Boolean", "String", "Array"], id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 110)
                Button("Add") {
                    let key = customKey.trimmingCharacters(in: .whitespaces)
                    guard !key.isEmpty, model.entitlements[key] == nil else { return }
                    switch customKeyType {
                    case "String": model.setString("", forKey: key)
                    case "Array": model.setStringArray([], forKey: key)
                    default: model.setBool(false, forKey: key)
                    }
                    customKey = ""
                }
                .disabled(customKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func rawXMLSection(_ c: ShellColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Raw XML").font(.headline)
                Spacer()
                Button("Copy XML") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.xmlText(), forType: .string)
                    status = "Copied entitlements XML to clipboard"
                }
                Button("Apply XML") {
                    do {
                        try model.setXMLText(rawText)
                        status = "Applied raw XML."
                    } catch {
                        model.setProblem("Raw XML is not a valid entitlements dictionary: \(error.localizedDescription)")
                    }
                }
                Button("Reload") { rawText = model.xmlText() }
            }
            TextEditor(text: $rawText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 220)
                .border(c.separator)
        }
    }

    private var addCapabilitySheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Add Capability to Entitlements", systemImage: "plus.circle.fill")
                    .font(.title3.bold())
                Spacer()
                Button {
                    showingAddSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search capabilities by name, key, or category...", text: $addSheetSearch)
                    .textFieldStyle(.plain)
                if !addSheetSearch.isEmpty {
                    Button { addSheetSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(EntitlementCapabilitySection.allCases.filter { $0 != .other }) { cat in
                        let isSelected = addSheetSection == cat
                        Button {
                            addSheetSection = cat
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.caption2)
                                Text(cat.rawValue)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(isSelected ? Color.teal : Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let available = EntitlementCapabilityCatalog.definitions
                .filter { !model.isCapabilityOn($0) }
                .filter { def in
                    if addSheetSection != .all && def.section != addSheetSection {
                        return false
                    }
                    if addSheetSearch.isEmpty { return true }
                    let query = addSheetSearch.lowercased()
                    return def.name.lowercased().contains(query)
                        || def.rawKey.lowercased().contains(query)
                        || def.explanation.lowercased().contains(query)
                }

            if available.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No matching capabilities found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                List(available) { def in
                    HStack(spacing: 12) {
                        Image(systemName: def.symbol)
                            .font(.title3)
                            .foregroundStyle(.teal)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(def.name)
                                .font(.body.weight(.medium))
                            Text(def.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(def.rawKey)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button("Add") {
                            model.setCapability(def, on: true)
                            showingAddSheet = false
                            status = "Added \(def.name)"
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset)
                .frame(minHeight: 240)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Entitlement Key")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("e.g. com.example.custom-capability", text: $addSheetCustomKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Picker("Type", selection: $addSheetCustomKeyType) {
                        Text("Boolean").tag("boolean")
                        Text("String").tag("string")
                        Text("Array").tag("array")
                        Text("Dictionary").tag("dictionary")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    Button("Add Custom") {
                        let trimmed = addSheetCustomKey.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, model.entitlements[trimmed] == nil else { return }
                        switch addSheetCustomKeyType {
                        case "string":
                            model.setString("", forKey: trimmed)
                        case "array":
                            model.setStringArray([], forKey: trimmed)
                        case "dictionary":
                            model.set(.dictionary([:]), forKey: trimmed)
                        default:
                            model.setBool(true, forKey: trimmed)
                        }
                        addSheetCustomKey = ""
                        showingAddSheet = false
                        status = "Added custom key \(trimmed)"
                    }
                    .buttonStyle(.bordered)
                    .disabled(addSheetCustomKey.trimmingCharacters(in: .whitespaces).isEmpty || model.entitlements[addSheetCustomKey.trimmingCharacters(in: .whitespaces)] != nil)
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    showingAddSheet = false
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 620)
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
