import Foundation
import Testing
@testable import SpacesEngine


enum SpacesTestSupport {
    static func tempDir(_ name: String = UUID().uuidString) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spaces-tests-\(name)", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func makeRepo(_ name: String = UUID().uuidString) throws -> (Repository, SpacesAPI, URL) {
        let url = try tempDir(name)
        let repo = try Repository.create(
            at: url,
            user: SpacesConfig.User(name: "Test User", email: "test@example.com"))
        return (repo, SpacesAPI(repo: repo), url)
    }

    static func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    
    @discardableResult
    static func commitFiles(_ api: SpacesAPI, _ files: [String: String],
                            message: String) throws -> ObjectID {
        for (path, contents) in files {
            try write(contents, to: api.repo.worktreeURL.appendingPathComponent(path))
        }
        _ = try api.stageAll()
        return try api.commit(message: message).oid
    }
}
