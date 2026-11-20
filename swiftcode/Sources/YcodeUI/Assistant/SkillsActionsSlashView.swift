import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
import YcodeAssistant

public enum SlashCommandKind: String, Codable, Sendable, CaseIterable {
    case builtIn = "Action"
    case skill = "Skill"
}

public struct SlashPaletteItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let command: String
    public let title: String
    public let subtitle: String
    public let iconName: String
    public let iconColor: Color
    public let badgeText: String
    public let badgeColor: Color
    public let kind: SlashCommandKind
    public let skillDescriptor: SkillDescriptor?

    public init(
        id: String,
        command: String,
        title: String,
        subtitle: String,
        iconName: String,
        iconColor: Color = .accentColor,
        badgeText: String,
        badgeColor: Color = .primary.opacity(0.06),
        kind: SlashCommandKind = .builtIn,
        skillDescriptor: SkillDescriptor? = nil
    ) {
        self.id = id
        self.command = command
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.iconColor = iconColor
        self.badgeText = badgeText
        self.badgeColor = badgeColor
        self.kind = kind
        self.skillDescriptor = skillDescriptor
    }
}

public struct SkillsActionsSlashView: View {
    public let query: String
    public var onSelectAction: (SlashPaletteItem) -> Void
    public var onDismiss: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var selectedCategory: String = "All"
    @State private var skillIndex = SkillIndex.shared

    public init(
        query: String = "",
        onSelectAction: @escaping (SlashPaletteItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.query = query
        self.onSelectAction = onSelectAction
        self.onDismiss = onDismiss
    }

    public static let builtInActions: [SlashPaletteItem] = [
        SlashPaletteItem(
            id: "action-schedule",
            command: "/schedule",
            title: "Schedule Task",
            subtitle: "Schedule delayed background tasks, one-shot timers or recurring cron routines",
            iconName: "clock.badge.checkmark",
            iconColor: .orange,
            badgeText: "Schedule",
            badgeColor: Color.orange.opacity(0.12),
            kind: .builtIn
        ),
        SlashPaletteItem(
            id: "action-compact",
            command: "/compact",
            title: "Compact Conversation",
            subtitle: "Fully compact long session conversation, summarizing history into memory to free context tokens",
            iconName: "arrow.triangle.merge",
            iconColor: .cyan,
            badgeText: "Context",
            badgeColor: Color.cyan.opacity(0.12),
            kind: .builtIn
        ),
        SlashPaletteItem(
            id: "action-goal",
            command: "/goal",
            title: "Autonomous Goal Mode",
            subtitle: "Sets autonomous goal mode to accomplish the task end-to-end without routine confirmation",
            iconName: "target",
            iconColor: .green,
            badgeText: "Autonomous",
            badgeColor: Color.green.opacity(0.12),
            kind: .builtIn
        ),
        SlashPaletteItem(
            id: "action-teamwork",
            command: "/teamwork",
            title: "Teamwork & Subagents",
            subtitle: "Mandates using the native workers system (subagents) for parallel scoped execution",
            iconName: "person.3.sequence.fill",
            iconColor: .blue,
            badgeText: "Workers",
            badgeColor: Color.blue.opacity(0.12),
            kind: .builtIn
        ),
        SlashPaletteItem(
            id: "action-interview",
            command: "/interview",
            title: "Interactive Interview",
            subtitle: "Interactive interview asking user questions before getting to work using the plan-AskUser decision tool",
            iconName: "questionmark.bubble.fill",
            iconColor: .indigo,
            badgeText: "Planning",
            badgeColor: Color.indigo.opacity(0.12),
            kind: .builtIn
        ),
        SlashPaletteItem(
            id: "action-learn",
            command: "/learn",
            title: "Learn & Remember",
            subtitle: "Reflect on recent successes or corrections to capture reusable skills or persistent rules",
            iconName: "brain.head.profile",
            iconColor: .purple,
            badgeText: "Memory",
            badgeColor: Color.purple.opacity(0.12),
            kind: .builtIn
        ),
        SlashPaletteItem(
            id: "action-boost",
            command: "/boost",
            title: "Boost Master Orchestrator",
            subtitle: "Invokes the model as a master orchestrator commanding workers to boss them around and complete the user task",
            iconName: "bolt.badge.automatic.fill",
            iconColor: .yellow,
            badgeText: "Orchestrator",
            badgeColor: Color.yellow.opacity(0.15),
            kind: .builtIn
        )
    ]

    private var allItems: [SlashPaletteItem] {
        var list: [SlashPaletteItem] = Self.builtInActions

        // Installed skills from authoritative store
        let installed = AgentSkillManager.shared.installedSkills.isEmpty
            ? SkillDiscoveryService.shared.allDiscoveredSkills
            : AgentSkillManager.shared.installedSkills

        for skill in installed {
            list.append(
                SlashPaletteItem(
                    id: "skill-\(skill.id)",
                    command: "/\(skill.name)",
                    title: skill.name,
                    subtitle: skill.description.isEmpty ? "Authoritative workspace skill" : skill.description,
                    iconName: skill.sourceKind.iconName,
                    iconColor: .accentColor,
                    badgeText: skill.sourceKind.rawValue,
                    badgeColor: Color.primary.opacity(0.06),
                    kind: .skill,
                    skillDescriptor: skill
                )
            )
        }

        return list
    }

    private var availableCategories: [String] {
        var cats = ["All", "Actions", "Skills"]
        let customSources = Set(allItems.compactMap { $0.skillDescriptor?.sourceKind.rawValue })
        cats.append(contentsOf: customSources.sorted())
        return cats
    }

    private var filteredItems: [SlashPaletteItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let stripped = cleanQuery.hasPrefix("/") ? String(cleanQuery.dropFirst()) : cleanQuery

        return allItems.filter { item in
            // Category filter
            if selectedCategory == "Actions" && item.kind != .builtIn { return false }
            if selectedCategory == "Skills" && item.kind != .skill { return false }
            if selectedCategory != "All" && selectedCategory != "Actions" && selectedCategory != "Skills" {
                if item.skillDescriptor?.sourceKind.rawValue != selectedCategory {
                    return false
                }
            }

            // Query filter
            guard !stripped.isEmpty else { return true }
            return item.command.lowercased().contains(stripped)
                || item.title.lowercased().contains(stripped)
                || item.subtitle.lowercased().contains(stripped)
                || item.badgeText.lowercased().contains(stripped)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 24, height: 24)

                    Image(systemName: "slash.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Slash Commands & Skills")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("\(filteredItems.count)")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }

                    Text("Built-in actions and installed skills")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("esc to dismiss")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            // Category Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(availableCategories, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                            selectedIndex = 0
                        } label: {
                            Text(cat)
                                .font(.system(size: 10, weight: selectedCategory == cat ? .semibold : .regular))
                                .foregroundColor(selectedCategory == cat ? .primary : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(selectedCategory == cat ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedCategory == cat ? Color.primary.opacity(0.18) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .background(.ultraThinMaterial.opacity(0.6))

            Divider().opacity(0.3)

            // Results List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if filteredItems.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("No commands or skills match '\(query)'")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                        } else {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { idx, item in
                                slashRow(item: item, isSelected: idx == selectedIndex)
                                    .id(idx)
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(height: 280)
                .onChange(of: selectedIndex) { _, newIdx in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }

            Divider().opacity(0.3)

            // Footer
            HStack(spacing: 8) {
                Text("Navigate with ↑↓ and Return ↵")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                if let selected = selectedItem {
                    Text(selected.command)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial.opacity(0.4))
        }
        .frame(width: 480)
        .liquidGlass(style: .sheet, cornerRadius: 12)
        .onExitCommand(perform: onDismiss)
        .background(
            VStack {
                Button("") { selectPrevious() }
                    .keyboardShortcut(.upArrow, modifiers: [])

                Button("") { selectNext() }
                    .keyboardShortcut(.downArrow, modifiers: [])

                Button("") { commitSelected() }
                    .keyboardShortcut(.return, modifiers: [])
            }
            .opacity(0.001)
            .frame(width: 0, height: 0)
        )
    }

    private var selectedItem: SlashPaletteItem? {
        guard selectedIndex >= 0 && selectedIndex < filteredItems.count else { return nil }
        return filteredItems[selectedIndex]
    }

    private func selectPrevious() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + filteredItems.count) % filteredItems.count
    }

    private func selectNext() {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % filteredItems.count
    }

    private func commitSelected() {
        guard let item = selectedItem else { return }
        onSelectAction(item)
    }

    @ViewBuilder
    private func slashRow(item: SlashPaletteItem, isSelected: Bool) -> some View {
        Button {
            onSelectAction(item)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(item.iconColor.opacity(0.12))
                        .frame(width: 22, height: 22)

                    Image(systemName: item.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(item.iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.command)
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)

                        Text(item.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Text(item.badgeText)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(item.kind == .builtIn ? item.iconColor : .secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(item.badgeColor, in: Capsule())
                    }

                    Text(item.subtitle)
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "arrow.turn.down.left")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.4))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.primary.opacity(0.14) : Color.clear, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}
