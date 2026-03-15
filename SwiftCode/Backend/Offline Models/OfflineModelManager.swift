import Foundation

struct InstalledOfflineModelRecord: Identifiable, Codable {
    var id: String { modelName }
    let modelName: String
    let provider: String
    let size: String
    let installDate: Date
    let localModelPath: String
}

@MainActor
final class OfflineModelManager: ObservableObject {
    static let shared = OfflineModelManager()

    @Published var installedModels: [OfflineModelMetadata] = []
    @Published var installedModelRecords: [InstalledOfflineModelRecord] = []
    @Published var downloadingModels: Set<String> = []

    private let modelsDir: URL
    private let metadataPlistURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDir = appSupport.appendingPathComponent("SwiftCode/OfflineModels")
        metadataPlistURL = modelsDir.appendingPathComponent("installed-models.plist")
        ensureDirectory()
        loadInstalledModels()
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
    }

    func loadInstalledModels() {
        installedModelRecords = loadMetadataFromPlist()
        installedModels = installedModelRecords.map { record in
            OfflineModelMetadata(
                modelName: record.modelName,
                providerName: record.provider,
                description: "Locally stored model",
                modelSize: record.size,
                tags: ["offline", "installed"],
                downloadCount: 0,
                modelURL: URL(fileURLWithPath: record.localModelPath),
                files: [],
                isQuantized: false
            )
        }
    }

    func registerInstalledModel(from model: OfflineModelMetadata, localPath: URL, installDate: Date = Date()) {
        var records = loadMetadataFromPlist().filter { $0.modelName != model.modelName }
        let newRecord = InstalledOfflineModelRecord(
            modelName: model.modelName,
            provider: model.providerName,
            size: model.modelSize,
            installDate: installDate,
            localModelPath: localPath.path
        )
        records.append(newRecord)
        records.sort { $0.installDate > $1.installDate }
        persist(records)
        loadInstalledModels()
    }

    func isModelInstalled(_ modelName: String) -> Bool {
        installedModelRecords.contains { $0.modelName == modelName }
    }

    func removeModel(_ model: OfflineModelMetadata) {
        let url = modelDirectory(for: model.modelName)
        try? FileManager.default.removeItem(at: url)

        var records = loadMetadataFromPlist()
        records.removeAll { $0.modelName == model.modelName }
        persist(records)
        loadInstalledModels()
    }

    func modelDirectory(for modelName: String) -> URL {
        modelsDir.appendingPathComponent(modelName)
    }

    private func loadMetadataFromPlist() -> [InstalledOfflineModelRecord] {
        guard let data = try? Data(contentsOf: metadataPlistURL) else {
            return []
        }

        do {
            return try PropertyListDecoder().decode([InstalledOfflineModelRecord].self, from: data)
        } catch {
            return []
        }
    }

    private func persist(_ records: [InstalledOfflineModelRecord]) {
        do {
            let data = try PropertyListEncoder().encode(records)
            try data.write(to: metadataPlistURL, options: .atomic)
        } catch {
            print("Failed to persist offline model metadata plist: \(error)")
        }
    }
}
