import SwiftUI

struct OfflineModelsView: View {
    @StateObject private var manager = OfflineModelManager.shared
    @State private var availableModels: [OfflineModelMetadata] = []
    @State private var isLoading = false
    @State private var downloadingModel: OfflineModelMetadata?

    var body: some View {
        List {
            Section("Installed Models") {
                if manager.installedModels.isEmpty {
                    Text("No local models installed")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(manager.installedModels) { model in
                        VStack(alignment: .leading) {
                            Text(model.modelName)
                                .font(.headline)
                            HStack {
                                Text(model.providerName)
                                Text("•")
                                Text(model.modelSize)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            HStack {
                                Button("Run") {
                                    // Test run
                                }
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    manager.removeModel(model)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }

            Section("Available Models (HuggingFace)") {
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
            await loadModels()
        }
        .sheet(item: $downloadingModel) { model in
            ModelDownloadProgressView(modelName: model.modelName)
        }
    }

    private func loadModels() async {
        isLoading = true
        do {
            availableModels = try await HuggingFaceAPI.shared.fetchModels()
        } catch {
            print("Failed to fetch models: \(error)")
        }
        isLoading = false
    }

    private func startDownload(_ model: OfflineModelMetadata) {
        downloadingModel = model
        Task {
            try? await OfflineModelDownloader.shared.download(model: model)
            await loadModels() // Refresh
        }
    }
}
