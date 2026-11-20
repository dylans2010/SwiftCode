# Entitlements and Code-Signing Analysis

<!-- system-index-depends: Safeguards.md, CodeSigningAndNotarization.md -->

Entitlements declare what a binary is allowed to do; the code signature
says who vouches for it. Assist reads both to answer trust questions about
a binary. This asset is about analyzing a binary's claims, not about
signing Assist's own apps; that is `CodeSigningAndNotarization.md`.

## When to retrieve

- The user asks what a binary is allowed to do or who signed it.
- An app is denied an entitlement-gated capability and the cause is
  unclear.
- A binary's signature looks wrong, missing, or mismatched.

## What Assist reads

- The signature blob: presence, type, and which parts of the file it
  covers. Presence is not validity.
- The signing identity: team identifier, certificate subject, and whether
  the identity is a developer, distribution, or ad-hoc signature. Ad-hoc
  signatures assert integrity, not identity.
- Entitlements: the capability list the binary declares, such as sandbox
  access, keychain groups, network entitlements, or hardware access. Each
  entitlement is a claim about what the binary may request.
- The designated requirement: the rule the system uses to decide whether
  a binary is acceptable. A binary can be signed and still fail its
  requirement.
- Provisioning or profile data where present: which devices or capabilities
  a build was provisioned for.

## How to report findings

- List entitlements in plain language with what each one permits. Do not
  dump raw plist text as the answer.
- Separate what the binary declares from what the system grants. An
  entitlement is a request; the system, the profile, and the user's
  consent decide the grant.
- Flag over-broad entitlements as observations, not accusations. A
  capability may be legitimate for the app's purpose.
- Report signature problems precisely: missing, expired, mismatched team,
  or requirement failure are four different findings.

## Common misreadings

- Treating a valid signature as proof the binary is safe. Signing proves
  origin and integrity, not good behavior.
- Treating an ad-hoc signature as no signature. It still binds the binary
  to its contents.
- Assuming an entitlement means the capability is used. It means it may
  be requested.
- Confusing the app's entitlements with the user's permissions. The user
  can still deny a runtime prompt.

## Cross-references

- Signing your own apps: `CodeSigningAndNotarization.md`
- Sandbox rules: `AppSandboxSecurity.md`
- Load commands: `MachOLoadCommands.md`

## Limits

- Assist describes declared entitlements and signature state. It does not
  perform a cryptographic verification itself, and it never tells a user
  to bypass a signature check.
- Entitlement contents can include team and group identifiers; treat them
  as identifiers, not as secrets, and do not repeat them needlessly.
