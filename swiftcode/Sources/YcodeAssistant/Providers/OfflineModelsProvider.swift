import Foundation

/// Serves Assist requests with models downloaded from Hugging Face and stored
/// by `OfflineModelManager` (GGUF/MLX/CoreML via `OfflineModelRunner`).
public struct OfflineModelsProvider: AssistantProvider {
    public let kind = ProviderKind.offlineModels

    static let noModelsHint = "No offline models are installed. Download one from Hugging Face in Settings ▸ Assist."

    public init() {}

    public func availability() async -> ProviderAvailability {
        var records = OfflineModelsStorage.shared.loadInstalledModelRecords()
        // Surface the user's default offline model first so a provider with
        // no explicit model selection resolves to it.
        if let active = UserDefaults.standard.string(forKey: OfflineModelManager.defaultOfflineModelKey),
           let idx = records.firstIndex(where: { $0.modelName == active }), idx != 0 {
            records.insert(records.remove(at: idx), at: 0)
        }
        let models = records.map { record in
            ModelInfo(id: record.modelName,
                      displayName: record.modelName,
                      description: record.sizeDescription)
        }
        return models.isEmpty ? .noModels(hint: Self.noModelsHint) : .ready(models)
    }

    /// Model IDs picked up from the Assist model catalog may carry a
    /// "(HuggingFace)"/"(Offline)" suffix; strip it before matching a record.
    static func canonicalModelName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" (HuggingFace)", " (Offline)", " (Local)"] where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
        }
        return name
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        let rawName = request.model ?? ""
        let requested = Self.canonicalModelName(rawName)
        return eventStream { out in
            var records = OfflineModelsStorage.shared.loadInstalledModelRecords()
            var name = requested.isEmpty ? "" : requested
            if name.isEmpty || !records.contains(where: { $0.modelName == name }) {
                // Fall back to the user's default offline model when the
                // request carries no usable ID (or a stale catalog entry).
                if let fallback = UserDefaults.standard.string(forKey: OfflineModelManager.defaultOfflineModelKey),
                   records.contains(where: { $0.modelName == fallback }) {
                    name = fallback
                }
            }
            guard let record = records.first(where: { $0.modelName == name }) else {
                throw AssistantError.modelNotFound(model: rawName, hint: "Download it from Hugging Face in Settings ▸ Assist.")
            }
            let directory = try OfflineModelsStorage.shared.modelDirectory(for: record.modelName, createIfNeeded: true)
            out.yield(.activity("Loading \(record.modelName)…"))
            try await OfflineModelRunner.shared.loadModel(at: directory)
            try await OfflineModelRunner.shared.streamResponse(prompt: request.flattenedPrompt) { token in
                out.yield(.text(token))
            }
            out.yield(.finished(nil))
        }
    }
}
