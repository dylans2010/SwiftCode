# Drag and Drop on macOS

<!-- system-index-depends: SwiftUIArchitecture.md -->

Drag and drop is a core macOS interaction: files, text, images, and custom
data move between views and apps. This asset covers how Assist designs
drag and drop that feels native and fails gracefully.

## When to retrieve

- The user is adding drag and drop to a view or a window.
- A drag works in one direction but not the other.
- Dropped data arrives in the wrong form or not at all.

## Design rules

- Declare the types the view accepts, and accept only those. A drop
  target that accepts everything accepts garbage.
- Provide a visible drop indication: highlight the target while a valid
  drag hovers over it, and clear it when the drag leaves.
- Support the standard forms first: files, text, images, and URLs. Custom
  types come after the standard ones work.
- A drag source offers the richest type it can and a plain fallback. A
  custom type with no plain fallback cannot be dropped into other apps.
- Drops are undoable where the operation is destructive. Moving a file
  into the trash is not the same as copying it.

## Data rules

- Validate dropped data before acting on it. A file that claims to be an
  image may not be one.
- Handle multiple items: a drop can carry many files, and the app must
  process all of them or reject the drop cleanly.
- Handle promised files: some sources provide data lazily, and the app
  must wait for the promise instead of reading a file that does not exist
  yet.
- Never trust a dropped path without checking it exists and is readable.
  Paths from other apps can be stale or sandboxed away.

## Failure handling

- A rejected drop explains why, briefly, in the UI. Silence teaches the
  user nothing.
- A partially successful multi-file drop reports which items succeeded
  and which failed.
- A drop that cannot be completed leaves the app in its prior state. No
  half-moved files.

## Common mistakes

- Accepting a drop type the view cannot actually handle.
- Forgetting the drop highlight, so users cannot tell where a drop lands.
- Reading a dropped file synchronously on the main thread for a large
  file.
- Assuming a drag source and a drop target in the same app can skip
  validation. They cannot; the data still crosses a boundary.

## Cross-references

- SwiftUI architecture: `SwiftUIArchitecture.md`
- File operations: `FileOperations.md`
- Sharing: `SharingAndShareSheet.md`

## Limits

- Assist designs the interaction and the data contract. Sandbox and
  security-scoped access for dropped files follow the app's existing
  security model; see `AppSandboxSecurity.md`.
