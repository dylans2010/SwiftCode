import Foundation

struct ProjectFolder: Identifiable, Codable, Equatable {
    var folderId: UUID
    var folderName: String
    var iconSymbol: String
    var colorHex: String
    var createdDate: Date
    var projectIdentifiers: [UUID]

    var id: UUID { folderId }

    init(
        folderId: UUID = UUID(),
        folderName: String,
        iconSymbol: String = "folder.fill",
        colorHex: String = "#4F86FF",
        createdDate: Date = Date(),
        projectIdentifiers: [UUID] = []
    ) {
        self.folderId = folderId
        self.folderName = folderName
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.createdDate = createdDate
        self.projectIdentifiers = projectIdentifiers
    }
}
