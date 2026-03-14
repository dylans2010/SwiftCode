import Foundation

final class HuggingFaceAPI {
    static let shared = HuggingFaceAPI()
    private init() {}

    private let baseURL = URL(string: "https://huggingface.co/api/models")!
    private let cacheKey = "huggingface.models.cache"
    private let cacheTimestampKey = "huggingface.models.cache.timestamp"
    private let cacheDuration: TimeInterval = 3600 // 1 hour

    func fetchModels() async throws -> [OfflineModelMetadata] {
        if let cached = getCachedModels() {
            return cached
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "search", value: "mlx"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "20")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let hfModels = try JSONDecoder().decode([HFModelResponse].self, from: data)
        let models = hfModels.map { hf in
            OfflineModelMetadata(
                modelName: hf.modelId,
                providerName: hf.author ?? "Unknown",
                description: "Hugging Face model: \(hf.modelId)",
                modelSize: "Unknown", // Size often requires additional API calls
                tags: hf.tags ?? [],
                downloadCount: hf.downloads ?? 0,
                modelURL: URL(string: "https://huggingface.co/\(hf.modelId)")!,
                files: [], // Files list also requires separate call
                isQuantized: hf.tags?.contains("quantized") ?? false
            )
        }

        cacheModels(models)
        return models
    }

    private func cacheModels(_ models: [OfflineModelMetadata]) {
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
        }
    }

    private func getCachedModels() -> [OfflineModelMetadata]? {
        let timestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
        guard Date().timeIntervalSince1970 - timestamp < cacheDuration else { return nil }

        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let models = try? JSONDecoder().decode([OfflineModelMetadata].self, from: data) else {
            return nil
        }
        return models
    }
}

private struct HFModelResponse: Decodable {
    let modelId: String
    let author: String?
    let downloads: Int?
    let tags: [String]?
}
