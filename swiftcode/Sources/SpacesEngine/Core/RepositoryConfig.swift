import Foundation

/// Repository configuration stored in `.spaces/config.json`.
public struct SpacesConfig: Codable, Sendable {
    public var version: Int
    public var core: Core
    public var user: User?
    public var remotes: [String: RemoteConfig]
    public var branchTracking: [String: String] // branch -> remote/branch
    public var lfs: LFSConfig
    public var extensions: [String: Bool]

    public struct Core: Codable, Sendable {
        public var defaultBranch: String
        public var fileMode: Bool
        public var symlinks: Bool
        public var autocrlf: Bool
        public var longPaths: Bool
        public init(defaultBranch: String = "main", fileMode: Bool = true,
                    symlinks: Bool = true, autocrlf: Bool = false, longPaths: Bool = true) {
            self.defaultBranch = defaultBranch
            self.fileMode = fileMode
            self.symlinks = symlinks
            self.autocrlf = autocrlf
            self.longPaths = longPaths
        }
    }

    public struct User: Codable, Sendable {
        public var name: String
        public var email: String
        public init(name: String, email: String) { self.name = name; self.email = email }
    }

    public struct RemoteConfig: Codable, Sendable {
        public var url: String
        public var fetchSpec: String
        public var pushURL: String?
        public init(url: String, fetchSpec: String = "+refs/heads/*:refs/remotes/{remote}/*",
                    pushURL: String? = nil) {
            self.url = url
            self.fetchSpec = fetchSpec
            self.pushURL = pushURL
        }
    }

    public struct LFSConfig: Codable, Sendable {
        public var enabled: Bool
        public var thresholdBytes: Int64
        public init(enabled: Bool = true, thresholdBytes: Int64 = 10 * 1024 * 1024) {
            self.enabled = enabled
            self.thresholdBytes = thresholdBytes
        }
    }

    public init(version: Int = RepositoryFormat.formatVersion,
                core: Core = Core(), user: User? = nil,
                remotes: [String: RemoteConfig] = [:],
                branchTracking: [String: String] = [:],
                lfs: LFSConfig = LFSConfig(),
                extensions: [String: Bool] = [:]) {
        self.version = version
        self.core = core
        self.user = user
        self.remotes = remotes
        self.branchTracking = branchTracking
        self.lfs = lfs
        self.extensions = extensions
    }
}
