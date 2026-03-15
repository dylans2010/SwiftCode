// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftCode",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "SwiftCodeApp", targets: ["SwiftCodeApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.19.0")
    ],
    targets: [
        .target(
            name: "SwiftCodeApp",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift")
            ],
            path: "SwiftCode",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "Preview Content"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
