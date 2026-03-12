import Foundation

struct GitHubReleaseCheckResult {
    let latestBuildNumber: Int
    let latestTag: String
    let releaseURL: URL?

    func isUpdateAvailable(currentBuild: Int) -> Bool {
        latestBuildNumber > currentBuild
    }
}

final class GitHubReleaseCheck {
    static let shared = GitHubReleaseCheck()
    private init() {}

    private let session = URLSession.shared
    private let buildPattern = #"build-(\d+)"#

    func checkLatestBuild(owner: String = "dylans2010", repo: String = "SwiftCode") async throws -> GitHubReleaseCheckResult {
        var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")
        components?.queryItems = [URLQueryItem(name: "per_page", value: "30")]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SwiftCode", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let releases = try JSONDecoder().decode([GitHubReleaseDTO].self, from: data)

        let parsed = releases.compactMap { release -> (Int, GitHubReleaseDTO)? in
            guard let build = extractBuildNumber(from: release.tagName) else { return nil }
            return (build, release)
        }

        guard let latest = parsed.max(by: { $0.0 < $1.0 }) else {
            throw NSError(domain: "GitHubReleaseCheck", code: 404, userInfo: [NSLocalizedDescriptionKey: "No build-* releases were found."])
        }

        return GitHubReleaseCheckResult(
            latestBuildNumber: latest.0,
            latestTag: latest.1.tagName,
            releaseURL: URL(string: latest.1.htmlURL)
        )
    }

    private func extractBuildNumber(from tag: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: buildPattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(location: 0, length: tag.utf16.count)
        guard let match = regex.firstMatch(in: tag, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: tag) else {
            return nil
        }

        return Int(tag[valueRange])
    }
}

private struct GitHubReleaseDTO: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
