import Foundation

final class VercelManager {
    static let shared = VercelManager()
    private init() {}

    private let baseURL = URL(string: "https://api.vercel.com")!

    func deploy(
        project: Project,
        token: String?,
        domain: String?,
        logHandler: @escaping (String) -> Void
    ) async throws -> DeploymentResult {
        guard let token = token, !token.isEmpty else {
            return DeploymentResult(success: false, url: nil, errorMessage: "Vercel API Token is required.")
        }

        do {
            logHandler("Detecting framework and build settings...")
            let framework = await DeploymentTargets.shared.detectFramework(project: project)

            logHandler("Preparing files for Vercel deployment...")
            let files = try await prepareFiles(project: project)

            logHandler("Creating deployment on Vercel...")
            let deployment = try await createDeployment(
                project: project,
                files: files,
                framework: framework,
                token: token,
                logHandler: logHandler
            )

            logHandler("Deployment created (ID: \(deployment.id)). Monitoring build status...")
            let finalStatus = try await pollDeploymentStatus(deploymentId: deployment.id, token: token, logHandler: logHandler)

            if finalStatus == "READY" {
                let siteURL = domain != nil ? "https://\(domain!)" : "https://\(deployment.url)"
                logHandler("Deployment successful! Live at \(siteURL)")
                return DeploymentResult(success: true, url: siteURL, errorMessage: nil)
            } else {
                return DeploymentResult(success: false, url: nil, errorMessage: "Vercel deployment failed with status: \(finalStatus)")
            }
        } catch {
            logHandler("Error: \(error.localizedDescription)")
            return DeploymentResult(success: false, url: nil, errorMessage: error.localizedDescription)
        }
    }

    private func prepareFiles(project: Project) async throws -> [VercelFile] {
        let projectDir = await project.directoryURL
        let fileManager = FileManager.default
        var vercelFiles: [VercelFile] = []

        let enumerator = fileManager.enumerator(at: projectDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])

        while let fileURL = enumerator?.nextObject() as? URL {
            let relativePath = String(fileURL.path.dropFirst(projectDir.path.count + 1))
            let data = try Data(contentsOf: fileURL)
            vercelFiles.append(VercelFile(file: relativePath, data: data))
        }

        return vercelFiles
    }

    private func createDeployment(
        project: Project,
        files: [VercelFile],
        framework: FrameworkConfig,
        token: String,
        logHandler: @escaping (String) -> Void
    ) async throws -> VercelDeploymentResponse {
        let url = baseURL.appendingPathComponent("v13/deployments")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let projectName = project.name.lowercased().replacingOccurrences(of: " ", with: "-")

        let vercelFramework: String?
        switch framework.name.lowercased() {
        case "next.js": vercelFramework = "nextjs"
        case "nuxt": vercelFramework = "nuxtjs"
        case "vite": vercelFramework = "vite"
        case "astro": vercelFramework = "astro"
        case "static": vercelFramework = nil
        default: vercelFramework = nil
        }

        var body: [String: Any] = [
            "name": projectName,
            "files": files.map { ["file": $0.file, "data": $0.data.base64EncodedString()] },
            "projectSettings": [
                "framework": vercelFramework,
                "buildCommand": framework.buildCommand,
                "outputDirectory": framework.outputDirectory
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "VercelManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create deployment: \(errorMsg)"])
        }

        return try JSONDecoder().decode(VercelDeploymentResponse.self, from: data)
    }

    private func pollDeploymentStatus(deploymentId: String, token: String, logHandler: @escaping (String) -> Void) async throws -> String {
        let url = baseURL.appendingPathComponent("v13/deployments/\(deploymentId)")

        for i in 1...60 { // Poll for 10 minutes (10s intervals)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let deployment = try JSONDecoder().decode(VercelDeploymentResponse.self, from: data)
                logHandler("Status (\(i)): \(deployment.readyState)")
                if deployment.readyState == "READY" { return "READY" }
                if ["ERROR", "CANCELED"].contains(deployment.readyState) { return deployment.readyState }
            }

            try await Task.sleep(nanoseconds: 10_000_000_000)
        }
        return "TIMEOUT"
    }
}

// MARK: - Vercel Models

struct VercelFile {
    let file: String
    let data: Data
}

struct VercelDeploymentResponse: Codable {
    let id: String
    let url: String
    let readyState: String
}
