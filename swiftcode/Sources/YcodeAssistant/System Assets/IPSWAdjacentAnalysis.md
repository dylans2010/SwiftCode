# IPSW-Adjacent Analysis as Far as Assist Is Concerned

<!-- system-index-depends: ReverseEngineeringTriage.md, Safeguards.md -->

An IPSW is a firmware bundle: a signed archive of the components that make
up an iOS or iPadOS install. Assist's role here is narrow and file-level:
identify, inventory, and explain what is in the bundle, and stop well
short of booting, modifying, or re-signing it.

## When to retrieve

- The user asks what an IPSW file contains or how to inspect one.
- A firmware question touches SwiftCode's simulator or device work.
- Triage needs to know whether a file is firmware-related at all.

## What Assist may do

- Identify the file as an IPSW (a zip archive with a known manifest and
  payload layout) and name the device and build it targets from the
  manifest.
- Inventory the bundle's entries at the file level: manifest, restore
  ramdisks, kernel caches, and firmware components, by name and size.
- Explain what each component is for, in general terms, and which ones
  are signed.
- Read the manifest's declared metadata: build version, device class,
  and component list.
- Hand deeper questions to the right place: device and runtime work
  belongs with the device tooling, not with ad-hoc firmware surgery.

## What Assist must not do

- Boot, mount, or execute firmware components.
- Modify, repack, or re-sign an IPSW or any component inside it.
- Help bypass signature verification, activation, or restore checks.
- Extract or redistribute Apple firmware components.
- Treat an IPSW as a source of runnable code for SwiftCode's own
  simulator. The simulator uses its own runtimes.

## How to report IPSW findings

- Lead with device, build, and manifest validity. Everything else is
  inventory.
- Distinguish the manifest's claims from verified contents. A manifest
  can list a component the archive does not actually contain.
- Flag signature state as declared, not verified, unless a verification
  was actually performed by appropriate tooling.
- Keep the answer at the inventory level. Component internals are a
  separate analysis with their own scope rules.

## Common mistakes

- Treating the IPSW as a disk image to mount and run. It is a signed
  restore bundle.
- Assuming every component in the manifest is present and intact.
- Confusing the restore ramdisk with the installed system.
- Offering firmware modification as a troubleshooting step.

## Cross-references

- Triage: `ReverseEngineeringTriage.md`
- Ethics and scope: `ReverseEngineeringEthicsAndScope.md`
- Evidence handling: `EvidenceHandlingAndChainOfCustody.md`

## Limits

- Assist's IPSW work is identification and inventory only. Any deeper
  firmware analysis is out of scope and must be declined or redirected.
