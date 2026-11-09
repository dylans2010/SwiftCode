import YcodeAssistant
import SwiftUI

public struct InstalledOfflineModelsView: View {
    @State var manager = OfflineModelManager.shared

    public init(manager: OfflineModelManager = OfflineModelManager.shared) {
        self._manager = State(initialValue: manager)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if manager.installedModelRecords.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "externaldrive.badge.xmark")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No Local Models Installed")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Download models from Hugging Face or via direct link.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ForEach(manager.installedModelRecords) { model in
                    let isActive = manager.defaultOfflineModelName == model.modelName

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(model.modelName)
                                        .font(.title3.bold())
                                        .foregroundStyle(.primary)

                                    if isActive {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 6, height: 6)
                                            Text("ACTIVE LOCAL MODEL")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.green)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.12), in: Capsule())
                                    }
                                }

                                HStack(spacing: 8) {
                                    Label(model.folderName, systemImage: "folder")
                                    Text("•")
                                    Label(model.sizeDescription, systemImage: "internaldrive")
                                    Text("•")
                                    Label("Tokens: \(model.metadata.tokenCount > 0 ? "\(model.metadata.tokenCount)" : "Standard")", systemImage: "number")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()

                            Text(model.sizeDescription)
                                .font(.subheadline.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.blue)
                        }

                        Divider()

                        HStack {
                            Label("Installed: \(dateFormatter.string(from: model.installDate))", systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()

                            if !isActive {
                                Button {
                                    manager.setDefaultOfflineModel(model.modelName)
                                } label: {
                                    Label("Set as Active Model", systemImage: "star")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        if let validation = model.validationStatus {
                            HStack(spacing: 6) {
                                Image(systemName: validation.hasPrefix("Error") ? "exclamationmark.octagon.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(validation.hasPrefix("Error") ? .red : .green)
                                Text(validation)
                                    .font(.caption)
                                    .foregroundStyle(validation.hasPrefix("Error") ? .red : .secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(validation.hasPrefix("Error") ? Color.red.opacity(0.08) : Color.green.opacity(0.06))
                            .cornerRadius(8)
                        }

                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    await testModel(model)
                                }
                            } label: {
                                Label("Run Diagnostics", systemImage: "waveform.path.ecg")
                                    .font(.subheadline.bold())
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Button(role: .destructive) {
                                deleteModel(model)
                            } label: {
                                Label("Remove Model", systemImage: "trash")
                                    .font(.subheadline.bold())
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .liquidGlass(style: .standard, cornerRadius: 12)
                }
            }
        }
    }

    private func deleteModel(_ model: InstalledOfflineModelRecord) {
        let metadata = OfflineModelMetadata(
            modelName: model.modelName,
            providerName: "Offline",
            description: "Locally Stored Model",
            modelSize: model.sizeDescription,
            modelSizeBytes: model.metadata.totalSize,
            tags: ["offline", "installed"],
            downloadCount: 0,
            modelURL: URL(fileURLWithPath: model.localModelPath),
            files: [],
            isQuantized: false
        )
        manager.removeModel(metadata)
    }

    private func testModel(_ model: InstalledOfflineModelRecord) async {
        do {
            try await OfflineModelRunner.shared.loadModel(at: URL(fileURLWithPath: model.localModelPath))
            let reply = try await OfflineModelRunner.shared.generateResponse(prompt: "Hello from SwiftCode")
            let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedReply.isEmpty {
                manager.updateValidationStatus(for: model.modelName, status: "Error: Empty response", clearLocalPath: false)
            } else {
                manager.updateValidationStatus(for: model.modelName, status: "Valid: \(trimmedReply.prefix(60))", clearLocalPath: false)
            }
        } catch {
            manager.updateValidationStatus(for: model.modelName, status: "Error: \(error.localizedDescription)", clearLocalPath: false)
        }
    }
}
