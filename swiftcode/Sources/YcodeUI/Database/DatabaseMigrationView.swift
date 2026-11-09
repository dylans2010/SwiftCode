import YcodeIDECore
import SwiftCodeCloud
import SwiftUI

struct StoredDatabaseMigration: Identifiable, Codable, Hashable {
    var id: UUID
    var version: String
    var name: String
    var sqlUp: String
    var sqlDown: String
    var appliedAt: Date?

    init(id: UUID = UUID(), version: String, name: String, sqlUp: String, sqlDown: String, appliedAt: Date? = nil) {
        self.id = id
        self.version = version
        self.name = name
        self.sqlUp = sqlUp
        self.sqlDown = sqlDown
        self.appliedAt = appliedAt
    }
}

@MainActor
final class DatabaseMigrationListManager: ObservableObject {
    static let shared = DatabaseMigrationListManager()

    @Published var migrations: [StoredDatabaseMigration] = []

    private init() {
        loadMigrations()
    }

    func generateMigration(name: String, sqlUp: String, sqlDown: String) -> StoredDatabaseMigration {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let version = formatter.string(from: Date())

        let migration = StoredDatabaseMigration(
            version: version,
            name: name,
            sqlUp: sqlUp,
            sqlDown: sqlDown
        )

        migrations.append(migration)
        saveMigrations()
        return migration
    }

    func applyMigration(_ migration: StoredDatabaseMigration, on connection: DatabaseConnection) async throws {
        switch connection.provider {
        case .sqlite:
            guard let filePath = connection.sqliteFilePath else { return }
            _ = try DatabaseManager.shared.executeSQLiteQuery(filePath: filePath, sql: migration.sqlUp)
        case .supabase:
            _ = try await SupabaseService().executeSQL(connection: connection, sql: migration.sqlUp)
        default:
            break
        }

        if let idx = migrations.firstIndex(where: { $0.id == migration.id }) {
            migrations[idx].appliedAt = Date()
            saveMigrations()
        }
    }

    func rollbackMigration(_ migration: StoredDatabaseMigration, on connection: DatabaseConnection) async throws {
        switch connection.provider {
        case .sqlite:
            guard let filePath = connection.sqliteFilePath else { return }
            _ = try DatabaseManager.shared.executeSQLiteQuery(filePath: filePath, sql: migration.sqlDown)
        case .supabase:
            _ = try await SupabaseService().executeSQL(connection: connection, sql: migration.sqlDown)
        default:
            break
        }

        if let idx = migrations.firstIndex(where: { $0.id == migration.id }) {
            migrations[idx].appliedAt = nil
            saveMigrations()
        }
    }

    private func loadMigrations() {
        if let data = UserDefaults.standard.data(forKey: "com.swiftcode.database.migrations"),
           let decoded = try? JSONDecoder().decode([StoredDatabaseMigration].self, from: data) {
            self.migrations = decoded
        }
    }

    private func saveMigrations() {
        if let encoded = try? JSONEncoder().encode(migrations) {
            UserDefaults.standard.set(encoded, forKey: "com.swiftcode.database.migrations")
        }
    }
}

struct DatabaseMigrationView: View {
    @EnvironmentObject var connManager: DatabaseConnectionManager
    @StateObject private var migManager = DatabaseMigrationListManager.shared

    @State private var name = ""
    @State private var sqlUp = "CREATE TABLE logs (\n    id INTEGER PRIMARY KEY,\n    message TEXT\n);"
    @State private var sqlDown = "DROP TABLE IF EXISTS logs;"
    @State private var resultMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Generate New Migration")
                        .font(.headline)

                    TextField("Migration Name (e.g. add_logs_table)", text: $name)

                    Text("SQL Up (Apply)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $sqlUp)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)
                        .border(Color.secondary.opacity(0.2))

                    Text("SQL Down (Rollback)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $sqlDown)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)
                        .border(Color.secondary.opacity(0.2))

                    Button("Generate Migration File") {
                        generateMigration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || sqlUp.isEmpty || sqlDown.isEmpty)
                }
                .padding()
                .frame(width: 320)
                .liquidGlass(style: .subtle, cornerRadius: 0)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Migration History")
                        .font(.headline)

                    if migManager.migrations.isEmpty {
                        ContentUnavailableView("No migrations generated", systemImage: "arrow.triangle.2.circlepath", description: Text("Created migration scripts will appear here."))
                    } else {
                        List(migManager.migrations) { mig in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(mig.version)_\(mig.name)")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    if let appliedAt = mig.appliedAt {
                                        Text("Applied (\(DatabaseFormatter.formatDate(appliedAt)))")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("Pending")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }

                                HStack {
                                    if mig.appliedAt == nil {
                                        Button("Apply") {
                                            applyMigration(mig)
                                        }
                                        .buttonStyle(.bordered)
                                    } else {
                                        Button("Rollback") {
                                            rollbackMigration(mig)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }

            if !resultMessage.isEmpty {
                Divider()
                Text(resultMessage)
                    .foregroundColor(.blue)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
            }
        }
    }

    private func generateMigration() {
        _ = migManager.generateMigration(name: name, sqlUp: sqlUp, sqlDown: sqlDown)
        resultMessage = "Migration file generated successfully!"
        name = ""
    }

    private func applyMigration(_ mig: StoredDatabaseMigration) {
        guard let conn = connManager.activeConnection else { return }
        Task {
            do {
                try await migManager.applyMigration(mig, on: conn)
                resultMessage = "Successfully applied migration \(mig.name)!"
            } catch {
                resultMessage = "Failed to apply: \(error.localizedDescription)"
            }
        }
    }

    private func rollbackMigration(_ mig: StoredDatabaseMigration) {
        guard let conn = connManager.activeConnection else { return }
        Task {
            do {
                try await migManager.rollbackMigration(mig, on: conn)
                resultMessage = "Successfully rolled back migration \(mig.name)!"
            } catch {
                resultMessage = "Failed to rollback: \(error.localizedDescription)"
            }
        }
    }
}
