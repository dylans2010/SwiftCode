# Sharing and Share Sheet

<!-- system-index-depends: DragAndDropMacOS.md -->

Sharing is how content leaves the app: AirDrop, Mail, Messages, Files,
or a third-party service. On macOS the share sheet is `NSSharingServicePicker`;
the app's job is to hand it the right items, in the right form, with a
sensible fallback.

## Offering share

- Put Share in the File menu, in the toolbar, and in the contextual menu
  for the item. One location is easy to miss.
- Share the item the user is looking at, not the whole document, unless
  they asked for the whole document.
- Disable Share when there is nothing to share, and say why in the menu
  item's tooltip rather than leaving a dead button.

## What to hand the picker

- Hand over the richest representation first: the file, then a rich text
  or image, then plain text. Services pick the best representation they
  support.
- For files, share a real file URL to a real file on disk. Do not share a
  temporary path that disappears before the service reads it.
- Give the item a good filename. The filename is what the recipient sees;
  `Untitled-3.txt` is a failure of naming, not of sharing.
- Provide a subject or title where the service supports it, so a shared
  email arrives with a subject line.
- Keep the shared content minimal: share the selected range or the chosen
  page, not the entire workspace, unless the user asked for it.

## NSSharingServicePicker details

- Present the picker anchored to the control that invoked it (a toolbar
  button or a menu item's view). An unanchored picker appears in a random
  place.
- Use `NSSharingServicePickerDelegate` to filter the services list: hide
  services that make no sense for the content (for example, hide image-only
  services when sharing plain text).
- Handle the picker delegate's `sharingService(_:didFailToShareItems:...)`
  and tell the user what failed in plain language.
- On macOS, the picker is a menu, not a sheet. Do not expect the iOS
  `UIActivityViewController` presentation model.

## Privacy and safety

- Sharing is an export. Before sharing, confirm the content contains no
  credentials, tokens, or private data the user did not intend to send.
- Never auto-share. Every share is a user action with a visible picker.
- If the content is large, warn before sharing over AirDrop or Mail so
  the user is not surprised by a long transfer.

## Verification

- Share to Mail, Messages, AirDrop, and Files and confirm each receives
  the right content and filename.
- Share with no network and confirm the failure is reported, not silent.
- Confirm the picker is anchored correctly at different window sizes.
- Confirm sharing a selection shares only the selection.
