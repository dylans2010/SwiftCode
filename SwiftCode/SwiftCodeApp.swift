import SwiftUI

@main
struct SwiftCodeApp: App {
    @StateObject private var projectManager = ProjectManager.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var codingManager = CodingManager.shared
    @StateObject private var toolbarSettings = ToolbarSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectManager)
                .environmentObject(settings)
                .environmentObject(toolbarSettings)
                .task {
                    // Ensure the persistent Projects and Models directories exist at launch
                    codingManager.ensureProjectsDirectory()
                    codingManager.ensureModelsDirectory()
                }
        }
    }
}
