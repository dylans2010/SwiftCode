import SwiftUI

struct ChatMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.content)
                .font(.callout)
                .foregroundStyle(message.role == .assistant ? .primary : Color.white)

            Text(Self.timestampFormatter.string(from: message.timestamp))
                .font(.caption2)
                .foregroundStyle(message.role == .assistant ? .secondary : Color.white.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(message.role == .assistant ? Color.secondary.opacity(0.18) : Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

struct TypingIndicatorBubble: View {
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.75)
                Text("AI is typing…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Spacer(minLength: 40)
        }
    }
}

struct SlashCommandList: View {
    let commands: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(commands, id: \.self) { command in
                Button {
                    onSelect(command)
                } label: {
                    Text(command)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if command != commands.last {
                    Divider()
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
        )
    }
}
