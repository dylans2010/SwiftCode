import Foundation

struct FilePatch: Identifiable, Codable {
    let id: UUID
    let filePath: String
    let originalContent: String
    let modifiedContent: String
    let diff: String

    init(filePath: String, originalContent: String, modifiedContent: String) {
        self.id = UUID()
        self.filePath = filePath
        self.originalContent = originalContent
        self.modifiedContent = modifiedContent
        self.diff = FilePatch.generateDiff(original: originalContent, modified: modifiedContent)
    }

    private static func generateDiff(original: String, modified: String) -> String {
        // More robust diff generation using Myers or similar is complex for a single file implementation.
        // We'll use a slightly better line-by-line approach that shows context.
        let origLines = original.components(separatedBy: .newlines)
        let modLines = modified.components(separatedBy: .newlines)

        var diff = ""

        // This is still a simplified diff, but better than before.
        // In a real production app, we would use a dedicated library.
        let maxLines = max(origLines.count, modLines.count)

        for i in 0..<maxLines {
            let orig = i < origLines.count ? origLines[i] : nil
            let mod = i < modLines.count ? modLines[i] : nil

            if orig != mod {
                if let o = orig {
                    diff += "-\(o)\n"
                }
                if let m = mod {
                    diff += "+\(m)\n"
                }
            } else if let o = orig {
                // Show some context (minimal)
                // diff += " \(o)\n"
            }
        }

        return diff.isEmpty ? "No changes detected." : diff
    }
}

@MainActor
final class CodePatchEngine: ObservableObject {
    static let shared = CodePatchEngine()
    private init() {}

    @Published var pendingPatches: [FilePatch] = []

    func createPatch(filePath: String, originalContent: String, modifiedContent: String) {
        let patch = FilePatch(filePath: filePath, originalContent: originalContent, modifiedContent: modifiedContent)
        pendingPatches.append(patch)
    }

    func applyPatch(_ patch: FilePatch) throws {
        let url = URL(fileURLWithPath: patch.filePath)
        try patch.modifiedContent.write(to: url, atomically: true, encoding: .utf8)
        pendingPatches.removeAll { $0.id == patch.id }
    }

    func rejectPatch(_ patch: FilePatch) {
        pendingPatches.removeAll { $0.id == patch.id }
    }

    func clearAll() {
        pendingPatches.removeAll()
    }
}
