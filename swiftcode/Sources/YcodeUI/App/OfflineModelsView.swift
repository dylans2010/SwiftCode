import YcodeAssistant
import SwiftUI

public struct OfflineModelsView: View {
    @State private var manager = OfflineModelManager.shared
    @State private var downloader = OfflineModelDownloader.shared
    @State private var runner = OfflineModelRunner.shared
    @State private var availableModels: [OfflineModelMetadata] = []
    @State private var recommendations: [RecommendedOfflineModel] = []
    @State private var searchQuery: String = ""
    @State private var selectedFilterTag: String? = nil
    @State private var isLoading = false
    @State private var isRefreshingFromAPI = false
    @State private var isSearching = false
    @State private var downloadingModel: OfflineModelMetadata?
    @State private var isPresentingInstallGuide = false
    @State private var directLinkInput: String = ""
    @State private var directLinkError: String? = nil
    @State private var isResolvingDirectLink = false

    private let popularChips = [
        "DeepSeek-Coder",
        "Qwen2.5-Coder",
        "CodeLlama",
        "StarCoder",
        "Phi-3",
        "GGUF",
        "MLX"
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                hardwareAccelerationCard

                
                if downloader.isDownloading || downloader.activeModel != nil {
                    activeDownloadCard
                }

                
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Installed Local Models", systemImage: "externaldrive.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("\(manager.installedModelRecords.count) installed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        InstalledOfflineModelsView(manager: manager)
                    }
                    .padding()
                }
                .groupBoxStyle(ModernGroupBoxStyle())

                
                huggingFaceSearchSection

                
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Recommended for this Mac", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Spacer()
                        }

                        if recommendations.isEmpty {
                            Text("No Recommendations Available")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(recommendations) { recommendation in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(recommendation.modelName)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Spacer()

                                            Text(recommendation.estimatedSize)
                                                .font(.caption.bold())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                                .foregroundStyle(.purple)
                                        }

                                        Text(recommendation.description)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        HStack {
                                            Label("Compatibility: \(recommendation.compatibility)", systemImage: "cpu")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Button("Download") {
                                                Task { await startRecommendedDownload(recommendation) }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(downloader.isDownloading)
                                        }
                                    }
                                    .padding(14)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
                .groupBoxStyle(ModernGroupBoxStyle())

                
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Install Model via Hugging Face Link", systemImage: "link")
                                .font(.headline)
                                .foregroundColor(.indigo)
                            Spacer()
                        }

                        Text("Paste a Hugging Face repository URL (e.g. https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct). SwiftCode will inspect compatible weights and download them into your local offline directory.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField("https://huggingface.co/...", text: $directLinkInput)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                Task {
                                    await resolveAndDownloadDirectLink()
                                }
                            } label: {
                                if isResolvingDirectLink {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Text("Verify & Download")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(directLinkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResolvingDirectLink || downloader.isDownloading)
                        }

                        if let directLinkError {
                            Text(directLinkError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding()
                }
                .groupBoxStyle(ModernGroupBoxStyle())
            }
            .padding(24)
        }
        .navigationTitle("Offline Models")
        .task {
            manager.loadInstalledModels()
            recommendations = DeviceCapabilityAnalyzer.shared.getRecommendedModelList()
            await loadModels(forceRefresh: false)
        }
        .sheet(item: $downloadingModel) { model in
            ModelDownloadProgressView(
                modelName: model.modelName,
                modelLink: model.modelURL.absoluteString,
                metadata: model
            ) {
                downloadingModel = nil
                await loadModels(forceRefresh: false)
            }
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPresentingInstallGuide) {
            ModelLinkInstallGuideView {
                await loadModels(forceRefresh: false)
            }
        }
    }

    
    private var hardwareAccelerationCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Hardware Acceleration", systemImage: "bolt.badge.clock.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("Apple Silicon Optimized")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                        .foregroundStyle(.orange)
                }

                Picker("Compute Target", selection: Binding(
                    get: { runner.hardwareAcceleration },
                    set: { runner.hardwareAcceleration = $0 }
                )) {
                    ForEach(HardwareAcceleration.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 6) {
                    Image(systemName: runner.hardwareAcceleration.icon)
                        .foregroundStyle(.secondary)
                    Text(runner.hardwareAcceleration.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .groupBoxStyle(ModernGroupBoxStyle())
    }

    
    private var activeDownloadCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(downloader.activeModel?.modelName ?? "Downloading Model...")
                            .font(.headline)
                    }
                    Spacer()

                    HStack(spacing: 8) {
                        if downloader.isPaused {
                            Button {
                                downloader.resumeDownload()
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button {
                                downloader.pauseDownload()
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(role: .destructive) {
                            downloader.cancelCurrentDownload()
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                    }
                }

                ProgressView(value: downloader.downloadPercentage, total: 100)
                    .tint(Theme.accentSwiftUIColor)

                HStack {
                    Text(downloader.progressLine)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("File: \(downloader.currentFileName)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.04))
            .cornerRadius(12)
        }
        .groupBoxStyle(ModernGroupBoxStyle())
    }

    
    private var huggingFaceSearchSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Hugging Face Model Hub", systemImage: "magnifyingglass")
                        .font(.headline)
                        .foregroundColor(.green)
                    Spacer()

                    if isSearching || isLoading {
                        ProgressView().scaleEffect(0.6)
                    }

                    Button {
                        Task { await performSearch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh search results")
                }

                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search coding models (DeepSeek, Qwen, CodeLlama, etc.)...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task { await performSearch() }
                        }
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            Task { await performSearch() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(popularChips, id: \.self) { chip in
                            let isSelected = searchQuery.localizedCaseInsensitiveContains(chip)
                            Button {
                                searchQuery = chip
                                Task { await performSearch() }
                            } label: {
                                Text(chip)
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(isSelected ? Color.green.opacity(0.2) : Color.secondary.opacity(0.12), in: Capsule())
                                    .foregroundStyle(isSelected ? Color.green : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                if availableModels.isEmpty && !isLoading {
                    Text("No Hugging Face models found matching '\(searchQuery)'. Try another search.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 12) {
                        ForEach(availableModels) { model in
                            let isInstalled = manager.isModelInstalled(model.modelName)

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.modelName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        HStack(spacing: 6) {
                                            Text(model.providerName)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text("•")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            Label("\(model.downloadCount) downloads", systemImage: "arrow.down.circle")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()

                                    Text(model.modelSize)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(.green)
                                }

                                Text(model.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)

                                HStack {
                                    if model.isQuantized {
                                        Label("Quantized", systemImage: "scalemass")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if isInstalled {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                            Text("Installed")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.green)
                                        }
                                    } else {
                                        Button {
                                            startDownload(model)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.down.circle")
                                                Text("Download")
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(downloader.isDownloading || model.preferredDownloadFile == nil)
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .groupBoxStyle(ModernGroupBoxStyle())
    }

    private func performSearch() async {
        isSearching = true
        do {
            availableModels = try await HuggingFaceAPI.shared.searchModels(query: searchQuery, limit: 20)
        } catch {
            print("Failed to search Hugging Face models: \(error)")
        }
        isSearching = false
    }

    private func loadModels(forceRefresh: Bool) async {
        isLoading = !forceRefresh
        isRefreshingFromAPI = forceRefresh
        do {
            if searchQuery.isEmpty {
                availableModels = try await HuggingFaceAPI.shared.fetchModels(forceRefresh: forceRefresh)
            } else {
                availableModels = try await HuggingFaceAPI.shared.searchModels(query: searchQuery, limit: 20)
            }
        } catch {
            print("Failed to fetch models: \(error)")
        }
        isLoading = false
        isRefreshingFromAPI = false
    }

    private func startDownload(_ model: OfflineModelMetadata) {
        downloader.startDownload(model: model)
        downloadingModel = model
    }

    private func startRecommendedDownload(_ recommendation: RecommendedOfflineModel) async {
        do {
            let metadata = try await manager.fetchModelMetadataFromLink(recommendation.suggestedLink)
            downloader.startDownload(model: metadata)
            downloadingModel = metadata
        } catch {
            print("Failed to start recommended model download: \(error)")
        }
    }

    private func resolveAndDownloadDirectLink() async {
        let trimmed = directLinkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isResolvingDirectLink = true
        directLinkError = nil
        do {
            let metadata = try await manager.fetchModelMetadataFromLink(trimmed)
            directLinkInput = ""
            startDownload(metadata)
        } catch {
            directLinkError = "Could not resolve repository: \(error.localizedDescription)"
        }
        isResolvingDirectLink = false
    }
}
