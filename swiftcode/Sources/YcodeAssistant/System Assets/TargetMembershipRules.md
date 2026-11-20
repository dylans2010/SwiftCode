<!-- system-index-depends: XcodebuildMastery.md, SPMConfigurationDeepDive.md -->
# Target Membership, File References & PBXProj Integrity

Guidelines for managing Xcode target memberships, compile sources phases, and avoiding duplicate symbols or missing references.

---

## 1. The PBXProj Target Membership Model
In Xcode projects (`project.pbxproj`), adding a file to the project directory does NOT automatically make it compile.
Every source file must be registered in three sections:
1. `PBXFileReference`: Declares the physical file on disk.
2. `PBXGroup`: Displays the file in the project navigator tree.
3. `PBXBuildFile`: Associates the file reference with a `PBXSourcesBuildPhase` of one or more targets.

---

## 2. Common PBXProj Errors & Fixes
- **"Undefined symbol for architecture":** The Swift or C file exists on disk, but its `PBXBuildFile` entry was not added to the target's `PBXSourcesBuildPhase`.
- **"Duplicate symbol":** The file was accidentally added twice to the compile sources phase, or defined in both an app target and a linked static library.
- **Missing Resource Error:** An asset catalog, plist, or JSON file was added to Compile Sources instead of the `PBXResourcesBuildPhase`.

---

## 3. Assist Tooling for Target Management
Use `project_mutation_controller` to register newly created files rather than manually editing raw PBX UUIDs:
- `action: "add"`: Registers file reference and compiles sources membership.
- `action: "remove"`: Safely detaches build phases and file references.
- `action: "repair"`: Validates project integrity and repairs broken references.
