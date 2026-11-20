# Window Management on macOS

<!-- system-index-depends: SwiftUIArchitecture.md -->

macOS users expect windows to behave like Mac windows: resizable,
restorable, tabbed, full-screen capable, and remembered between launches.
A Mac app that fights the windowing system feels broken even when its
content is right.

## Window basics

- Use `WindowGroup` for document windows and `Window` / `Settings` scenes
  for auxiliary windows. One scene per window kind, not one window per
  special case.
- Give every window a sensible default size and a minimum size. A window
  that can shrink to nothing is a window the user can lose.
- Set the window title to the document or view name, and show the dirty
  indicator when there are unsaved changes.
- Windows must be resizable unless there is a genuine reason they cannot
  be. A fixed-size window on a Mac is a bug report waiting to happen.

## Tabs, full screen, and spaces

- Support tabbed windows (`NSWindow.allowsAutomaticWindowTabbing`) unless
  the app's windows are genuinely not tabbable. Users expect Cmd-T to work.
- Support full screen and Split View. Custom window chrome must not break
  the full-screen transition or the traffic lights.
- Remember which space and display a window was on. The system restores
  this for well-behaved apps; custom window code must not defeat it.
- Do not fight Mission Control or Exposé with always-on-top windows.
  Always-on-top is for alerts, not for main windows.

## State restoration

- Persist window frame, sidebar width, selected tab, and split positions
  with `NSWindowRestoration` or SwiftUI's scene storage. Restore them on
  launch so the app reopens exactly as the user left it.
- Restoration must be fast and silent. If restoring a window requires
  loading a document, load it in the background and show the window
  immediately with a placeholder.
- If a document no longer exists, restore the window anyway with an honest
  empty state, or close it with an explanation. Never crash on a missing
  file at launch.
- Test restoration with the app killed from the Dock, not just quit cleanly.

## Multiple windows and coordination

- Each window owns its own state; shared state lives in the model, not in
  a window controller. Two windows showing the same document must stay in
  sync through the model.
- Commands in the menu bar act on the key window. Make sure the key window
  is the one the user thinks it is.
- Closing the last window of a document app should not quit the app; it
  should leave the app running with no windows, ready to open another.
- Do not open a new window for every action. A window per search result or
  per settings page is window spam.

## Sizing, layout, and accessibility

- Content must reflow when the window resizes. Fixed layouts that clip at
  small sizes are unfinished.
- Respect the user's text size and Reduce Motion settings in every window.
- Every window must be fully keyboard navigable, including its toolbar
  and sidebar.

## Verification

- Quit and relaunch: frames, tabs, and sidebar widths are restored.
- Open two windows on the same document and edit in one; the other updates.
- Enter and exit full screen, tab windows, and move one to another display.
