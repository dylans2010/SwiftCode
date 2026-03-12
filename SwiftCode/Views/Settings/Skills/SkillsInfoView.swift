import SwiftUI

struct SkillsInfoView: View {
    let skill: AgentSkillBundle

    private var formattedMarkdown: AttributedString {
        (try? AttributedString(markdown: skill.markdown)) ?? AttributedString(skill.markdown)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(skill.scheme.name)
                    .font(.title2.weight(.bold))
                Text(skill.scheme.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Label(skill.scheme.author, systemImage: "person")
                    Spacer()
                    Text("v\(skill.scheme.version)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                if !skill.scheme.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(skill.scheme.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }

                GroupBox("Recommended Tools") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(skill.scheme.recommendedTools, id: \.self) { tool in
                            Text("• \(tool)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                GroupBox("Guidance") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(skill.scheme.guidance, id: \.self) { item in
                            Text("• \(item)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                GroupBox("skills.md") {
                    Text(formattedMarkdown)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("Skill Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}
