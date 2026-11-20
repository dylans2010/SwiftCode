# Menu Bar Extras on macOS

<!-- system-index-depends: AppLifecycleAndScenes.md -->

A menu bar extra is the small icon at the right end of the menu bar that
opens a menu or a popover. It is the home of always-available controls:
status, quick actions, and glanceable state. Treat it as a secondary
interface, never as the only way to reach a feature.

## When a menu bar extra fits

- The app has persistent state worth glancing at: sync status, a timer,
  a build, a connection, a recording.
- The user benefits from one-click actions without opening the main window.
- The app is a utility whose main window is opened rarely.

Do not add a menu bar extra to a document app just because it is possible.
Every extra competes for scarce menu bar space and for the user's attention.

## NSStatusItem basics

- Create one `NSStatusItem` with `NSStatusBar.system.statusItem(withLength:)`.
- Use `NSStatusItem.variableLength` for text or a square length for an icon.
- Set `statusItem.button` image with a template image (`isTemplate = true`)
  so it renders correctly in light and dark mode and in any accent color.
- Keep the icon legible at 18pt: simple silhouette, no fine detail, no text
  smaller than the system can render.
- Hold a strong reference to the status item for the life of the app. If
  the only reference is local, the item vanishes when the variable dies.

## Menu vs. popover

- A plain `NSMenu` is the default: fast, keyboard navigable, VoiceOver
  friendly, and familiar. Prefer it for action lists and status display.
- A popover (`NSPopover` anchored to the status button) fits richer content:
  a mini player, a progress list, a settings summary. Keep it focused and
  dismissible with one click outside.
- Never open a full window from a status item click without the user asking
  for it. The menu bar extra is a shortcut, not a launcher that hijacks focus.

## Behavior rules

- The menu must reflect live state every time it opens. Rebuild or refresh
  its items in `menuWillOpen(_:)` rather than caching a stale snapshot.
- Disabled items explain themselves: use a short suffix or a submenu note
  rather than a bare greyed-out row the user cannot interpret.
- Quit must always be reachable from the menu. So must Preferences and
  opening the main window, unless the app genuinely has no main window.
- Do not animate the icon continuously. A subtle state change (filled vs.
  outline, a badge dot) communicates more than a spinning icon, and it
  costs no CPU while idle.
- Respect `NSStatusItem.isVisible`: let the user hide the extra in Settings
  and do not fight the system by recreating it.

## Lifecycle and login

- A menu-bar-only app still needs a proper app lifecycle: it must handle
  termination, updates, and `NSApplication` delegate events normally.
- If the app launches at login, say so in Settings and offer the toggle
  there; never hide a login item the user did not knowingly enable.
- On macOS, the menu bar extra shares the app's process. A crash in the
  extra is a crash of the app, so keep its code paths simple and guarded.

## Verification

- Launch the app, confirm the icon appears, opens, and closes cleanly.
- Toggle light/dark mode and confirm the template image stays legible.
- Quit from the menu, relaunch, and confirm the item returns.
- Test with VoiceOver: every menu item must have a spoken label.
