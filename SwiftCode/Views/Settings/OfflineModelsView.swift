import SwiftUI

struct OfflineModelsView: View {
    @StateObject private var manager = OfflineModelManager.shared
    @State private var availableModels: [OfflineModelMetadata] = []
    @State private var isLoading = false
    @State private var isRefreshingFromAPI = false
    @State private var downloadingModel: OfflineModelMetadata?

    var body: some View {
        List {
            InstalledOfflineModelsView(manager: manager)

            Section("Available Models (HuggingFace)") {
                Button {
                    Task {
                        await loadModels(forceRefresh: true)
                    }
                } label: {
                    HStack {
                        Label("Fetch from HuggingFace API", systemImage: "arrow.clockwise")
                        if isRefreshingFromAPI {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                }
                .disabled(isLoading || isRefreshingFromAPI)

                if isLoading {
                    ProgressView()
                } else {
                    ForEach(availableModels) { model in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.modelName)
                                .font(.headline)
                            Text(model.description)
                                .font(.caption)
                                .lineLimit(2)

                            HStack {
                                Text(model.modelSize)
                                Spacer()
                                Button {
                                    startDownload(model)
                                } label: {
                                    Text("Download")
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(manager.isModelInstalled(model.modelName))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Offline Models")
        .task {
            manager.loadInstalledModels()
            await loadModels(forceRefresh: false)
        }
        .sheet(item: $downloadingModel) { model in
            ModelDownloadProgressView(modelName: model.modelName)
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
        }
    }

    private func loadModels(forceRefresh: Bool) async {
        isLoading = !forceRefresh
        isRefreshingFromAPI = forceRefresh
        do {
            availableModels = try await HuggingFaceAPI.shared.fetchModels(forceRefresh: forceRefresh)
        } catch {
            print("Failed to fetch models: \(error)")
        }
        isLoading = false
        isRefreshingFromAPI = false
    }

    private func startDownload(_ model: OfflineModelMetadata) {
        downloadingModel = model
        Task {
            try? await OfflineModelDownloader.shared.download(model: model)
            manager.loadInstalledModels()
            await loadModels(forceRefresh: false)
        }
    }
}
