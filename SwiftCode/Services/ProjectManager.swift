import Foundation
import Combine

@MainActor
final class ProjectManager: ObservableObject {
    static let shared = ProjectManager()

    @Published var projects: [Project] = [] {
        didSet { persistProjectList() }
    }
    @Published var activeProject: Project?
    @Published var activeFileNode: FileNode?
    @Published var activeFileContent: String = ""

    private var autoSaveCancellable: AnyCancellable?
    private var pendingSave: DispatchWorkItem?
    private static let projectListKey = "com.swiftcode.projectList"

    // MARK: - Directories

    var projectsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("SwiftCodeProjects", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func metadataURL(for project: Project) -> URL {
        projectsDirectory.appendingPathComponent(project.name).appendingPathComponent("project.json")
    }

    private init() {
        loadProjects()
    }

    // MARK: - UserDefaults Persistence

    /// Persist the project list to UserDefaults so the dashboard always shows projects.
    private func persistProjectList() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(projects) {
            UserDefaults.standard.set(data, forKey: Self.projectListKey)
        }
    }

    /// Load the project list from UserDefaults as a fallback when disk scan finds nothing.
    private func loadProjectListFromDefaults() -> [Project] {
        guard let data = UserDefaults.standard.data(forKey: Self.projectListKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Project].self, from: data)) ?? []
    }

    // MARK: - Load Projects

    func loadProjects() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            // If disk scan fails, restore from UserDefaults
            let cached = loadProjectListFromDefaults()
            if !cached.isEmpty { projects = cached }
            return
        }

        var loaded: [Project] = []
        for url in contents {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let metaURL = url.appendingPathComponent("project.json")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let data = try? Data(contentsOf: metaURL),
               var project = try? decoder.decode(Project.self, from: data) {
                project.files = buildFileTree(at: url, relativeTo: url)
                loaded.append(project)
            } else {
                // Directory exists but has no project.json — create metadata so the project persists
                let name = url.lastPathComponent
                var project = Project(name: name)
                project.files = buildFileTree(at: url, relativeTo: url)
                try? saveMetadata(project)
                loaded.append(project)
            }
        }

        if loaded.isEmpty {
            // Fallback: try to recover from UserDefaults if disk is empty
            let cached = loadProjectListFromDefaults()
            projects = cached.sorted { $0.lastOpened > $1.lastOpened }
        } else {
            projects = loaded.sorted { $0.lastOpened > $1.lastOpened }
        }
    }

    // MARK: - Create Project

    func createProject(name: String) throws -> Project {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { throw ProjectError.invalidName }

        let projectDir = projectsDirectory.appendingPathComponent(sanitized)
        guard !FileManager.default.fileExists(atPath: projectDir.path) else {
            throw ProjectError.alreadyExists
        }

        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        var project = Project(name: sanitized)
        project.description = "A new SwiftCode project"

        // Create default file structure
        try createDefaultStructure(at: projectDir, projectName: sanitized)

        // Rebuild file tree
        project.files = buildFileTree(at: projectDir, relativeTo: projectDir)

        // Persist metadata
        try saveMetadata(project)

        projects.insert(project, at: 0)
        return project
    }

    private func createDefaultStructure(at dir: URL, projectName: String) throws {
        let fm = FileManager.default

        // Sources/
        let sourcesDir = dir.appendingPathComponent("Sources")
        try fm.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        // Sources/ContentView.swift
        let contentView = """
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "swift")
                .imageScale(.large)
                .foregroundStyle(.orange)
            Text("\(projectName)")
                .font(.title)
                .bold()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
"""
        try contentView.write(to: sourcesDir.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        // Sources/App.swift
        let appSwift = """
import SwiftUI

@main
struct \(projectName.replacingOccurrences(of: " ", with: ""))App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
"""
        try appSwift.write(to: sourcesDir.appendingPathComponent("App.swift"), atomically: true, encoding: .utf8)

        // README.md
        let readme = """
# \(projectName)

Created with SwiftCode — an AI-powered iOS development environment.

## Getting Started

Edit your Swift files in the editor and use the AI assistant to generate, modify, or debug code.
"""
        try readme.write(to: dir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        // .github/workflows/build.yml
        let workflowsDir = dir.appendingPathComponent(".github/workflows")
        try fm.createDirectory(at: workflowsDir, withIntermediateDirectories: true)
        let workflow = """
name: Build

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: echo "Add your xcodebuild command here"
"""
        try workflow.write(to: workflowsDir.appendingPathComponent("build.yml"), atomically: true, encoding: .utf8)
    }

    // MARK: - Delete Project

    func deleteProject(_ project: Project) throws {
        try FileManager.default.removeItem(at: project.directoryURL)
        projects.removeAll { $0.id == project.id }
        if activeProject?.id == project.id {
            activeProject = nil
        }
    }

    // MARK: - Rename Project

    func renameProject(_ project: Project, to newName: String) throws {
        let sanitized = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { throw ProjectError.invalidName }

        let newURL = projectsDirectory.appendingPathComponent(sanitized)
        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            throw ProjectError.alreadyExists
        }

        try FileManager.default.moveItem(at: project.directoryURL, to: newURL)

        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].name = sanitized
            try saveMetadata(projects[idx])
        }

        if activeProject?.id == project.id {
            activeProject?.name = sanitized
        }
    }

    // MARK: - Duplicate Project

    func duplicateProject(_ project: Project) throws -> Project {
        let baseName = "\(project.name) Copy"
        var newName = baseName
        var counter = 2
        while FileManager.default.fileExists(atPath: projectsDirectory.appendingPathComponent(newName).path) {
            newName = "\(baseName) \(counter)"
            counter += 1
        }

        let newURL = projectsDirectory.appendingPathComponent(newName)
        try FileManager.default.copyItem(at: project.directoryURL, to: newURL)

        var newProject = Project(name: newName)
        newProject.description = project.description
        newProject.files = buildFileTree(at: newURL, relativeTo: newURL)
        try saveMetadata(newProject)

        projects.insert(newProject, at: 0)
        return newProject
    }

    // MARK: - Open / Close Project

    func openProject(_ project: Project) {
        var updated = project
        updated.lastOpened = Date()
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = updated
            try? saveMetadata(projects[idx])
        }
        updated.files = buildFileTree(at: updated.directoryURL, relativeTo: updated.directoryURL)
        activeProject = updated
        activeFileNode = nil
        activeFileContent = ""
    }

    func closeProject() {
        activeProject = nil
        activeFileNode = nil
        activeFileContent = ""
    }

    // MARK: - File Operations

    func openFile(_ node: FileNode) {
        guard !node.isDirectory else { return }
        guard let project = activeProject else { return }
        let fileURL = project.directoryURL.appendingPathComponent(node.path)
        activeFileContent = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        activeFileNode = node
    }

    func saveCurrentFile(content: String) {
        guard let project = activeProject,
              let node = activeFileNode else { return }
        let fileURL = project.directoryURL.appendingPathComponent(node.path)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        activeFileContent = content
    }

    func createFile(named name: String, inDirectory directoryPath: String?, project: Project, initialContent: String? = nil) throws {
        let base = directoryPath.map { project.directoryURL.appendingPathComponent($0) } ?? project.directoryURL
        let fileURL = base.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ProjectError.alreadyExists
        }
        let content: String
        if let provided = initialContent {
            content = provided
        } else if name.hasSuffix(".swift") {
            content = generateSwiftTemplate(for: name, in: project)
        } else {
            content = ""
        }
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        refreshFileTree(for: project)
    }

    private func generateSwiftTemplate(for name: String, in project: Project) -> String {
        let settings = AppSettings.shared
        let rawName = (name as NSString).deletingPathExtension
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        // Ensure the struct name starts with a letter (Swift identifier requirement)
        let structName: String
        if rawName.isEmpty || rawName.first?.isLetter == false {
            structName = "UntitledView"
        } else {
            structName = rawName
        }
        let author = settings.fileHeaderAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorDisplay = author.isEmpty ? "User" : author
        let customComment = settings.fileHeaderCustomComment.trimmingCharacters(in: .whitespacesAndNewlines)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        let dateStr = dateFormatter.string(from: Date())

        return """
//  \(name)
//  \(project.name)
//
//  Created by \(authorDisplay) on \(dateStr).
//  \(customComment.isEmpty ? "Made with SwiftCode" : customComment)
//

import SwiftUI

struct \(structName): View {
    var body: some View {
        VStack {
            Text("Hello, World!")
        }
        .padding()
    }
}

#Preview {
    \(structName)()
}
"""
    }

    func createFolder(named name: String, inDirectory directoryPath: String?, project: Project) throws {
        let base = directoryPath.map { project.directoryURL.appendingPathComponent($0) } ?? project.directoryURL
        let folderURL = base.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        refreshFileTree(for: project)
    }

    func deleteNode(_ node: FileNode, project: Project) throws {
        let url = project.directoryURL.appendingPathComponent(node.path)
        try FileManager.default.removeItem(at: url)
        if activeFileNode?.id == node.id {
            activeFileNode = nil
            activeFileContent = ""
        }
        refreshFileTree(for: project)
    }

    func renameNode(_ node: FileNode, to newName: String, project: Project) throws {
        let oldURL = project.directoryURL.appendingPathComponent(node.path)
        let newPath = (node.path as NSString).deletingLastPathComponent.appending("/\(newName)")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let newURL = project.directoryURL.appendingPathComponent(newPath)
        try FileManager.default.moveItem(at: oldURL, to: newURL)
        refreshFileTree(for: project)
    }

    // MARK: - File Tree

    private func buildFileTree(at url: URL, relativeTo base: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents
            .filter { $0.lastPathComponent != "project.json" }
            .sorted {
                let aIsDir = (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let bIsDir = (try? $1.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if aIsDir != bIsDir { return aIsDir }
                return $0.lastPathComponent < $1.lastPathComponent
            }
            .map { childURL -> FileNode in
                let isDir = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let relativePath = childURL.path.replacingOccurrences(of: base.path + "/", with: "")
                let node = FileNode(name: childURL.lastPathComponent, path: relativePath, isDirectory: isDir)
                if isDir {
                    node.children = buildFileTree(at: childURL, relativeTo: base)
                }
                return node
            }
    }

    func refreshFileTree(for project: Project) {
        let files = buildFileTree(at: project.directoryURL, relativeTo: project.directoryURL)
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx].files = files
        }
        if activeProject?.id == project.id {
            activeProject?.files = files
        }
    }

    // MARK: - Metadata Persistence

    private func saveMetadata(_ project: Project) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)
        try data.write(to: metadataURL(for: project))
    }
}

// MARK: - Errors

enum ProjectError: LocalizedError {
    case invalidName
    case alreadyExists
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidName: return "Project name is invalid."
        case .alreadyExists: return "A project with that name already exists."
        case .notFound: return "Project not found."
        }
    }
}
