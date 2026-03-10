import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var projectManager: ProjectManager

    var body: some View {
        Group {
            if let project = projectManager.activeProject {
                ProjectWorkspaceView(project: project)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else {
                ProjectsDashboardView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: projectManager.activeProject?.id)
    }
}
