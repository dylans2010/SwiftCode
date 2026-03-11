# Local Building

This folder is reserved for temporary/helper build-generation artifacts used by `ProjectBuilderManager`.

At runtime, SwiftCode writes:
- `project.yml` for XcodeGen
- `Generated/Info.plist` when a user project does not provide one

Generated `.xcodeproj` / `.xcworkspace` files are created for the **user project**, not for SwiftCode itself.
