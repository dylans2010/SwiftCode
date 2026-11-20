# Widgets and Live Activities

<!-- system-index-depends: AppLifecycleAndScenes.md -->

Widgets put a slice of the app on the desktop and in Notification Center;
Live Activities put a live slice on the Lock Screen. Both run outside the
app, in a separate process, with strict limits on what they can do.

## What widgets can and cannot do

- A widget shows glanceable, read-only content: the next event, a count,
  a status, a progress bar. It is not a mini app.
- Widgets cannot scroll, play video, accept text input, or run arbitrary
  code on a tap. A tap opens the app (deep-linked to the item).
- Widget content updates on a timeline the system controls, not on demand.
  The system budgets updates; an app that requests them constantly gets
  throttled.
- Keep widget views simple and fast to render. A widget that takes a
  second to draw is a widget the system stops showing.

## Architecture

- Put widget code in a Widget Extension target with its own bundle ID.
- Share data between the app and the widget through an App Group container
  (`UserDefaults(suiteName:)` for small state, shared files for larger
  data) or through `CoreData` / `SwiftData` with a shared store.
- Share model code through a framework or a shared Swift package target.
  Do not duplicate the model in the app target and the widget target.
- The widget reads the shared store; it never talks to the network
  directly except through its timeline provider's refresh.

## Timelines and updates

- The timeline provider supplies entries for future times. Provide entries
  for the next few hours, not just the current moment.
- Use `WidgetCenter.shared.reloadAllTimelines()` sparingly: after the user
  changes something meaningful, not after every keystroke.
- For time-sensitive data, prefer a timeline entry dated in the future
  over a reload. The system renders the future entry without waking the app.
- Keep the data behind a timeline entry small. The widget process has a
  tight memory limit and is killed if it exceeds it.

## Live Activities

- A Live Activity shows a live, time-bounded event: a build, a timer, a
  download. Start it with `Activity.request` and end it explicitly.
- Update the activity's dynamic content with `Activity.update`, but
  throttle updates: the system limits how often an activity may refresh.
- Always provide an end state. An activity that never ends stays on the
  Lock Screen until the system kills it, which looks like a bug.
- Live Activities require the user to start them (or the app to start one
  for an event the user began). Never start one silently.

## Design and privacy

- Design widgets for all sizes the app offers, and for light and dark
  mode. A widget that only looks right at one size is unfinished.
- Never show sensitive content in a widget or Live Activity: they are
  visible on the Lock Screen and the desktop without unlocking.
- Test the widget with no data, with stale data, and with the app never
  launched, since the widget can run before the app ever opens.

## Verification

- Install the widget in every size and confirm it renders and deep-links.
- Change data in the app and confirm the widget updates within its budget.
- Start, update, and end a Live Activity and confirm it disappears.
- Kill the app and confirm the widget still shows its last good data.
