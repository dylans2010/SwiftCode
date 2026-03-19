import SwiftUI

struct AICoreView: View {
    @AppStorage("useCodexAsAgent") private var useCodexAsAgent = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TraditionalAgentView(selectedTab: $selectedTab)
                .opacity(useCodexAsAgent ? 0 : 1)
                .allowsHitTesting(!useCodexAsAgent)

            CodexMainView()
                .opacity(useCodexAsAgent ? 1 : 0)
                .allowsHitTesting(useCodexAsAgent)
        }
        .animation(.easeInOut(duration: 0.25), value: useCodexAsAgent)
    }
}

struct TraditionalAgentView: View {
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 0) {
            AgentToolbar(selectedTab: $selectedTab)
            Divider()
            if selectedTab == 0 {
                AgentModeView()
            } else {
                ChatAIInterfaceView()
            }
        }
    }
}
