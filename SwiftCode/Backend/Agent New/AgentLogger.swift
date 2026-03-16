import Foundation
import Combine

struct ToolLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let toolName: String
    let source: ToolSource
    let arguments: [String: Any]
    let duration: TimeInterval
    let error: String?
}

@MainActor
final class AgentLogger: ObservableObject {
    static let shared = AgentLogger()
    private init() {}

    @Published var toolLogs: [ToolLogEntry] = []

    func logToolCall(name: String, source: ToolSource, arguments: [String: Any], duration: TimeInterval, error: String? = nil) {
        let entry = ToolLogEntry(
            timestamp: Date(),
            toolName: name,
            source: source,
            arguments: arguments,
            duration: duration,
            error: error
        )
        toolLogs.append(entry)

        print("[\(source.rawValue)] \(name) executed in \(String(format: "%.3f", duration))s")
    }
}
