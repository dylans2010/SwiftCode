import Foundation

// MARK: - GitHub API Service

final class GitHubService {
    static let shared = GitHubService()
    private init() {}

    private let baseURL = URL(string: "https://api.github.com")!

    private var token: String? {
        KeychainService.shared.get(forKey: KeychainService.githubToken)
    }

    private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - Auth Check

    func getAuthenticatedUser() async throws -> GitHubUser {
        guard token != nil else { throw GitHubError.missingToken }
        let url = baseURL.appendingPathComponent("user")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }

    // MARK: - Create Repository

    func createRepository(name: String, description: String, isPrivate: Bool) async throws -> GitHubRepo {
        guard token != nil else { throw GitHubError.missingToken }

        let url = baseURL.appendingPathComponent("user/repos")
        var request = authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "name": name,
            "description": description,
            "private": isPrivate,
            "auto_init": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(GitHubRepo.self, from: data)
    }

    // MARK: - Push File (create or update)

    func pushFile(
        owner: String,
        repo: String,
        path: String,
        content: String,
        message: String,
        sha: String? = nil
    ) async throws {
        guard token != nil else { throw GitHubError.missingToken }

        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw GitHubError.invalidPath
        }
        let url = baseURL
            .appendingPathComponent("repos")
            .appendingPathComponent(owner)
            .appendingPathComponent(repo)
            .appendingPathComponent("contents")
            .appendingPathComponent(encodedPath)

        var request = authorizedRequest(url: url, method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let base64Content = Data(content.utf8).base64EncodedString()
        var body: [String: Any] = [
            "message": message,
            "content": base64Content
        ]
        if let sha { body["sha"] = sha }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Push All Project Files

    func pushProject(_ project: Project, owner: String, repo: String, commitMessage: String) async throws {
        let allFiles = collectFiles(from: project.files)
        for fileNode in allFiles {
            let fileURL = project.directoryURL.appendingPathComponent(fileNode.path)
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let existingSHA = try? await getFileSHA(owner: owner, repo: repo, path: fileNode.path)
            try await pushFile(
                owner: owner,
                repo: repo,
                path: fileNode.path,
                content: content,
                message: commitMessage,
                sha: existingSHA
            )
        }
    }

    private func collectFiles(from nodes: [FileNode]) -> [FileNode] {
        nodes.flatMap { node -> [FileNode] in
            if node.isDirectory { return collectFiles(from: node.children) }
            return [node]
        }
    }

    // MARK: - Get File SHA

    func getFileSHA(owner: String, repo: String, path: String) async throws -> String? {
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        let url = baseURL
            .appendingPathComponent("repos/\(owner)/\(repo)/contents/\(encodedPath)")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        let json = try JSONDecoder().decode(GitHubFileContent.self, from: data)
        return json.sha
    }

    // MARK: - List Workflow Runs

    func listWorkflowRuns(owner: String, repo: String) async throws -> [WorkflowRun] {
        guard token != nil else { throw GitHubError.missingToken }
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/actions/runs")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(WorkflowRunsResponse.self, from: data)
        return result.workflowRuns
    }

    // MARK: - Get Workflow Run Logs URL

    func getWorkflowRunLogsURL(owner: String, repo: String, runID: Int) async throws -> URL {
        guard token != nil else { throw GitHubError.missingToken }
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/actions/runs/\(runID)/logs")
        var request = authorizedRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // This endpoint returns a redirect; capture the Location header.
        let session = URLSession(configuration: .default, delegate: NoRedirectDelegate(), delegateQueue: nil)
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 302,
              let locationString = httpResponse.value(forHTTPHeaderField: "Location"),
              let logsURL = URL(string: locationString) else {
            throw GitHubError.noLogsAvailable
        }
        return logsURL
    }

    // MARK: - List Releases

    func listReleases(owner: String, repo: String) async throws -> [GitHubRelease] {
        guard token != nil else { throw GitHubError.missingToken }
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/releases")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GitHubRelease].self, from: data)
    }

    // MARK: - Pull / Download File

    func getFileContent(owner: String, repo: String, path: String) async throws -> String {
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw GitHubError.invalidPath
        }
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/contents/\(encodedPath)")
        let request = authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        let file = try JSONDecoder().decode(GitHubFileContent.self, from: data)
        guard let decoded = Data(base64Encoded: file.content.replacingOccurrences(of: "\n", with: "")),
              let string = String(data: decoded, encoding: .utf8) else {
            throw GitHubError.decodingFailed
        }
        return string
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GitHubError.apiError(statusCode: http.statusCode, body: body)
        }
    }
}

// MARK: - No Redirect Delegate (for log URLs)

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil // Don't follow redirects
    }
}

// MARK: - GitHub Response Models

struct GitHubUser: Decodable {
    let login: String
    let name: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case login, name
        case avatarUrl = "avatar_url"
    }
}

struct GitHubRepo: Decodable {
    let id: Int
    let name: String
    let fullName: String
    let htmlUrl: String
    let cloneUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case cloneUrl = "clone_url"
    }
}

struct GitHubFileContent: Decodable {
    let sha: String
    let content: String
}

struct WorkflowRunsResponse: Decodable {
    let workflowRuns: [WorkflowRun]
}

struct WorkflowRun: Identifiable, Decodable {
    let id: Int
    let name: String?
    let status: String
    let conclusion: String?
    let htmlUrl: String
    let createdAt: Date
    let updatedAt: Date
    let runNumber: Int

    var statusBadge: String {
        switch conclusion ?? status {
        case "success": return "checkmark.circle.fill"
        case "failure": return "xmark.circle.fill"
        case "cancelled": return "slash.circle.fill"
        case "in_progress": return "clock.fill"
        default: return "circle"
        }
    }

    var isRunning: Bool {
        status == "in_progress" || status == "queued"
    }
}

struct GitHubRelease: Identifiable, Decodable {
    let id: Int
    let tagName: String
    let name: String?
    let htmlUrl: String
    let createdAt: Date
    let assets: [GitHubAsset]
}

struct GitHubAsset: Identifiable, Decodable {
    let id: Int
    let name: String
    let browserDownloadUrl: String
    let size: Int
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case missingToken
    case invalidResponse
    case apiError(statusCode: Int, body: String)
    case noLogsAvailable
    case invalidPath
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No GitHub token found. Please add your personal access token in Settings."
        case .invalidResponse:
            return "Received an invalid response from GitHub."
        case let .apiError(code, body):
            return "GitHub API error \(code): \(body)"
        case .noLogsAvailable:
            return "No logs are available for this workflow run."
        case .invalidPath:
            return "The file path is invalid."
        case .decodingFailed:
            return "Failed to decode file content from GitHub."
        }
    }
}
