import SwiftUI

struct InstalledOfflineModelsView: View {
    @ObservedObject var manager = OfflineModelManager.shared

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
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
                        HStack(alignment: .firstTextBaseline) {
                            Text(model.modelName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                            Text(model.size)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            Text(model.validationStatus ?? "Not validated")
                                .font(.caption)
                                .foregroundStyle((model.validationStatus ?? "").hasPrefix("Error") ? .red : .secondary)

                            Spacer()

                            Text(dateFormatter.string(from: model.installDate))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        if !model.localModelPath.isEmpty {
                            Text(model.localModelPath)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 8) {
                            Button {
                                Task {
                                    await testModel(model)
                                }
                            } label: {
                                Label("Test", systemImage: "waveform.path.ecg")
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive) {
                                deleteModel(model)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func deleteModel(_ model: InstalledOfflineModelRecord) {
        let metadata = OfflineModelMetadata(
            modelName: model.modelName,
            providerName: model.provider,
            description: "Locally stored model",
            modelSize: model.size,
            tags: ["offline", "installed"],
            downloadCount: 0,
            modelURL: URL(fileURLWithPath: model.localModelPath.isEmpty ? "/" : model.localModelPath),
            files: [],
            isQuantized: false
        )
        manager.removeModel(metadata)
    }

    private func testModel(_ model: InstalledOfflineModelRecord) async {
        guard !model.localModelPath.isEmpty else {
            manager.updateValidationStatus(for: model.modelName, status: "Error: Missing local path", clearLocalPath: true)
            return
        }

        do {
            try await OfflineModelRunner.shared.loadModel(at: URL(fileURLWithPath: model.localModelPath))
            let reply = try await OfflineModelRunner.shared.generateResponse(prompt: "Hello from SwiftCode")
            let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedReply.isEmpty {
                manager.updateValidationStatus(for: model.modelName, status: "Error: Empty response", clearLocalPath: true)
            } else {
                manager.updateValidationStatus(for: model.modelName, status: "Valid: \(trimmedReply.prefix(60))")
            }
        } catch {
            manager.updateValidationStatus(for: model.modelName, status: "Error: \(error.localizedDescription)", clearLocalPath: true)
        }
    }
}
