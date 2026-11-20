# Onboarding and First Run

<!-- system-index-depends: SwiftUIArchitecture.md -->

First run is the only time the user has no habits in your app yet. Good
onboarding teaches one thing at a time, gets out of the way, and never
asks for anything before showing value.

## Principles

- Show value before asking for setup. Let the user see the app working
  with sample content before demanding accounts, permissions, or folders.
- One screen, one decision. A five-step wizard with three choices per step
  is a form, not an welcome.
- Every step must be skippable, and skipping must leave the app usable.
  A user who skips setup is a user, not a failure.
- Never block first run on a network call. If the server is unreachable,
  onboarding must still complete.

## What to ask, and when

- Permissions (notifications, folders, accessibility) belong at the moment
  the feature that needs them is first used, not in a permission gauntlet.
- Account sign-in belongs after the user has seen what the account adds.
  Offer a guest or local mode first where the product allows it.
- Folder or workspace selection belongs on first real use of the feature,
  with a sensible default already chosen.
- Appearance and preference choices can wait until Settings; do not spend
  a first-run screen on them.

## State and resumability

- Persist onboarding progress in `UserDefaults` or a small state file so
  a crash or quit mid-onboarding resumes where it left off.
- Record a single `hasCompletedOnboarding` flag, plus a version number.
  When the app ships a new major feature, a one-screen "what's new" is
  fine; re-running the whole flow is not.
- Keep onboarding UI in the app, not in a separate window that can be lost
  behind other apps. If it is a window, it must be the key window on launch
  until dismissed.

## Sample content and empty states

- Ship real, clearly-marked sample content the user can delete in one
  action. An empty app teaches nothing; a populated one invites play.
- Label sample content as sample so it is never mistaken for the user's
  work, and never sync it to their account.
- The first empty state after onboarding should repeat the one action that
  matters most, with a visible button, not a paragraph of instructions.

## Accessibility and polish

- Every onboarding screen must work with VoiceOver and full keyboard
  navigation. The first run is the worst place to discover it does not.
- Buttons need visible focus rings; text needs real contrast; motion
  must respect Reduce Motion.
- Localize every string from day one. Retrofitting localization onto
  onboarding screens is how strings ship untranslated.

## Verification

- Delete all app state and run first launch cold, three times in a row.
- Skip every step and confirm the app is usable.
- Deny every permission and confirm nothing crashes or dead-ends.
- Quit mid-flow and relaunch to confirm it resumes correctly.
