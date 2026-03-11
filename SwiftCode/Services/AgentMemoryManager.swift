import Foundation

// MARK: - Agent Memory Manager
// Persistent agent memory store, wrapping AgentMemory with richer capabilities.

struct AgentMemoryEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var key: String
    var value: String
    var category: Category
    var projectName: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    enum Category: String, Codable, CaseIterable {
        case architecture  = "Architecture"
        case filePattern   = "File Pattern"
        case dependency    = "Dependency"
        case codeConvention = "Code Convention"
        case taskHistory   = "Task History"
        case projectInfo   = "Project Info"
        case custom        = "Custom"
    }
}

@MainActor
final class AgentMemoryManager: ObservableObject {
    static let shared = AgentMemoryManager()

    @Published var entries: [AgentMemoryEntry] = []
    @Published var legacyMemory: AgentMemory = AgentMemory()

    private var memoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentMemoryEntries.json")
    }

    private var legacyMemoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentMemory.json")
    }

    private init() {
        load()
        loadLegacy()
    }

    // MARK: - CRUD

    func addEntry(
        key: String,
        value: String,
        category: AgentMemoryEntry.Category = .custom,
        projectName: String = ""
    ) {
        if let idx = entries.firstIndex(where: { $0.key == key && $0.projectName == projectName }) {
            entries[idx].value = value
            entries[idx].updatedAt = Date()
        } else {
            let entry = AgentMemoryEntry(
                key: key,
                value: value,
                category: category,
                projectName: projectName
            )
            entries.append(entry)
        }
        save()
    }

    func removeEntry(_ entry: AgentMemoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearAll(forProject projectName: String? = nil) {
        if let project = projectName {
            entries.removeAll { $0.projectName == project }
        } else {
            entries.removeAll()
        }
        save()
    }

    func entries(for projectName: String) -> [AgentMemoryEntry] {
        entries.filter { $0.projectName == projectName }
    }

    func entries(for category: AgentMemoryEntry.Category) -> [AgentMemoryEntry] {
        entries.filter { $0.category == category }
    }

    // MARK: - Context Builder

    func buildContext(for projectName: String) -> String {
        let projectEntries = entries(for: projectName)
        guard !projectEntries.isEmpty else { return legacyContextString() }

        let grouped = Dictionary(grouping: projectEntries, by: { $0.category })
        var parts: [String] = []

        for category in AgentMemoryEntry.Category.allCases {
            if let items = grouped[category], !items.isEmpty {
                parts.append("## \(category.rawValue)")
                parts.append(contentsOf: items.map { "- \($0.key): \($0.value)" })
            }
        }

        return parts.joined(separator: "\n")
    }

    private func legacyContextString() -> String {
        var parts: [String] = []
        if !legacyMemory.projectArchitecture.isEmpty {
            parts.append("Architecture: \(legacyMemory.projectArchitecture)")
        }
        if !legacyMemory.importantFiles.isEmpty {
            parts.append("Key files: \(legacyMemory.importantFiles.joined(separator: ", "))")
        }
        if !legacyMemory.dependencies.isEmpty {
            parts.append("Dependencies: \(legacyMemory.dependencies.joined(separator: ", "))")
        }
        if !legacyMemory.codePatterns.isEmpty {
            parts.append("Patterns: \(legacyMemory.codePatterns.joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Legacy Compatibility

    func updateLegacy(
        architecture: String? = nil,
        files: [String]? = nil,
        deps: [String]? = nil,
        patterns: [String]? = nil
    ) {
        if let arch = architecture { legacyMemory.projectArchitecture = arch }
        if let f = files { legacyMemory.importantFiles = f }
        if let d = deps { legacyMemory.dependencies = d }
        if let p = patterns { legacyMemory.codePatterns = p }
        saveLegacy()
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: memoryURL)
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: memoryURL),
              let decoded = try? JSONDecoder().decode([AgentMemoryEntry].self, from: data) else { return }
        entries = decoded
    }

    func saveLegacy() {
        legacyMemory.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(legacyMemory) {
            try? data.write(to: legacyMemoryURL)
        }
    }

    func loadLegacy() {
        guard let data = try? Data(contentsOf: legacyMemoryURL),
              let decoded = try? JSONDecoder().decode(AgentMemory.self, from: data) else { return }
        legacyMemory = decoded
    }
}
