import Foundation

final class HuggingFaceAPI {
    static let shared = HuggingFaceAPI()
    private init() {}

    private let baseURL = URL(string: "https://huggingface.co/api/models")!
    private let cacheKey = "huggingface.models.cache"
    private let cacheTimestampKey = "huggingface.models.cache.timestamp"
    private let cacheDuration: TimeInterval = 3600 // 1 hour

    func fetchModels(forceRefresh: Bool = false) async throws -> [OfflineModelMetadata] {
        if !forceRefresh, let cached = getCachedModels() {
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
        let models = try await mapModels(hfModels)

        cacheModels(models)
        return models
    }

    private func mapModels(_ hfModels: [HFModelResponse]) async throws -> [OfflineModelMetadata] {
        var mapped: [OfflineModelMetadata] = []

        for hf in hfModels {
            let details = try? await fetchModelDetails(modelId: hf.modelId)
            let totalBytes = details?.siblingFiles?.compactMap { file in
                file.lfs?.size ?? file.size
            }.reduce(0, +)

            let files = details?.siblingFiles?.map(\.filename) ?? []
            let resolvedSize = totalBytes.map(Self.formatBytes) ?? "Unknown"

            mapped.append(
                OfflineModelMetadata(
                    modelName: hf.modelId,
                    providerName: hf.author ?? "Unknown",
                    description: "Hugging Face model: \(hf.modelId)",
                    modelSize: resolvedSize,
                    tags: hf.tags ?? [],
                    downloadCount: hf.downloads ?? 0,
                    modelURL: URL(string: "https://huggingface.co/\(hf.modelId)")!,
                    files: files,
                    isQuantized: hf.tags?.contains("quantized") ?? false
                )
            )
        }

        return mapped
    }

    private func fetchModelDetails(modelId: String) async throws -> HFModelDetailsResponse {
        guard let encoded = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://huggingface.co/api/models/\(encoded)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(HFModelDetailsResponse.self, from: data)
    }

    private static func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
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

private struct HFModelDetailsResponse: Decodable {
    let siblingFiles: [HFModelFile]?

    enum CodingKeys: String, CodingKey {
        case siblingFiles = "siblings"
    }
}

private struct HFModelFile: Decodable {
    let filename: String
    let size: Int?
    let lfs: HFModelLFS?

    enum CodingKeys: String, CodingKey {
        case filename = "rfilename"
        case size
        case lfs
    }
}

private struct HFModelLFS: Decodable {
    let size: Int?
}
