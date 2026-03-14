import Foundation

@MainActor
final class FolderManager: ObservableObject {
    static let shared = FolderManager()

    @Published var folders: [ProjectFolder] = [] {
        didSet { persistFolders() }
    }

    private static let foldersKey = "com.swiftcode.projectFolders"

    private init() {
        loadFolders()
    }

    func createFolder(name: String, symbol: String, colorHex: String, gradientColors: [String]? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let folder = ProjectFolder(folderName: trimmed, iconSymbol: symbol, colorHex: colorHex, gradientColors: gradientColors)
        folders.append(folder)
    }

    func addProject(_ projectId: UUID, to folderId: UUID) {
        guard let index = folders.firstIndex(where: { $0.folderId == folderId }) else { return }
        if !folders[index].projectIdentifiers.contains(projectId) {
            folders[index].projectIdentifiers.append(projectId)
        }
    }

    func projects(in folder: ProjectFolder, allProjects: [Project]) -> [Project] {
        allProjects.filter { folder.projectIdentifiers.contains($0.id) }
    }

    private func persistFolders() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(folders) {
            UserDefaults.standard.set(data, forKey: Self.foldersKey)
        }
    }

    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: Self.foldersKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        folders = (try? decoder.decode([ProjectFolder].self, from: data)) ?? []
    }
}
