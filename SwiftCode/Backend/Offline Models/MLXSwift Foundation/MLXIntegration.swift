import Foundation
import MLX
import MLXNN
import MLXOptimizers
import MLXRandom

/// Centralized MLX bootstrap and validation utilities.
enum MLXIntegration {
    /// Ensures MLX modules are linked into the application binary and available at runtime.
    ///
    /// The implementation intentionally references symbols from multiple MLX packages
    /// so that SPM/Xcode will resolve and link all configured products.
    static func validateRuntime() {
        _ = Adam(learningRate: 1e-3)
        _ = GELU()
        MLXRandom.seed(42)
    }
}

/// Common abstraction for loaded offline models.
protocol OfflineLanguageModel {
    func generate(tokens: [Int]) -> AsyncThrowingStream<Int, Error>
}

/// Common abstraction for tokenizers.
protocol OfflineTokenizer {
    func encode(text: String) -> [Int]
    func decode(tokens: [Int]) -> String
}

/// Factory for creating and managing MLX-backed models and tokenizers.
final class LLMModelFactory {
    static let shared = LLMModelFactory()

    private init() {
        MLXIntegration.validateRuntime()
    }

    func loadModel(from directory: URL) async throws -> (OfflineLanguageModel, OfflineTokenizer) {
        let configuration = try ModelConfiguration.load(from: directory)
        return try await StubOfflineModelLoader.load(configuration: configuration)
    }
}

struct ModelConfiguration {
    let modelDirectory: URL

    static func load(from directory: URL) throws -> ModelConfiguration {
        let configFile = directory.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            throw NSError(
                domain: "LLMModelFactory",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing config.json in model directory: \(directory.path)"]
            )
        }

        return ModelConfiguration(modelDirectory: directory)
    }
}

/// Placeholder loader used until a concrete MLX model runtime is wired to specific model families.
enum StubOfflineModelLoader {
    static func load(configuration: ModelConfiguration) async throws -> (OfflineLanguageModel, OfflineTokenizer) {
        throw NSError(
            domain: "StubOfflineModelLoader",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "MLX Swift packages are integrated. Add model-family specific loader implementation for \(configuration.modelDirectory.lastPathComponent)."]
        )
    }
}
