# MLXSwift Foundation Integration

This folder is now wired to Apple's **MLX Swift** ecosystem through Swift Package Manager in `SwiftCode.xcodeproj`.

## Integrated packages

The app target now links these products from [`ml-explore/mlx-swift`](https://github.com/ml-explore/mlx-swift):

- `MLX`
- `MLXNN`
- `MLXOptimizers`
- `MLXRandom`

## What changed

- `MLXIntegration.swift` now imports and validates runtime symbols from multiple MLX packages.
- `MLXModelContainer.swift` uses shared offline model/tokenizer protocols decoupled from any single model family loader.
- The Xcode project includes MLX Swift package references and product dependencies, so checkout/build resolves packages automatically (no manual package add steps required).

## Updating MLX Swift

1. Open `SwiftCode.xcodeproj` in Xcode.
2. Go to **Package Dependencies**.
3. Update `mlx-swift` to a newer compatible version.
4. Build the `SwiftCode` target and verify the Offline Models flow.

> Recommendation: update MLX packages and model-runtime adapter code together, because model-loading APIs may evolve between releases.

## Next step for model-family support

`UniversalModelLoader` now performs config-driven architecture detection (`model_type` in `config.json`), tokenizer discovery, and safetensors file resolution. Architecture routing is centralized and extendable so new HuggingFace model types can be added without changing call sites. Runtime-specific MLX builders can be wired per architecture in `GenericMLXArchitectureBuilders`.
