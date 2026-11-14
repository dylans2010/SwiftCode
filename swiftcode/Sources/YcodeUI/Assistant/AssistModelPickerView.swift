import SwiftUI
import YcodeAssistant




public struct AssistModelPickerView: View {
    public struct ProviderSection: Identifiable {
        public var id: String { provider.rawValue }
        public let provider: ProviderKind
        public let availability: ProviderAvailability?

        public init(provider: ProviderKind, availability: ProviderAvailability?) {
            self.provider = provider
            self.availability = availability
        }

        public var models: [ModelInfo] { availability?.models ?? [] }
        public var isReady: Bool { availability?.isReady == true }
    }

    public var sections: [ProviderSection]
    public var selectedKind: ProviderKind?
    public var selectedModelID: String?
    public var onSelect: (ProviderKind, String?) -> Void
    public var onCheckAgain: () -> Void
    public var onOpenSettings: () -> Void

    @State private var searchText = ""

    public init(sections: [ProviderSection],
                selectedKind: ProviderKind?,
                selectedModelID: String?,
                onSelect: @escaping (ProviderKind, String?) -> Void,
                onCheckAgain: @escaping () -> Void,
                onOpenSettings: @escaping () -> Void) {
        self.sections = sections
        self.selectedKind = selectedKind
        self.selectedModelID = selectedModelID
        self.onSelect = onSelect
        self.onCheckAgain = onCheckAgain
        self.onOpenSettings = onOpenSettings
    }

    private var filteredSections: [ProviderSection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sections }
        return sections.compactMap { section in
            let providerMatches = section.provider.displayName.lowercased().contains(query)
            if providerMatches { return section }
            let models = section.models.filter {
                $0.id.lowercased().contains(query) || $0.displayName.lowercased().contains(query)
            }
            guard !models.isEmpty else { return nil }
            return ProviderSection(provider: section.provider,
                                   availability: .ready(models))
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if filteredSections.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                        ForEach(filteredSections) { section in
                            Section {
                                sectionContent(section)
                            } header: {
                                sectionHeader(section)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            Divider()
            footer
        }
        .frame(width: 340, height: 430)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Assist Models")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search providers and models", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func sectionHeader(_ section: ProviderSection) -> some View {
        HStack(spacing: 5) {
            Image(systemName: Self.symbol(for: section.provider))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 14)
            Text(section.provider.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if section.isReady {
                Text("\(section.models.count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            } else {
                Text(Self.stateSuffix(section.availability))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.bar)
    }

    @ViewBuilder
    private func sectionContent(_ section: ProviderSection) -> some View {
        if section.isReady {
            ForEach(section.models, id: \.id) { model in
                modelRow(section: section, model: model)
            }
        } else if section.models.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(section.availability?.hint ?? "Checking…")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private func modelRow(section: ProviderSection, model: ModelInfo) -> some View {
        let isSelected = section.provider == selectedKind && model.id == selectedModelID
        let title = model.displayName.isEmpty ? "Default" : model.displayName
        return Button {
            onSelect(section.provider, model.id.isEmpty ? nil : model.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if model.id != title {
                        Text(model.id)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Check Again", action: onCheckAgain)
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button("Assist Settings…", action: onOpenSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    static func stateSuffix(_ availability: ProviderAvailability?) -> String {
        switch availability {
        case nil: "checking…"
        case .ready?: ""
        case .notRunning?: "not running"
        case .noModels?: "no models"
        case .notInstalled?: "not installed"
        case .signedOut?: "not signed in"
        case .failed?: "unavailable"
        }
    }

    static func symbol(for provider: ProviderKind) -> String {
        switch provider {
        case .ollama: "server.rack"
        case .llamaCpp: "memorychip"
        case .openAI: "bubble.left.and.bubble.right"
        case .claudeCode: "terminal"
        case .codex: "curlybraces"
        case .antigravity: "cloud"
        case .acpAgent: "plug"
        case .openRouter: "arrow.triangle.branch"
        case .openCode: "chevron.left.forwardslash.chevron.right"
        case .hermes: "wind"
        case .foundationModels: "cpu"
        case .scCloud: "cloud.sun"
        case .metaAssist: "person.2"
        case .anthropic: "brain"
        case .gemini: "sparkle"
        case .mistral: "bolt"
        case .qwen: "cpu"
        case .offlineModels: "externaldrive"
        }
    }
}
