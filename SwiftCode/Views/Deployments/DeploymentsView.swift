import SwiftUI

struct DeploymentsView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @State private var selectedPlatform: DeploymentPlatform = .netlify
    @State private var customDomain: String = ""
    @State private var useCustomDomain: Bool = false
    @State private var logs: [DeploymentLogLine] = []
    @State private var isDeploying: Bool = false
    @State private var deploymentURL: String?
    @State private var errorMessage: String?

    private var hasToken: Bool {
        let service: DeploymentKeychainManager.Service = {
            switch selectedPlatform {
            case .netlify: return .netlify
            case .vercel: return .vercel
            case .githubPages: return .github
            }
        }()
        return DeploymentKeychainManager.shared.retrieveKey(service: service) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Platform") {
                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach(DeploymentPlatform.allCases) { platform in
                            Text(platform.rawValue).tag(platform)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Configuration") {
                    Toggle("Use Custom Domain", isOn: $useCustomDomain)
                    if useCustomDomain {
                        TextField("e.g. example.com", text: $customDomain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }

                Section {
                    Button(action: startDeployment) {
                        HStack {
                            if isDeploying {
                                ProgressView().padding(.trailing, 8)
                            } else {
                                Image(systemName: "cloud.fill")
                            }
                            Text(isDeploying ? "Deploying..." : "Start Deployment")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isDeploying || !hasToken)
                    .listRowBackground(isDeploying || !hasToken ? Color.gray.opacity(0.2) : Color.orange)
                    .foregroundStyle(.white)
                } footer: {
                    if !hasToken {
                        Text("Please configure your API key in Settings > API Keys.")
                            .foregroundStyle(.red)
                    }
                }

                if let deploymentURL = deploymentURL {
                    Section("Result") {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Deployment Successful")
                                .font(.subheadline.bold())
                        }

                        Link(destination: URL(string: deploymentURL)!) {
                            Label(deploymentURL, systemImage: "link")
                                .font(.caption.monospaced())
                        }

                        Button("Open in Browser") {
                            #if os(iOS)
                            UIApplication.shared.open(URL(string: deploymentURL)!)
                            #endif
                        }
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    } header: {
                        Text("Error").foregroundStyle(.red)
                    }
                }

                if !logs.isEmpty {
                    Section("Deployment Logs") {
                        DeploymentLogsView(logs: logs)
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
            .navigationTitle("Deployments")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func startDeployment() {
        guard let project = projectManager.activeProject else { return }

        isDeploying = true
        deploymentURL = nil
        errorMessage = nil
        logs = []

        Task {
            do {
                let service: DeploymentKeychainManager.Service = {
                    switch selectedPlatform {
                    case .netlify: return .netlify
                    case .vercel: return .vercel
                    case .githubPages: return .github
                    }
                }()
                let tokenToUse = DeploymentKeychainManager.shared.retrieveKey(service: service)

                let result = try await DeploymentTargets.shared.deploy(
                    project: project,
                    platform: selectedPlatform,
                    token: tokenToUse,
                    domain: useCustomDomain ? customDomain : nil
                ) { message in
                    DispatchQueue.main.async {
                        logs.append(DeploymentLogLine(timestamp: Date(), message: message, isError: false))
                    }
                }

                DispatchQueue.main.async {
                    isDeploying = false
                    if result.success {
                        deploymentURL = result.url
                    } else {
                        errorMessage = result.errorMessage
                        logs.append(DeploymentLogLine(timestamp: Date(), message: result.errorMessage ?? "Unknown error", isError: true))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isDeploying = false
                    errorMessage = error.localizedDescription
                    logs.append(DeploymentLogLine(timestamp: Date(), message: error.localizedDescription, isError: true))
                }
            }
        }
    }
}

#Preview {
    DeploymentsView()
        .environmentObject(ProjectManager.shared)
}
