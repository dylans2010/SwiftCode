import Foundation

struct UniversalLoadedModel {
    let model: OfflineLanguageModel
    let tokenizer: OfflineTokenizer
}

enum UniversalModelLoaderError: LocalizedError {
    case missingConfig(URL)
    case invalidConfig(URL)
    case missingModelType(URL)
    case unsupportedArchitecture(String)
    case missingWeights(URL)
    case invalidTokenizer(URL)
    case missingTokenizer(URL)
    case runtimeUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .missingConfig(directory):
            return "Missing config.json in model directory: \(directory.path)"
        case let .invalidConfig(configURL):
            return "Could not parse config.json at: \(configURL.path)"
        case let .missingModelType(configURL):
            return "config.json is missing required field \"model_type\": \(configURL.path)"
        case let .unsupportedArchitecture(modelType):
            return "Unsupported HuggingFace architecture: \(modelType). Add a router entry in UniversalModelLoader.ArchitectureRegistry."
        case let .missingWeights(directory):
            return "Missing model weights in \(directory.path). Expected model.safetensors or model-00001-of-XXXXX.safetensors shards."
        case let .invalidTokenizer(tokenizerURL):
            return "Tokenizer file is corrupt or unreadable: \(tokenizerURL.path)"
        case let .missingTokenizer(directory):
            return "Missing tokenizer in \(directory.path). Expected tokenizer.json or tokenizer.model (with tokenizer_config.json fallback)."
        case let .runtimeUnavailable(details):
            return details
        }
    }
}

struct UniversalModelLoader {
    func loadModel(from directory: URL) async throws -> UniversalLoadedModel {
        let config = try loadConfig(from: directory)
        let architecture = try ArchitectureRegistry.resolve(modelType: config.modelType)
        let tokenizer = try loadTokenizer(from: directory)
        let weights = try detectWeights(in: directory)
        let model = try await architecture.buildModel(config: config, weightSource: weights)

        return UniversalLoadedModel(model: model, tokenizer: tokenizer)
    }

    private func loadConfig(from directory: URL) throws -> HuggingFaceModelConfig {
        let configURL = directory.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw UniversalModelLoaderError.missingConfig(directory)
        }

        do {
            let data = try Data(contentsOf: configURL)
            let rawConfig = try JSONDecoder().decode(RawConfig.self, from: data)
            guard let modelType = rawConfig.modelType?.trimmingCharacters(in: .whitespacesAndNewlines), !modelType.isEmpty else {
                throw UniversalModelLoaderError.missingModelType(configURL)
            }

            return HuggingFaceModelConfig(modelDirectory: directory, modelType: modelType, rawJSON: data)
        } catch let error as UniversalModelLoaderError {
            throw error
        } catch {
            throw UniversalModelLoaderError.invalidConfig(configURL)
        }
    }

    private func loadTokenizer(from directory: URL) throws -> OfflineTokenizer {
        let tokenizerJSON = directory.appendingPathComponent("tokenizer.json")
        let tokenizerModel = directory.appendingPathComponent("tokenizer.model")
        let tokenizerConfig = directory.appendingPathComponent("tokenizer_config.json")

        if FileManager.default.fileExists(atPath: tokenizerJSON.path) {
            return try JSONBackedTokenizer.load(from: tokenizerJSON)
        }

        if FileManager.default.fileExists(atPath: tokenizerModel.path) {
            return FileBackedTokenizer(tokenizerFile: tokenizerModel)
        }

        if FileManager.default.fileExists(atPath: tokenizerConfig.path) {
            return try JSONBackedTokenizer.load(from: tokenizerConfig)
        }

        throw UniversalModelLoaderError.missingTokenizer(directory)
    }

    private func detectWeights(in directory: URL) throws -> WeightSource {
        let fileManager = FileManager.default
        let singleFile = directory.appendingPathComponent("model.safetensors")
        if fileManager.fileExists(atPath: singleFile.path) {
            return .single(singleFile)
        }

        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let shards = contents
            .filter { $0.lastPathComponent.range(of: #"^model-\d{5}-of-\d{5}\.safetensors$"#, options: .regularExpression) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        if !shards.isEmpty {
            return .sharded(shards)
        }

        throw UniversalModelLoaderError.missingWeights(directory)
    }
}

private struct RawConfig: Decodable {
    let modelType: String?

    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
    }
}

struct HuggingFaceModelConfig {
    let modelDirectory: URL
    let modelType: String
    let rawJSON: Data
}

enum WeightSource {
    case single(URL)
    case sharded([URL])

    var files: [URL] {
        switch self {
        case let .single(file):
            return [file]
        case let .sharded(files):
            return files
        }
    }
}

private enum ArchitectureRegistry {
    typealias Builder = (HuggingFaceModelConfig, WeightSource) async throws -> OfflineLanguageModel

    static func resolve(modelType: String) throws -> RegisteredArchitecture {
        guard let architecture = mapping[modelType.lowercased()] else {
            throw UniversalModelLoaderError.unsupportedArchitecture(modelType)
        }

        return architecture
    }

    private static let mapping: [String: RegisteredArchitecture] = [
        "llama": RegisteredArchitecture(name: "llama", builder: GenericMLXArchitectureBuilders.llama),
        "mistral": RegisteredArchitecture(name: "mistral", builder: GenericMLXArchitectureBuilders.mistral),
        "qwen": RegisteredArchitecture(name: "qwen", builder: GenericMLXArchitectureBuilders.qwen),
        "phi": RegisteredArchitecture(name: "phi", builder: GenericMLXArchitectureBuilders.phi),
        "gpt_neox": RegisteredArchitecture(name: "gpt_neox", builder: GenericMLXArchitectureBuilders.gptNeoX),
        "falcon": RegisteredArchitecture(name: "falcon", builder: GenericMLXArchitectureBuilders.falcon),
        "gemma": RegisteredArchitecture(name: "gemma", builder: GenericMLXArchitectureBuilders.gemma)
    ]
}

private struct RegisteredArchitecture {
    let name: String
    let builder: ArchitectureRegistry.Builder

    func buildModel(config: HuggingFaceModelConfig, weightSource: WeightSource) async throws -> OfflineLanguageModel {
        try await builder(config, weightSource)
    }
}

private enum GenericMLXArchitectureBuilders {
    static func llama(config: HuggingFaceModelConfig, weights: WeightSource) async throws -> OfflineLanguageModel {
        try runtimeUnavailable(architecture: "llama", config: config, weights: weights)
    }

    static func mistral(config: HuggingFaceModelConfig, weights: WeightSource) async throws -> OfflineLanguageModel {
        try runtimeUnavailable(architecture: "mistral", config: config, weights: weights)
    }

    static func qwen(config: HuggingFaceModelConfig, weights: WeightSource) async throws -> OfflineLanguageModel {
        try runtimeUnavailable(architecture: "qwen", config: config, weights: weights)
    }

    static func phi(config: HuggingFaceModelConfig, weights: WeightSource) async throws -> OfflineLanguageModel {
        try runtimeUnavailable(architecture: "phi", config: config, weights: weights)
    }

    static func gptNeoX(config: HuggingFaceModelConfig, weights: WeightSource) async throws -> OfflineLanguageModel {
        try runtimeUnavailable(architecture: "gpt_neox", config: config, weights: weights)
    }

    static func falcon(config: HuggingFaceModelConfig, weights: WeightSource) async throws -> OfflineLanguageModel {
        try runtimeUnavailable(architecture: "falcon", config: config, weights: weights)
    }

    static func gemma(config: HuggingFaceModelConfig, weights: WeightSource) async throws -> OfflineLanguageModel {
        try runtimeUnavailable(architecture: "gemma", config: config, weights: weights)
    }

    private static func runtimeUnavailable(architecture: String, config: HuggingFaceModelConfig, weights: WeightSource) throws -> OfflineLanguageModel {
        throw UniversalModelLoaderError.runtimeUnavailable(
            "Detected architecture \"\(architecture)\" for model \(config.modelDirectory.lastPathComponent), but no MLX runtime adapter is currently linked for this architecture. Detected \(weights.files.count) weight file(s)."
        )
    }
}

private struct JSONBackedTokenizer: OfflineTokenizer {
    let text: String

    static func load(from fileURL: URL) throws -> JSONBackedTokenizer {
        do {
            let data = try Data(contentsOf: fileURL)
            _ = try JSONSerialization.jsonObject(with: data)
            return JSONBackedTokenizer(text: String(decoding: data, as: UTF8.self))
        } catch {
            throw UniversalModelLoaderError.invalidTokenizer(fileURL)
        }
    }

    func encode(text: String) -> [Int] {
        Array(text.utf8).map(Int.init)
    }

    func decode(tokens: [Int]) -> String {
        let scalars = tokens.compactMap(UnicodeScalar.init).map(Character.init)
        return String(scalars)
    }
}

private struct FileBackedTokenizer: OfflineTokenizer {
    let tokenizerFile: URL

    func encode(text: String) -> [Int] {
        Array(text.utf8).map(Int.init)
    }

    func decode(tokens: [Int]) -> String {
        let scalars = tokens.compactMap(UnicodeScalar.init).map(Character.init)
        return String(scalars)
    }
}
