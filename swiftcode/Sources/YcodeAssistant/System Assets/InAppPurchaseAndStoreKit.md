# In-App Purchase and StoreKit

<!-- system-index-depends: Authentication.md, Safeguards.md -->

In-app purchase is money, identity, and trust in one flow. This asset
covers how Assist designs StoreKit integration that charges correctly,
restores reliably, and fails gracefully.

## When to retrieve

- The user is adding purchases, subscriptions, or consumables.
- A purchase fails, does not restore, or charges twice.
- A subscription's status, renewal, or cancellation needs explaining.

## Design rules

- Verify purchases with the App Store, not with client-side state alone.
  Client state can be forged; a validated receipt or transaction cannot.
- Never grant a purchase before verification completes. Granting early
  is a free-purchase bug.
- Handle restores as a first-class flow. A user who paid on another
  device must get what they paid for.
- Subscriptions are a state, not an event: active, expired, in grace,
  revoked, or refunded. The app must handle every state, not just active.
- Prices, products, and availability come from the store. Never hard-code
  a price or a product identifier's meaning.

## Failure handling

- A failed purchase leaves the user uncharged and informed, with a clear
  next step.
- A network failure during verification is a retry, not a grant and not
  a denial. Say so and retry.
- A purchase that cannot be verified is not granted, and the user is told
  why in plain language.
- Log the transaction identifier and the failure reason, never the
  payment details.

## Testing rules

- Test in the sandbox with a sandbox account, never with a real account
  and a real card.
- Test the restore flow, the interrupted purchase flow, and the
  subscription expiry flow, not just the happy path.
- Test what happens when the store is unreachable at each step.
- Verify that a refund revokes access where the product requires it.

## Common mistakes

- Granting access before the transaction is verified.
- Treating a subscription as active because the user once bought it.
- Forgetting the restore flow until a user complains.
- Storing purchase state only on the device, so a reinstall loses it.

## Cross-references

- Authentication: `Authentication.md`
- App Store submission: `AppStoreSubmissionChecklist.md`
- Privacy manifests: `PrivacyManifests.md`

## Limits

- Assist designs the flow and the verification discipline. It does not
  process payments, handle real transactions, or access the user's store
  account.
