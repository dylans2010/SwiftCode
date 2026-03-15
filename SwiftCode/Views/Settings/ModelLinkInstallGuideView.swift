import SwiftUI

struct ModelLinkInstallGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = OfflineModelManager.shared

    @State private var repositoryLink = ""
    @State private var resolvedMetadata: OfflineModelMetadata?
    @State private var errorMessage: String?
    @State private var isLoadingMetadata = false
    @State private var activeRequest: OfflineModelDownloader.DownloadRequest?

    let onInstalled: () async -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hugging Face repositories host open-source AI models that can run locally when a compatible file is available.")
                        .font(.callout)

                    Text("How to find a model")
                        .font(.headline)
                    Text("1. Open huggingface.co\n2. Choose a model repository\n3. Copy the repository URL")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Example link")
                        .font(.headline)
                    Text("https://huggingface.co/microsoft/phi-3-mini-4k-instruct")
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("Paste Model Link")
                        .font(.headline)

                    TextField("https://huggingface.co/{author}/{model} or direct file URL", text: $repositoryLink)
                        .textInputAutocapitalization(.never)
#if canImport(UIKit)
                        .autocorrectionDisabled(true)
#endif
                        .textFieldStyle(.roundedBorder)

                    Button("Fetch Model Info") {
                        Task { await fetchMetadata() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoadingMetadata || repositoryLink.isEmpty)

                    Button("Download Model") {
                        launchDownloadFlow()
                    }
                    .buttonStyle(.bordered)
                    .disabled(repositoryLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    if let metadata = resolvedMetadata {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(metadata.modelName)
                                .font(.headline)
                            Text(metadata.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Provider: \(metadata.providerName)")
                                .font(.caption)
                            Text("Compatible files: \(metadata.files.count)")
                                .font(.caption)
                            Text("Preferred: \(metadata.preferredDownloadFile?.fileName ?? "None")")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Install Through Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(item: $activeRequest) { request in
            ModelDownloadProgressView(request: request) {
                await onInstalled()
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    private func fetchMetadata() async {
        errorMessage = nil
        resolvedMetadata = nil

        guard manager.validateRepositoryURL(repositoryLink) else {
            errorMessage = OfflineModelError.invalidHuggingFaceURL.localizedDescription
            return
        }

        isLoadingMetadata = true
        defer { isLoadingMetadata = false }

        do {
            let metadata = try await manager.fetchModelMetadataFromLink(repositoryLink)
            resolvedMetadata = metadata
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func launchDownloadFlow() {
        errorMessage = nil

        if let metadata = resolvedMetadata {
            if manager.isModelInstalled(metadata.modelName) {
                errorMessage = "This model is already installed."
                return
            }

            activeRequest = OfflineModelDownloader.DownloadRequest(source: .metadata(metadata), originalLink: repositoryLink)
            return
        }

        guard let url = URL(string: repositoryLink.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = OfflineModelError.invalidModelURL.localizedDescription
            return
        }

        activeRequest = OfflineModelDownloader.DownloadRequest(source: .directURL(url), originalLink: repositoryLink)
    }
}
