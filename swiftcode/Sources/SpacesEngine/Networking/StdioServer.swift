import Foundation

public final class SpacesStdioServer: @unchecked Sendable {
    public let handler: SpacesProtocolHandler

    public init(repo: Repository) {
        self.handler = SpacesProtocolHandler(repo: repo)
    }

    public init(handler: SpacesProtocolHandler) {
        self.handler = handler
    }

    public func handleLine(_ line: Data) -> Data {
        let response: [String: Any]
        do {
            guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                throw SpacesError.protocolError("expected a JSON object")
            }
            response = try handler.handle(message)
        } catch {
            let detail = (error as? SpacesError)?.errorDescription ?? error.localizedDescription
            response = ["v": RepositoryFormat.protocolVersion, "op": "error", "error": detail]
        }
        var out = (try? JSONSerialization.data(withJSONObject: response))
            ?? Data("{\"op\":\"error\"}".utf8)
        out.append(10)
        return out
    }

    public func run(input: FileHandle = FileHandle.standardInput,
                    output: FileHandle = FileHandle.standardOutput) {
        var buffer = Data()
        while true {
            let chunk = input.availableData
            if chunk.isEmpty {
                break
            }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer.prefix(upTo: newline))
                buffer.removeFirst(newline + 1)
                if line.isEmpty {
                    continue
                }
                output.write(handleLine(line))
            }
        }
        if !buffer.isEmpty {
            output.write(handleLine(buffer))
        }
    }
}
