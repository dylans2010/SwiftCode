import Foundation

struct AgentMemory: Codable {
    var projectArchitecture: String = ""
    var importantFiles: [String] = []
    var dependencies: [String] = []
    var codePatterns: [String] = []
    var lastUpdated: Date = Date()
}
