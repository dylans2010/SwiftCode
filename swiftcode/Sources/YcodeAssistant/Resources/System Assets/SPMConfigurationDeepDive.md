<!-- system-index-depends: ModularAppDesign.md -->
# Swift Package Manager (SPM) Manifest Configuration

In-depth technical specification for authoring, configuring, and maintaining `Package.swift` manifests in modern Swift 5.9 / 6.0 projects.

---

## 1. Anatomy of a Modern `Package.swift`
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftCodeCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "SwiftCodeCore", targets: ["SwiftCodeCore"]),
        .executable(name: "swiftcode-cli", targets: ["swiftcode-cli"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .target(
            name: "SwiftCodeCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftCodeCoreTests",
            dependencies: ["SwiftCodeCore"]
        )
    ]
)
```

---

## 2. Resource Management: `.copy` vs `.process`
- **`.process("path")`:** Optimized for asset catalogs, CoreData models, and files that Xcode optimizes during build.
- **`.copy("path")`:** Preserves exact directory structure and file contents verbatim without modification.

---

## 3. Dependency Resolution & Package.resolved
- SPM locks exact Git commit hashes into `Package.resolved`.
- Resolve dependencies via CLI: `swift package resolve` or `xcodebuild -resolvePackageDependencies`.
- Update dependencies within semantic limits via: `swift package update`.
