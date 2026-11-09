import Foundation
import Observation

public enum HardwareAcceleration: String, CaseIterable, Identifiable, Codable, Sendable {
    case metal = "Metal (GPU)"
    case ane = "Apple Silicon Neural Engine"
    case cpu = "CPU (Universal)"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .metal: return "sparkles.rectangle.stack.fill"
        case .ane: return "cpu.fill"
        case .cpu: return "desktopcomputer"
        }
    }

    public var description: String {
        switch self {
        case .metal: return "Accelerated by Metal GPU compute pipelines for maximum batch throughput."
        case .ane: return "Optimized for Apple Neural Engine hardware with low power and high energy efficiency."
        case .cpu: return "Universal multithreaded CPU execution without GPU dependency."
        }
    }
}

@MainActor
@Observable
public final class OfflineModelRunner {
    public static let shared = OfflineModelRunner()
    private init() {}

    public static let hardwareAccelerationKey = "SwiftCode.offline.hardwareAcceleration"

    public var hardwareAcceleration: HardwareAcceleration {
        get {
            if let saved = UserDefaults.standard.string(forKey: Self.hardwareAccelerationKey),
               let mode = HardwareAcceleration(rawValue: saved) {
                return mode
            }
            return .metal
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.hardwareAccelerationKey)
        }
    }

    private let container = MLXModelContainer()
    private var loadedModelPath: String?

    public var isModelLoaded: Bool { container.isLoaded }
    public var loadedModelName: String { container.modelName }

    public func loadModel(at url: URL) async throws {
        if loadedModelPath == url.path && container.isLoaded { return }

        try await OfflineModelConverter.shared.convertIfNecessary(at: url)
        try await container.loadModel(at: url)
        loadedModelPath = url.path
    }

    public func generateResponse(prompt: String) async throws -> String {
        var response = ""
        try await streamResponse(prompt: prompt) { token in
            response += token
        }
        return response
    }

    public func streamResponse(prompt: String, onToken: @escaping (String) -> Void) async throws {
        guard container.isLoaded else {
            throw MLXRuntimeError.modelNotLoaded
        }

        try await container.generate(prompt: prompt, onToken: onToken)
    }

    public func unloadModel() {
        container.reset()
        loadedModelPath = nil
    }
}
