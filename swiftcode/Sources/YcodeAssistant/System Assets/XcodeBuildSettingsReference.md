<!-- system-index-depends: XcodebuildMastery.md -->
# Xcode Build Settings Reference & Compiler Flags

Authoritative reference for essential Xcode build settings, Swift compiler flags, and warning configurations across Apple platforms.

---

## 1. Essential Swift Compiler Settings
- `SWIFT_VERSION = 6.0`: Sets the Swift language version.
- `SWIFT_STRICT_CONCURRENCY = complete`: Enforces compile-time data-race safety.
- `OTHER_SWIFT_FLAGS`: Passes custom flags to the Swift compiler (e.g., `-Xfrontend -warn-long-function-bodies=200`).
- `SWIFT_OPTIMIZATION_LEVEL`:
  - `-Onone`: Debug builds (no optimization, fast compilation).
  - `-O`: Release builds (speed optimized).
  - `-Osize`: Small binary size optimized.

---

## 2. Clang & Linking Settings
- `ENABLE_HARDENED_RUNTIME = YES`: Required for macOS notarization.
- `DEAD_CODE_STRIPPING = YES`: Removes unreferenced functions and symbols from final binary.
- `STRIP_INSTALLED_PRODUCT = YES`: Strips debug symbol tables in Release archives.
- `OTHER_LDFLAGS`: Passes custom linker flags (e.g. `-ObjC`, `-dead_strip`).

---

## 3. Configuration Files (`.xcconfig`)
Always extract project build settings into clean, version-controlled `.xcconfig` files rather than storing them in binary project blobs:
```
// Config/Release.xcconfig
#include "Common.xcconfig"

SWIFT_OPTIMIZATION_LEVEL = -O
ENABLE_TESTABILITY = NO
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
```
