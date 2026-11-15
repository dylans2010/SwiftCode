import ArgumentParser
import Dispatch
import Foundation
import SpacesEngine

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private func cExit(_ code: Int32) -> Never {
    #if canImport(Darwin)
    Darwin.exit(code)
    #else
    Glibc.exit(code)
    #endif
}


struct Serve: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Serve a repository over spaces-proto/1 (NDJSON on stdio; --http-port serves HTTP instead)")
    @Argument var path: String
    @Option(name: .long) var httpPort: Int?
    @OptionGroup var global: GlobalOptions
    func run() throws {
        try SpacesOutput.apply(global, command: "Serve")
        var location = URL(fileURLWithPath: path)
        if location.lastPathComponent == RepositoryFormat.metadataDirectoryName {
            location = location.deletingLastPathComponent()
        }
        let repo = try Repository.open(at: location)
        if let port = httpPort {
            guard (0...65535).contains(port) else {
                throw SpacesError.invalidArgument("bad http port: \(port)")
            }
            let server = SpacesHttpServer(repo: repo, port: UInt16(port))
            try server.start()
            FileHandle.standardError.write(
                "spaces: serving \(repo.worktreeURL.path) on http://127.0.0.1:\(server.boundPort)\n"
                    .data(using: .utf8)!)
            let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            let terminate = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
            _ = signal(SIGINT, SIG_IGN)
            _ = signal(SIGTERM, SIG_IGN)
            interrupt.setEventHandler {
                server.stop()
                cExit(0)
            }
            terminate.setEventHandler {
                server.stop()
                cExit(0)
            }
            interrupt.resume()
            terminate.resume()
            dispatchMain()
        } else {
            SpacesStdioServer(repo: repo).run()
        }
    }
}
