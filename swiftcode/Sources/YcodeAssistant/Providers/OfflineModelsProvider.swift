import Foundation



public struct OfflineModelsProvider: AssistantProvider {
    public let kind = ProviderKind.offlineModels

    static let noModelsHint = "No offline models are installed. Download one from Hugging Face in Settings ▸ Assist."

    public init() {}

    public func availability() async -> ProviderAvailability {
        var records = OfflineModelsStorage.shared.loadInstalledModelRecords()
        
        
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

    
    
    static func canonicalModelName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" (HuggingFace)", " (Offline)", " (Local)"] where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
        }
        return name
    }

    public func send(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error> {
        let request = AssistUniversalModelContext.augment(request, compact: true)
        let rawName = request.model ?? ""
        let requested = Self.canonicalModelName(rawName)
        return eventStream { out in
            var records = OfflineModelsStorage.shared.loadInstalledModelRecords()
            var name = requested.isEmpty ? "" : requested
            if name.isEmpty || !records.contains(where: { $0.modelName == name }) {
                
                
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
