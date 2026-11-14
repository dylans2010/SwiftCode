import Foundation

public struct GitDiffHunk: Identifiable, Sendable, Codable, Equatable, Hashable {
    public let id: UUID
    public let filePath: String?
    public let header: String
    public let lines: [String]

    public init(id: UUID = UUID(), filePath: String? = nil, header: String, lines: [String]) {
        self.id = id
        self.filePath = filePath
        self.header = header
        self.lines = lines
    }
}
