import Foundation

public struct FileInspectorInfo: Equatable {
    public var workingCopy: String?
    public var relativePath: String?
    public var memberships: [TargetMembership]
    public var inSynchronizedFolder: Bool
    public var isPackageFile: Bool
    public var gitStatus: GitRepository.FileStatus?
    public var buildSettingsTarget: String?
    public var buildConfigurations: [String]
    public var buildSettings: [String: [String: String]]
    public var activeBuildConfiguration: String?

    
    
    
    public static let buildSettingKeys: Set<String> = [
        "SDKROOT", "PLATFORM_NAME",
        "PRODUCT_BUNDLE_IDENTIFIER", "PRODUCT_NAME", "PRODUCT_MODULE_NAME",
        "SWIFT_VERSION", "CLANG_ENABLE_MODULES",
        "IPHONEOS_DEPLOYMENT_TARGET", "MACOSX_DEPLOYMENT_TARGET",
        "TVOS_DEPLOYMENT_TARGET", "WATCHOS_DEPLOYMENT_TARGET", "XROS_DEPLOYMENT_TARGET",
        "MARKETING_VERSION", "CURRENT_PROJECT_VERSION",
        "TARGETED_DEVICE_FAMILY", "CODE_SIGN_STYLE", "DEVELOPMENT_TEAM",
        "SWIFT_EMIT_LOC_STRINGS", "GENERATE_INFOPLIST_FILE", "INFOPLIST_KEY_CFBundleDisplayName",
    ]

    public init(workingCopy: String? = nil, relativePath: String? = nil, memberships: [TargetMembership] = [],
                inSynchronizedFolder: Bool = false, isPackageFile: Bool = false,
                gitStatus: GitRepository.FileStatus? = nil, buildSettingsTarget: String? = nil,
                buildConfigurations: [String] = [], buildSettings: [String: [String: String]] = [:],
                activeBuildConfiguration: String? = nil) {
        self.workingCopy = workingCopy
        self.relativePath = relativePath
        self.memberships = memberships
        self.inSynchronizedFolder = inSynchronizedFolder
        self.isPackageFile = isPackageFile
        self.gitStatus = gitStatus
        self.buildSettingsTarget = buildSettingsTarget
        self.buildConfigurations = buildConfigurations
        self.buildSettings = buildSettings
        self.activeBuildConfiguration = activeBuildConfiguration
    }
}
