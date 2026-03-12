import Foundation

struct WorkspaceProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var buildConfiguration: String
    var environmentVariables: [String: String]
    var preferences: [String: String]

    static let template = WorkspaceProfile(id: UUID(), name: "Development", buildConfiguration: "Debug", environmentVariables: [:], preferences: [:])
}

@MainActor
final class WorkspaceProfilesManager: ObservableObject {
    static let shared = WorkspaceProfilesManager()
    @Published var profiles: [WorkspaceProfile] = [
        .init(id: UUID(), name: "Development", buildConfiguration: "Debug", environmentVariables: ["API_ENV": "dev"], preferences: [:]),
        .init(id: UUID(), name: "Testing", buildConfiguration: "Debug", environmentVariables: ["API_ENV": "test"], preferences: [:]),
        .init(id: UUID(), name: "Production", buildConfiguration: "Release", environmentVariables: ["API_ENV": "prod"], preferences: [:])
    ]
    @Published var activeProfileID: UUID?

    func switchTo(_ profile: WorkspaceProfile) { activeProfileID = profile.id }
    func add(_ profile: WorkspaceProfile) { profiles.append(profile) }
}
