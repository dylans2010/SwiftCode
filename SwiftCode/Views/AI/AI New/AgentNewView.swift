import SwiftUI

struct AgentNewView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            AgentToolbar(selectedTab: $selectedTab)

            Divider()

            if AppSettings.shared.useCodexAsDefaultAgent {
                CodexMainView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else if selectedTab == 0 {
                AgentModeView()
            } else {
                ChatAIInterfaceView()
            }
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
    }
}
