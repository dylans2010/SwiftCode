// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Test",
    platforms: [.iOS(.v17)],
    targets: [
        .executableTarget(name: "Test", path: "Sources")
    ]
)