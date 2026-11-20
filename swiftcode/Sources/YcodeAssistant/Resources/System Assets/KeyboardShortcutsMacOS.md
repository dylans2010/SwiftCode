# Keyboard Shortcuts on macOS

<!-- system-index-depends: SwiftUIArchitecture.md -->

Keyboard shortcuts are how power users drive a Mac app. This asset covers
how Assist designs shortcuts that are discoverable, consistent, and free
of conflicts.

## When to retrieve

- The user is adding shortcuts or a menu command.
- A shortcut conflicts, does nothing, or behaves unexpectedly.
- A workflow needs keyboard-driven operation.

## Design rules

- Every shortcut appears in a menu. A shortcut with no menu item is
  undiscoverable.
- Follow platform conventions: the standard shortcuts for cut, copy,
  paste, undo, save, and find mean what the system says they mean.
- Use the Command key for app commands, and avoid overriding system
  shortcuts the user relies on everywhere.
- Keep shortcuts stable across releases. A changed shortcut breaks
  muscle memory.
- Provide shortcuts for the actions users repeat, not for every action
  that exists. A menu full of shortcuts is noise.

## What Assist checks

- Conflicts: two commands sharing a shortcut, or a shortcut that
  collides with a system or accessibility shortcut.
- Context: a shortcut that acts in one view and does nothing in another,
  without explanation.
- Discoverability: the menu shows the shortcut, and the shortcut works
  from the places the menu says it does.
- Consistency: the same action has the same shortcut in every window and
  mode.

## Implementation notes

- Shortcuts belong to commands, not to views. A command that works from
  any focused view is a command; a shortcut wired to one button is a
  trap.
- Disabled commands show as disabled in the menu; their shortcuts do
  nothing while disabled, and the menu says why.
- Custom shortcuts the user defines must be validated for conflicts and
  stored per user, not per install.

## Common mistakes

- Defining a shortcut that duplicates a system shortcut and wondering
  why it never fires.
- Wiring a shortcut to a view that is not always focused.
- Changing a shortcut silently in a release.
- Giving a destructive action a shortcut that is easy to hit by accident.

## Cross-references

- SwiftUI architecture: `SwiftUIArchitecture.md`
- Menu bar extras: `MenuBarExtras.md`
- Window management: `WindowManagementMacOS.md`

## Limits

- Assist designs the shortcut set and the checks. The exact bindings
  remain the user's product decision.
