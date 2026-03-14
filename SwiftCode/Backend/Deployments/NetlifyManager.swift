import Foundation
import ZIPFoundation

final class NetlifyManager {
    static let shared = NetlifyManager()
    private init() {}

    private let baseURL = URL(string: "https://api.netlify.com/api/v1")!

    func deploy(
        project: Project,
        token: String?,
        domain: String?,
        logHandler: @escaping (String) -> Void
    ) async throws -> DeploymentResult {
        guard let token = token, !token.isEmpty else {
            return DeploymentResult(success: false, url: nil, errorMessage: "Netlify API Token is required.")
        }

        do {
            logHandler("Preparing project files for upload...")
            let zipURL = try await createProjectZip(project: project)
            defer { try? FileManager.default.removeItem(at: zipURL) }

            logHandler("Checking for existing site or creating a new one...")
            let siteId = try await getOrCreateSite(project: project, token: token, logHandler: logHandler)

            logHandler("Uploading ZIP to Netlify (Site ID: \(siteId))...")
            let deployId = try await uploadZip(siteId: siteId, zipURL: zipURL, token: token)

            logHandler("Deployment queued (ID: \(deployId)). Waiting for processing...")
            let finalStatus = try await pollDeploymentStatus(deployId: deployId, token: token, logHandler: logHandler)

            if finalStatus == "ready" {
                let siteInfo = try await getSiteInfo(siteId: siteId, token: token)
                let siteURL = domain != nil ? "https://\(domain!)" : siteInfo.url
                logHandler("Deployment successful! Live at \(siteURL)")
                return DeploymentResult(success: true, url: siteURL, errorMessage: nil)
            } else {
                return DeploymentResult(success: false, url: nil, errorMessage: "Netlify deployment failed with status: \(finalStatus)")
            }
        } catch {
            logHandler("Error: \(error.localizedDescription)")
            return DeploymentResult(success: false, url: nil, errorMessage: error.localizedDescription)
        }
    }

    private func createProjectZip(project: Project) async throws -> URL {
        let projectDir = await project.directoryURL
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(project.name)_\(UUID().uuidString).zip")

        // Use ZIPFoundation to create the archive
        try FileManager.default.zipItem(at: projectDir, to: zipURL, shouldKeepParent: false)

        return zipURL
    }

    private func getOrCreateSite(project: Project, token: String, logHandler: @escaping (String) -> Void) async throws -> String {
        let sitesURL = baseURL.appendingPathComponent("sites")
        var request = URLRequest(url: sitesURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetlifyManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch sites from Netlify."])
        }

        let sites = try JSONDecoder().decode([NetlifySite].self, from: data)
        let siteName = project.name.lowercased().replacingOccurrences(of: " ", with: "-")

        if let existingSite = sites.first(where: { $0.name == siteName || $0.custom_domain == siteName }) {
            logHandler("Using existing site: \(existingSite.name)")
            return existingSite.id
        }

        logHandler("Creating new site: \(siteName)...")
        var createRequest = URLRequest(url: sitesURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["name": siteName]
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
        guard let httpCreateResponse = createResponse as? HTTPURLResponse, (200...201).contains(httpCreateResponse.statusCode) else {
            // If name is taken, Netlify might return 422. We should handle it by getting a random name if needed or reporting error.
            let errorMsg = String(data: createData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "NetlifyManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create site: \(errorMsg)"])
        }

        let newSite = try JSONDecoder().decode(NetlifySite.self, from: createData)
        return newSite.id
    }

    private func uploadZip(siteId: String, zipURL: URL, token: String) async throws -> String {
        let uploadURL = baseURL.appendingPathComponent("sites/\(siteId)/deploys")
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")

        let zipData = try Data(contentsOf: zipURL)
        request.httpBody = zipData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "NetlifyManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to upload ZIP: \(errorMsg)"])
        }

        let deploy = try JSONDecoder().decode(NetlifyDeploy.self, from: data)
        return deploy.id
    }

    private func pollDeploymentStatus(deployId: String, token: String, logHandler: @escaping (String) -> Void) async throws -> String {
        let deployURL = baseURL.appendingPathComponent("deploys/\(deployId)")

        for i in 1...30 { // Poll for 5 minutes (10s intervals)
            var request = URLRequest(url: deployURL)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let deploy = try JSONDecoder().decode(NetlifyDeploy.self, from: data)
                logHandler("Status (\(i)): \(deploy.state)")
                if deploy.state == "ready" { return "ready" }
                if ["error", "failed"].contains(deploy.state) { return deploy.state }
            }

            try await Task.sleep(nanoseconds: 10_000_000_000)
        }
        return "timeout"
    }

    private func getSiteInfo(siteId: String, token: String) async throws -> NetlifySite {
        let siteURL = baseURL.appendingPathComponent("sites/\(siteId)")
        var request = URLRequest(url: siteURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetlifyManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch site info."])
        }

        return try JSONDecoder().decode(NetlifySite.self, from: data)
    }
}

// MARK: - Netlify Models

struct NetlifySite: Codable {
    let id: String
    let name: String
    let url: String
    let custom_domain: String?
}

struct NetlifyDeploy: Codable {
    let id: String
    let state: String
}
