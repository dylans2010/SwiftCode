import SwiftUI

struct ConflictResolverView: View {
    let conflict: BranchConflict
    @ObservedObject var manager: CollaborationManager
    @Environment(\.dismiss) private var dismiss

    @State private var resolution: ConflictResolutionChoice = .keepOurs
    @State private var manualContent: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Resolution Strategy", selection: $resolution) {
                    ForEach(ConflictResolutionChoice.allCases, id: \.self) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                HStack(spacing: 0) {
                    VStack {
                        Text("Current (Ours)")
                            .font(.caption.bold())
                        TextEditor(text: .constant(conflict.localContent))
                            .font(.system(size: 10, design: .monospaced))
                            .disabled(true)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.05))

                    Divider()

                    VStack {
                        Text("Incoming (Theirs)")
                            .font(.caption.bold())
                        TextEditor(text: .constant(conflict.remoteContent))
                            .font(.system(size: 10, design: .monospaced))
                            .disabled(true)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.05))
                }
                .frame(maxHeight: .infinity)

                VStack(alignment: .leading) {
                    Text("Result Preview")
                        .font(.caption.bold())
                        .padding(.horizontal)

                    TextEditor(text: $manualContent)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 150)
                        .padding(4)
                        .border(Color.gray.opacity(0.3))
                        .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Resolve Conflict: \(conflict.filePath)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Resolve") {
                        manager.resolveConflict(conflict.id, using: resolution, actorID: manager.creatorID)
                        dismiss()
                    }
                }
            }
            .onAppear {
                manualContent = conflict.localContent
            }
            .onChange(of: resolution) {
                updateManualContent()
            }
        }
    }

    private func updateManualContent() {
        switch resolution {
        case .keepOurs: manualContent = conflict.localContent
        case .keepTheirs: manualContent = conflict.remoteContent
        case .mergeBoth: manualContent = conflict.localContent + "\n" + conflict.remoteContent
        case .manual: break
        }
    }
}
