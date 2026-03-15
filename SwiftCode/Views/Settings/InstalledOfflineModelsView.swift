import SwiftUI

struct InstalledOfflineModelsView: View {
    @ObservedObject var manager = OfflineModelManager.shared

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        Section("Installed Models") {
            if manager.installedModelRecords.isEmpty {
                Text("No local models installed")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manager.installedModelRecords) { model in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.modelName)
                            .font(.headline)

                        LabeledContent("Provider", value: model.provider)
                        LabeledContent("Size", value: model.size)
                        LabeledContent("Installed", value: dateFormatter.string(from: model.installDate))
                        LabeledContent("Path") {
                            Text(model.localModelPath)
                                .multilineTextAlignment(.trailing)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
