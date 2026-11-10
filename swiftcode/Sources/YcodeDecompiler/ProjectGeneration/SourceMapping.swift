import Foundation

public struct SourceMapping: Sendable, Codable {
    public struct Entry: Sendable, Codable {
        public var address: UInt64
        public var file: String
        public var line: Int
        public var function: String?
        public var quality: ReconstructionQuality

        public init(address: UInt64, file: String, line: Int, function: String? = nil,
                    quality: ReconstructionQuality) {
            self.address = address
            self.file = file
            self.line = line
            self.function = function
            self.quality = quality
        }
    }

    public var entries: [Entry]
    public var generatedAt: Date
    public var originalSHA256: String
    public var originalFileName: String

    public init(entries: [Entry] = [], generatedAt: Date = Date(), originalSHA256: String = "",
                originalFileName: String = "") {
        self.entries = entries
        self.generatedAt = generatedAt
        self.originalSHA256 = originalSHA256
        self.originalFileName = originalFileName
    }

    public func entry(forAddress address: UInt64) -> Entry? {
        entries.first(where: { $0.address == address })
    }

    public func entry(containing address: UInt64) -> Entry? {
        entries.filter { $0.address <= address }.max(by: { $0.address < $1.address })
    }

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}
