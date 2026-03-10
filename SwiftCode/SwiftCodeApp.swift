import SwiftUI

@main
struct SwiftCodeApp: App {
    @StateObject private var projectManager = ProjectManager.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var codingManager = CodingManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectManager)
                .environmentObject(settings)
                .task {
                    // Ensure the persistent Projects and Models directories exist at launch
                    codingManager.ensureProjectsDirectory()
                    codingManager.ensureModelsDirectory()
                }
        }
    }
}
