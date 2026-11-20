# Notifications on macOS

<!-- system-index-depends: AppLifecycleAndScenes.md -->

macOS notifications use `UserNotifications` (`UNUserNotificationCenter`).
They are how an app reaches the user when its window is closed or buried.
Because they interrupt, every notification must earn its interruption.

## Requesting authorization

- Ask for authorization at the moment the user enables a feature that
  needs notifications, not at first launch. A cold first-launch prompt is
  the easiest one to deny.
- Explain the value before asking: one sentence about what the user will
  get, then the system prompt.
- Request only the options you use (`.alert`, `.sound`, `.badge`). Do not
  ask for `.providesAppNotificationSettings` unless you actually provide
  in-app notification settings.
- If authorization is denied, never re-prompt with the system dialog. Offer
  a Settings deep link instead, and keep the app fully usable without it.

## Content and categories

- Keep titles short and bodies to one sentence. The notification is a
  headline, not a document; the app holds the detail.
- Use `UNNotificationCategory` with actions for the two most likely
  responses (for example, Snooze and Open). More than three actions is
  clutter.
- Set a `threadIdentifier` so related notifications group into one stack
  instead of flooding Notification Center.
- Set a `summaryArgument` so the group summary reads naturally ("3 more
  builds finished").
- Never put sensitive content in a notification body: it appears on the
  lock screen and in Notification Center. Redact tokens, file paths, and
  personal data.

## Scheduling and delivery

- Use `UNTimeIntervalNotificationTrigger` for delays and
  `UNCalendarNotificationTrigger` for clock times. Do not schedule with a
  timer and hope the app is alive.
- Re-schedule repeating notifications after the app launches; the system
  does not guarantee indefinite repeats across restarts.
- Use `UNNotificationRequest` identifiers you can cancel later. When the
  underlying event is resolved or superseded, remove the pending request
  with `removePendingNotificationRequests(withIdentifiers:)`.
- Delivered notifications that are no longer true should be removed with
  `removeDeliveredNotifications(withIdentifiers:)`. A stale notification
  is worse than none.

## Handling responses

- Implement `UNUserNotificationCenterDelegate` and set it early, before
  any notification can arrive.
- `userNotificationCenter(_:willPresent:)` decides in-foreground behavior:
  usually show the banner anyway, or suppress it when the relevant window
  is already frontmost.
- `userNotificationCenter(_:didReceive:)` routes the tap or action to the
  right window and state. Open the specific item, not just the app.
- Handle the default action and custom actions in the same place so a tap
  and a button press cannot diverge.

## Verification

- Deny permission once and confirm the app degrades gracefully.
- Fire a notification with the app closed, frontmost, and backgrounded.
- Confirm grouping, actions, and deep-link routing all land correctly.
- Confirm a resolved event removes its pending and delivered notices.
