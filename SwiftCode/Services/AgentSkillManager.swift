import Foundation
import ZIPFoundation

struct AgentSkillScheme: Codable {
    var name: String
    var version: String
    var author: String
    var summary: String
    var tags: [String]
    var recommendedTools: [String]
    var guidance: [String]
}

enum AgentSkillSource: String, Codable {
    case preset
    case uploaded
}

struct AgentSkillBundle: Identifiable, Codable {
    var id: UUID
    var source: AgentSkillSource
    var markdown: String
    var scheme: AgentSkillScheme
}

@MainActor
final class AgentSkillManager: ObservableObject {
    static let shared = AgentSkillManager()

    @Published var uploadedSkills: [AgentSkillBundle] = []
    let presetSkills = PresetAgentSkills.all

    private let indexFileName = "skills_index.json"
    private let fm = FileManager.default

    private var skillsDirectory: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentSkills", isDirectory: true)
    }

    private var indexURL: URL { skillsDirectory.appendingPathComponent(indexFileName) }

    private init() {
        try? fm.createDirectory(at: skillsDirectory, withIntermediateDirectories: true)
        loadUploadedSkills()
    }

    var allSkills: [AgentSkillBundle] { presetSkills + uploadedSkills }

    func importSkillArchive(at archiveURL: URL) throws {
        let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? fm.removeItem(at: temp)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }

        try fm.unzipItem(at: archiveURL, to: temp)

        guard let markdownURL = findFile(named: "skills.md", in: temp),
              let schemeURL = findFile(named: "scheme.json", in: temp) else {
            throw NSError(domain: "AgentSkillManager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Zip must include skills.md and scheme.json"])
        }

        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        let data = try Data(contentsOf: schemeURL)
        var scheme = try JSONDecoder().decode(AgentSkillScheme.self, from: data)
        if scheme.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            scheme.name = archiveURL.deletingPathExtension().lastPathComponent
        }

        let bundle = AgentSkillBundle(id: UUID(), source: .uploaded, markdown: markdown, scheme: scheme)
        uploadedSkills.insert(bundle, at: 0)
        saveUploadedSkills()
    }

    private func findFile(named fileName: String, in directory: URL) -> URL? {
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: nil) else { return nil }
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent.lowercased() == fileName.lowercased() {
            return fileURL
        }
        return nil
    }

    private func saveUploadedSkills() {
        guard let data = try? JSONEncoder().encode(uploadedSkills) else { return }
        try? data.write(to: indexURL)
    }

    func resetUploadedSkills() {
        uploadedSkills = []
        try? fm.removeItem(at: indexURL)
    }

    private func loadUploadedSkills() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([AgentSkillBundle].self, from: data) else { return }
        uploadedSkills = decoded
    }
}
