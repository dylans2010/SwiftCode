import Foundation

final class ToolConnectionExecutor {
    static let shared = ToolConnectionExecutor()
    private init() {}

    func execute(_ connection: CustomAgentConnection, parameters: [String: Any]) async throws -> String {
        AssistCapabilityExecutor.executeIfNeeded(
            kind: .connection,
            name: connection.name,
            identifiers: connection.identificationTags,
            payload: parameters.reduce(into: [String: String]()) { partialResult, entry in
                partialResult[entry.key] = "\(entry.value)"
            }
        )

        guard !connection.apiEndpoint.isEmpty,
              let url = URL(string: connection.apiEndpoint) else {
            throw NSError(domain: "ToolConnectionExecutor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ToolConnectionExecutor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Tool execution failed"])
        }

        return String(data: data, encoding: .utf8) ?? "Empty response"
    }
}
