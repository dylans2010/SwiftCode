# Haptics and Feedback

<!-- system-index-depends: SwiftUIArchitecture.md -->

Feedback is how an interface confirms an action: a sound, a haptic, or a
visual change. This asset covers how Assist designs feedback that confirms
without annoying, and that respects the user's settings.

## When to retrieve

- The user is adding sounds, haptics, or confirmation feedback.
- Feedback feels excessive, missing, or inconsistent.
- An action needs a success or failure signal.

## Design rules

- Feedback confirms an action the user took, or warns about a state that
  needs attention. It never narrates routine operation.
- Match the feedback to the action: a small action gets a small signal.
  A destructive action gets a distinct, unmistakable one.
- Respect system settings. If the user disabled sounds or haptics, the
  app is silent. There is no exception for "important" feedback.
- Keep feedback consistent across the app: the same action produces the
  same signal everywhere.
- Provide a non-sensory alternative. A sound-only confirmation excludes
  users who cannot hear it; a haptic-only one excludes users who cannot
  feel it.

## What to check

- Every destructive action has a confirmation signal and a way back.
- Success and failure sound and feel different from each other.
- Feedback fires once per action, not once per internal step.
- Feedback does not block the interface. A sound that freezes the UI is
  a bug, not feedback.
- Volume and intensity are modest by default. The user can turn them up.

## Common mistakes

- Adding feedback to every button press, which trains users to ignore it.
- Using the error signal for routine validation, which teaches users that
  errors are normal.
- Playing feedback on the main thread in a way that delays the action it
  confirms.
- Ignoring the user's accessibility and sound settings.

## Cross-references

- SwiftUI architecture: `SwiftUIArchitecture.md`
- Accessibility audit: `AccessibilityAuditAndRemediation.md`
- Notifications: `NotificationsMacOS.md`

## Limits

- Feedback design is a product decision. Assist describes the discipline
  and the checks; the exact sounds and patterns remain the user's choice.
