import Foundation

@MainActor
final class OfflineModelManager: ObservableObject {
    static let shared = OfflineModelManager()

    @Published var installedModels: [OfflineModelMetadata] = []
    @Published var downloadingModels: Set<String> = []

    private let modelsDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDir = appSupport.appendingPathComponent("SwiftCode/OfflineModels")
        ensureDirectory()
        loadInstalledModels()
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
    }

    private func loadInstalledModels() {
        // In a real app, we'd store metadata in a plist/database.
        // For now, we'll scan the directory.
        guard let contents = try? FileManager.default.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: nil) else { return }

        var installed: [OfflineModelMetadata] = []
        for url in contents {
            if url.hasDirectoryPath {
                // Mock metadata for discovered folders
                installed.append(OfflineModelMetadata(
                    modelName: url.lastPathComponent,
                    providerName: "Local",
                    description: "Locally stored model",
                    modelSize: "Unknown",
                    tags: ["offline"],
                    downloadCount: 0,
                    modelURL: url,
                    files: [],
                    isQuantized: false
                ))
            }
        }
        installedModels = installed
    }

    func isModelInstalled(_ modelName: String) -> Bool {
        installedModels.contains { $0.modelName == modelName }
    }

    func removeModel(_ model: OfflineModelMetadata) {
        let url = modelsDir.appendingPathComponent(model.modelName)
        try? FileManager.default.removeItem(at: url)
        installedModels.removeAll { $0.modelName == model.modelName }
    }

    func modelDirectory(for modelName: String) -> URL {
        modelsDir.appendingPathComponent(modelName)
    }
}
