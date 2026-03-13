import Foundation

struct WorkspaceProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var buildConfiguration: String
    var environmentVariables: [String: String]
    var preferences: [String: String]

    static let empty = WorkspaceProfile(
        id: UUID(),
        name: "",
        buildConfiguration: "Debug",
        environmentVariables: [:],
        preferences: [:]
    )
}

@MainActor
final class WorkspaceProfilesManager: ObservableObject {
    static let shared = WorkspaceProfilesManager()

    @Published var profiles: [WorkspaceProfile] = [] {
        didSet { persistProfiles() }
    }
    @Published var activeProfileID: UUID? {
        didSet { persistActiveProfileID() }
    }

    private let profilesKey = "com.swiftcode.workspaceProfiles"
    private let activeProfileKey = "com.swiftcode.activeWorkspaceProfile"

    private init() {
        loadProfiles()
        loadActiveProfileID()
    }

    func switchTo(_ profile: WorkspaceProfile) { activeProfileID = profile.id }

    func add(_ profile: WorkspaceProfile) {
        profiles.append(profile)
        if activeProfileID == nil { activeProfileID = profile.id }
    }

    func update(_ profile: WorkspaceProfile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
    }

    func delete(_ profile: WorkspaceProfile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfileID == profile.id {
            activeProfileID = profiles.first?.id
        }
    }

    private func loadProfiles() {
        guard
            let data = UserDefaults.standard.data(forKey: profilesKey),
            let decoded = try? JSONDecoder().decode([WorkspaceProfile].self, from: data)
        else {
            profiles = []
            return
        }

        profiles = decoded
    }

    private func loadActiveProfileID() {
        guard let value = UserDefaults.standard.string(forKey: activeProfileKey) else { return }
        activeProfileID = UUID(uuidString: value)
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: profilesKey)
    }

    private func persistActiveProfileID() {
        UserDefaults.standard.set(activeProfileID?.uuidString, forKey: activeProfileKey)
    }
}
