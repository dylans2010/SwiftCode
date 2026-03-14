import Foundation

struct OfflineModelMetadata: Identifiable, Codable {
    var id: String { modelName }
    let modelName: String
    let providerName: String
    let description: String
    let modelSize: String
    let tags: [String]
    let downloadCount: Int
    let modelURL: URL
    let files: [String]
    let isQuantized: Bool
}
