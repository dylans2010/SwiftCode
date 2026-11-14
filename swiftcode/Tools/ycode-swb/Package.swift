// swift-tools-version: 6.0













import PackageDescription

let package = Package(
    name: "ycode-swb",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-build", revision: "5d44ed6ba16c53d56cac5fc6a2d572635aa4a979"),
    ],
    targets: [
        
        
        .target(name: "YcodeSigning"),
        
        .target(name: "YcodeRelease"),
        .executableTarget(name: "ycode-swb", dependencies: [.product(name: "SwiftBuild", package: "swift-build"), "YcodeSigning", "YcodeRelease"]),
    ]
)
