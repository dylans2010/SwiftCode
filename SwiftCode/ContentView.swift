import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var projectManager: ProjectManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var suggestionsManager: CodeSuggestionsML

    @State private var showSuggestionToast = false
    @State private var showSuggestionsView = false

    var body: some View {
        ZStack(alignment: .bottom) {
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

            if showSuggestionToast {
                Button {
                    showSuggestionToast = false
                    showSuggestionsView = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.max.fill")
                            .foregroundStyle(.yellow)
                        Text("Code Suggestions has reviewed your code, check it out")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule())
                }
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: projectManager.activeProject?.id)
        .onReceive(NotificationCenter.default.publisher(for: .codeSuggestionsReady)) { _ in
            guard settings.codeSuggestionsEnabled else { return }
            withAnimation {
                showSuggestionToast = true
            }
        }
        .onChange(of: projectManager.activeProject?.id) {
            guard settings.codeSuggestionsEnabled, let project = projectManager.activeProject else { return }
            suggestionsManager.analyze(project: project)
        }
        .onChange(of: settings.codeSuggestionsEnabled) {
            guard settings.codeSuggestionsEnabled, let project = projectManager.activeProject else { return }
            suggestionsManager.analyze(project: project)
        }
        .sheet(isPresented: $showSuggestionsView) {
            CodeSuggestionsView()
                .environmentObject(suggestionsManager)
        }
        .fullScreenCover(isPresented: .init(get: { !settings.hasCompletedOnboarding }, set: { _ in })) {
            OnboardingView()
                .environmentObject(settings)
        }
    }
}
