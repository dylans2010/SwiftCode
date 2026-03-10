import SwiftUI

@main
struct SwiftCodeApp: App {
    @StateObject private var projectManager = ProjectManager.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectManager)
                .environmentObject(settings)
        }
    }
}
