import Foundation
import Testing
@testable import SpacesEngine

@Suite struct DetectionTests {
    @Test func validRepositoryDetected() throws {
        let (_, _, url) = try SpacesTestSupport.makeRepo()
        let detection = Repository.detect(at: url)
        #expect(detection == .spaces(valid: true))
        #expect(SpacesAPI.detectRepository(at: url) == .spaces(valid: true))
    }

    @Test func corruptConfigDetectedAsInvalid() throws {
        let (_, _, url) = try SpacesTestSupport.makeRepo()
        let configURL = url.appendingPathComponent(".spaces").appendingPathComponent("config.json")
        try Data("{ this is not valid json".utf8).write(to: configURL)
        let detection = Repository.detect(at: url)
        guard case .spacesInvalid(let reason) = detection else {
            Issue.record("expected spacesInvalid, got \(detection)")
            return
        }
        #expect(reason.contains("config.json"))
    }

    @Test func newerFormatVersionDetected() throws {
        let (_, _, url) = try SpacesTestSupport.makeRepo()
        let configURL = url.appendingPathComponent(".spaces").appendingPathComponent("config.json")
        var config = try JSONDecoder().decode(SpacesConfig.self, from: Data(contentsOf: configURL))
        config.version = RepositoryFormat.formatVersion + 1
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(config).write(to: configURL)
        #expect(Repository.detect(at: url) == .unsupportedVersion(version: RepositoryFormat.formatVersion + 1))
    }

    @Test func missingObjectsDirectoryDetectedAsInvalid() throws {
        let (_, _, url) = try SpacesTestSupport.makeRepo()
        try FileManager.default.removeItem(at: url.appendingPathComponent(".spaces").appendingPathComponent("objects"))
        let detection = Repository.detect(at: url)
        guard case .spacesInvalid(let reason) = detection else {
            Issue.record("expected spacesInvalid, got \(detection)")
            return
        }
        #expect(reason.contains("objects"))
    }

    @Test func missingRefsDirectoryDetectedAsInvalid() throws {
        let (_, _, url) = try SpacesTestSupport.makeRepo()
        try FileManager.default.removeItem(at: url.appendingPathComponent(".spaces").appendingPathComponent("refs"))
        let detection = Repository.detect(at: url)
        guard case .spacesInvalid(let reason) = detection else {
            Issue.record("expected spacesInvalid, got \(detection)")
            return
        }
        #expect(reason.contains("refs"))
    }

    @Test func gitOnlyDirectoryDetectedAsGit() throws {
        let url = try SpacesTestSupport.tempDir()
        try FileManager.default.createDirectory(at: url.appendingPathComponent(".git"), withIntermediateDirectories: true)
        #expect(Repository.detect(at: url) == .git)
    }

    @Test func emptyDirectoryDetectedAsEmpty() throws {
        let url = try SpacesTestSupport.tempDir()
        #expect(Repository.detect(at: url) == .empty)
    }

    @Test func brokenSpacesDirectoryIsNeverReportedAsGit() throws {
        let url = try SpacesTestSupport.tempDir()
        try FileManager.default.createDirectory(at: url.appendingPathComponent(".spaces"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: url.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let detection = Repository.detect(at: url)
        guard case .spacesInvalid(let reason) = detection else {
            Issue.record("expected spacesInvalid, got \(detection)")
            return
        }
        #expect(reason.contains("config.json"))
    }
}
