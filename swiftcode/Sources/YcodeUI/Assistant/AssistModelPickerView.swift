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
            return ProviderSection(provider: section.provider, availability: .ready(models))
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.28)
            if filteredSections.isEmpty {
                noResults
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(filteredSections) { section in
                            providerSection(section)
                        }
                    }
                    .padding(12)
                }
                .scrollIndicators(.hidden)
            }
            Divider().opacity(0.28)
            footer
        }
        .frame(width: 352, height: 452)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.95), Color.indigo.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)
                .shadow(color: Color.accentColor.opacity(0.18), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Model")
                        .font(.system(size: 13.5, weight: .semibold))
                    Text("Choose a provider and model")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                TextField("Search models", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.055), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.075), lineWidth: 1)
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 12)
    }

    private func providerSection(_ section: ProviderSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: Self.symbol(for: section.provider))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(section.isReady ? Color.accentColor : Color.secondary)
                    .frame(width: 18, height: 18)
                    .background(
                        (section.isReady ? Color.accentColor : Color.secondary).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )

                Text(section.provider.displayName)
                    .font(.system(size: 11, weight: .semibold))

                statusBadge(section)
                Spacer()
            }
            .padding(.horizontal, 4)

            if section.isReady {
                VStack(spacing: 4) {
                    ForEach(section.models, id: \.id) { model in
                        ModelOptionRow(
                            section: section,
                            model: model,
                            isSelected: section.provider == selectedKind && model.id == selectedModelID,
                            onSelect: onSelect
                        )
                    }
                }
            } else {
                unavailableRow(section)
            }
        }
    }

    private func statusBadge(_ section: ProviderSection) -> some View {
        let color = section.isReady ? Color.green : Color.orange
        let text = section.isReady ? "\(section.models.count)" : Self.stateText(section.availability)
        return Text(text)
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.14), lineWidth: 0.5)
            )
    }

    private func unavailableRow(_ section: ProviderSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(section.availability?.hint ?? "Checking availability…")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045), lineWidth: 1)
        )
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
            Text("No matching models")
                .font(.system(size: 13, weight: .semibold))
            Text("Try a different provider or model name.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            FooterActionButton(title: "Refresh", symbol: "arrow.clockwise", action: onCheckAgain)
            FooterActionButton(title: "Settings", symbol: "gear", action: onOpenSettings)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    static func stateText(_ availability: ProviderAvailability?) -> String {
        switch availability {
        case nil: "checking"
        case .ready?: "ready"
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

private struct ModelOptionRow: View {
    let section: AssistModelPickerView.ProviderSection
    let model: ModelInfo
    let isSelected: Bool
    let onSelect: (ProviderKind, String?) -> Void

    @State private var isHovered = false

    var body: some View {
        let title = model.displayName.isEmpty ? "Default" : model.displayName
        Button {
            onSelect(section.provider, model.id.isEmpty ? nil : model.id)
        } label: {
            HStack(spacing: 9) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
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
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(
                isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(isHovered ? 0.055 : 0.025),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.26) : Color.primary.opacity(isHovered ? 0.09 : 0.035), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FooterActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .contentShape(Capsule())
                .background(Color.primary.opacity(isHovered ? 0.085 : 0.055), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(isHovered ? 0.1 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
