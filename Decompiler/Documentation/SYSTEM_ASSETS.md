# YcodeDecompiler — System Assets (Decompile Assist)

Decompile Assist's system prompt is assembled from Markdown "system asset"
documents bundled inside the `YcodeDecompiler` module. Implemented by
`AI/DecompileAssist/DecompileAssistAssetLoader.swift`; documents live in
`Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist/`.

## Asset inventory (all present)

### Required — missing any ⇒ hard error

| Asset | File |
|---|---|
| IDENTITY | `IDENTITY.md` |
| SOUL | `SOUL.md` |
| SYSTEM | `SYSTEM.md` |
| MEMORY | `MEMORY.md` |
| SECURITY | `SECURITY.md` |

### Optional — added in priority order, truncated first

| Asset | Added when |
|---|---|
| `FRIENDLY_MODE.md` / `MASTER_MODE.md` | always — matches `DecompilerSession.Mode` |
| `MACHO.md` / `ELF.md` / `PE.md` | loaded `BinaryImage.format` matches |
| `ARM64.md` / `X86_64.md` | `image.architecture` is arm64/arm64_32 or x86_64 |
| `DECOMPILATION.md`, `TOOLS.md`, `OUTPUT_FORMAT.md`, `EVIDENCE.md`, `LIMITATIONS.md` | always (if present) |

All 17 files exist in the resource directory today (verified by listing).

## Loading (`DecompileAssistAssetLoader`)

`init()` builds the candidate directory list — directories that don't
exist are dropped, standardized-path duplicates removed:

1. `Bundle.module.resourceURL/SystemAssets/DecompileAssist` (SwiftPM)
2. `Bundle.main.resourceURL/SystemAssets/DecompileAssist`
3. `Bundle.main.resourceURL/Decompiler/SystemAssets/DecompileAssist`
   (XcodeGen app resources layout)
4. `#filePath`-relative:
   `Sources/YcodeDecompiler/Resources/SystemAssets/DecompileAssist`

`asset(named:)` returns the first non-empty `<name>.md` found across the
directories, `nil` otherwise.

## Prompt assembly and bounding

`corePrompt(mode:architecture:format:)`:

1. Loads all five required assets; throws
   `DecompilerError.engineUnavailable("Decompile Assist system assets
   missing: …")` listing every missing file. Required docs are **never
   truncated**.
2. Collects optional docs in the priority order above.
3. Renders each as `## NAME\n\n<body>` joined by `\n\n---\n\n`.
4. Enforces `promptBudget = 12_000` chars: while over budget it drops
   optional docs **from the end of the priority list first**; a kept doc
   may be hard-truncated (≥200-char allowance, suffixed
   `\n\n…(truncated)`).
5. Final hard cap: prefix-truncate with `\n\n…(prompt truncated)`.

The assembled prompt is installed as the SDK session's system
instructions by `DecompileAssistSession.ensureSDKSession`.

## Evidence

| Claim | Level |
|---|---|
| Asset names, required set, search order, budget algorithm | 1 — `DecompileAssistAssetLoader.swift` |
| Asset files present | 1 — directory listing (17 `.md` files) |
