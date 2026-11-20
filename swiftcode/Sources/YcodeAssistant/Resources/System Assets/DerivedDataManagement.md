<!-- system-index-depends: XcodebuildMastery.md -->
# DerivedData Management, Module Caches & Cache Diagnostics

Guidelines for inspecting, cleaning, and optimizing Xcode DerivedData, Clang module caches, and index-store directories.

---

## 1. Structure of DerivedData
```
DerivedData/<ProjectName>-<Hash>/
├── Build/
│   ├── Intermediates.noindex/   # Object files (.o), precompiled headers (.pch)
│   └── Products/                # Final binaries, frameworks, .app bundles
├── Index.noindex/               # Symbol index, syntax maps, call graphs
├── Logs/                        # Build, test, and debug activity logs
└── ModuleCache.noindex/         # Precompiled Clang and Swift modules
```

---

## 2. Diagnosing Build Lockups & Cache Corruption
Symptoms of corrupted DerivedData:
- "Module 'XYZ' was created by a different version of the compiler"
- Infinite recompilation of unchanged source files.
- Stale symbol errors where Xcode fails to see recently added methods.

### Surgical Cleanup Commands:
```bash
# Surgical removal of module cache without deleting whole DerivedData
rm -rf ./build/DerivedData/ModuleCache.noindex/

# Targeted removal of project build intermediates
rm -rf ./build/DerivedData/Build/Intermediates.noindex/<TargetName>.build
```

---

## 3. Optimizing DerivedData for Fast Agent Iteration
- Place DerivedData on fast APFS volumes.
- Enable shared package caches across projects via `SWIFTPM_MODULECACHE_PATH`.
- Exclude `build/DerivedData` from git tracking in `.gitignore`.
