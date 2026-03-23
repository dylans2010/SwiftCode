import Foundation
import SwiftUI

@MainActor
public final class GitHubGistService: ObservableObject {
    public static let shared = GitHubGistService()
    private init() {}

    @Published public var gists: [GistResponse] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    private let baseURL = URL(string: "https://api.github.com")!

    private var token: String? {
        APIKeyManager.shared.retrieveKey(service: .gitHub) ?? KeychainService.shared.get(forKey: KeychainService.githubToken)
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

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw GistError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GistError.apiError("GitHub API error \(http.statusCode): \(body)")
        }
    }

    // MARK: - API Methods

    public func fetchGists() async throws -> [GistResponse] {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            var components = URLComponents(url: baseURL.appendingPathComponent("gists"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "per_page", value: "50")]

        let request = authorizedRequest(url: components.url!)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

            let decodedGists = try decoder().decode([GistResponse].self, from: data)
            self.gists = decodedGists
            return decodedGists
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func fetchGist(id: String) async throws -> GistResponse {
        errorMessage = nil
        do {
            let url = baseURL.appendingPathComponent("gists/\(id)")
        let request = authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
            return try decoder().decode(GistResponse.self, from: data)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func createGist(files: [GistFile], description: String, isPublic: Bool) async throws -> GistResponse {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let url = baseURL.appendingPathComponent("gists")
        var request = authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let fileDict = Dictionary(uniqueKeysWithValues: files.map { ($0.filename, $0.content) })
        let body = CreateGistRequest(description: description, isPublic: isPublic, files: fileDict)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

            let newGist = try decoder().decode(GistResponse.self, from: data)
            self.gists.insert(newGist, at: 0)
            return newGist
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func updateGist(id: String, description: String, files: [String: GistUpdateRequest.FileUpdateContent?]) async throws -> GistResponse {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let url = baseURL.appendingPathComponent("gists/\(id)")
        var request = authorizedRequest(url: url, method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GistUpdateRequest(description: description, files: files)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

            let updatedGist = try decoder().decode(GistResponse.self, from: data)
            if let index = gists.firstIndex(where: { $0.id == id }) {
                gists[index] = updatedGist
            }
            return updatedGist
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func deleteGist(id: String) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let url = baseURL.appendingPathComponent("gists/\(id)")
        let request = authorizedRequest(url: url, method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw GistError.invalidResponse }
        guard http.statusCode == 204 || (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GistError.apiError("GitHub API error \(http.statusCode): \(body)")
        }

            gists.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func checkIsStarred(id: String) async throws -> Bool {
        let url = baseURL.appendingPathComponent("gists/\(id)/star")
        let request = authorizedRequest(url: url)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 204
    }

    public func starGist(id: String) async throws {
        errorMessage = nil
        do {
            let url = baseURL.appendingPathComponent("gists/\(id)/star")
            let request = authorizedRequest(url: url, method: "PUT")
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateResponse(response, data: data)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func unstarGist(id: String) async throws {
        errorMessage = nil
        do {
            let url = baseURL.appendingPathComponent("gists/\(id)/star")
        let request = authorizedRequest(url: url, method: "DELETE")
        let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else { throw GistError.invalidResponse }
            guard http.statusCode == 204 || (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw GistError.apiError("GitHub API error \(http.statusCode): \(body)")
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func forkGist(id: String) async throws -> GistResponse {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let url = baseURL.appendingPathComponent("gists/\(id)/forks")
        let request = authorizedRequest(url: url, method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

            let forkedGist = try decoder().decode(GistResponse.self, from: data)
            self.gists.insert(forkedGist, at: 0)
            return forkedGist
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
