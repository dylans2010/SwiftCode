import SwiftUI

struct OnDeviceAIView: View {
    @ObservedObject var controller: ChatController
    @State private var inputText = ""
    @State private var useContext = true
    @State private var streamedResponse = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.7), .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                headerCard
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(controller.messages) { message in
                            ChatMessageBubble(message: message)
                                .padding(.horizontal, 8)
                        }
                        if !streamedResponse.isEmpty {
                            Text(streamedResponse)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .padding(.horizontal, 8)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.bottom, 8)
                }
                composer
            }
            .padding()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: controller.messages)
        .navigationTitle("Apple Intelligence")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("On-Device AI", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text(DeviceUtilityManager.shared.getCapabilityLevel().rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
            Text("Private, offline-first assistance with streaming responses and automatic fallback.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var composer: some View {
        VStack(spacing: 12) {
            Toggle("Use project context", isOn: $useContext)
                .toggleStyle(.switch)
                .padding(.horizontal, 4)
            HStack(spacing: 12) {
                TextField("Ask Apple Intelligence", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button {
                    let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !prompt.isEmpty else { return }
                    inputText = ""
                    streamedResponse = ""
                    Task {
                        controller.messages.append(ChatMessage(role: .user, content: prompt, timestamp: Date()))
                        do {
                            for try await chunk in OnDeviceAIManager.shared.streamResponse(for: useContext ? "[Context Aware]\n\n\(prompt)" : prompt) {
                                streamedResponse = chunk
                            }
                            if !streamedResponse.isEmpty {
                                controller.messages.append(ChatMessage(role: .assistant, content: streamedResponse, timestamp: Date()))
                                streamedResponse = ""
                            }
                        } catch {
                            controller.messages.append(ChatMessage(role: .assistant, content: error.localizedDescription, timestamp: Date()))
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}
