# Mach-O Reference

Mach-O is the executable format for macOS, iOS, and other Apple platforms.
Understanding its layout helps you interpret sections, symbols, and metadata.

## Structure

- **Header** (`mach_header` / `mach_header_64`): magic, CPU type/subtype,
  file type (`MH_EXECUTE`, `MH_DYLIB`, `MH_BUNDLE`, `MH_OBJECT`), load-command
  count and size.
- **Load commands**: everything the kernel/loader needs — segments, sections,
  symbols, code signature, encryption info, entry point (`LC_MAIN`), dylib
  dependencies (`LC_LOAD_DYLIB` family), build version, UUID
  (`LC_UUID`), function starts (`LC_FUNCTION_STARTS`).
- **Universal/fat binaries**: `FAT_MAGIC`/`FAT_MAGIC_64` container holding
  multiple slices; `list_binary_architectures` enumerates them and
  `inspect_binary_slice` describes one. Analysis operates on one slice.

## Segments and sections

- `__TEXT`: code and read-only data. `__text` is the main code section.
- `__DATA`: writable globals, `__data`, `__bss`, `__common`.
- `__DATA_CONST`: relocated constants (pointers, vtables).
- `__LINKEDIT`: symbol table, string table, code signature, function starts.
- Sections carry flags for executability/writability — `isExecutable` and
  `isWritable` on `BinarySectionInfo` come from these.

## Symbols and imports

- `LC_SYMTAB` → symbol table (`nlist`/`nlist_64` entries) in `__LINKEDIT`.
- Dynamic symbols and stubs (`__stubs`, `__la_symbol_ptr`, `__got`) implement
  imports; `image.imports` maps them to library names.
- Swift symbols appear mangled (`$s…`); use `demangle_symbol`.
- Stripped binaries keep only dynamic symbols — many functions appear as
  `sub_<addr>` discovered heuristically.

## Security metadata

- `LC_CODE_SIGNATURE`: CMS blob; entitlements live inside it as a DER-encoded
  plist. `inspect_code_signature` / `inspect_entitlements` expose what the
  parser recovered.
- `LC_ENCRYPTION_INFO(_64)`: FairPlay DRM; `isEncrypted` is set when cryptid
  is nonzero — decryption may be partial.
- Hardened runtime, library validation, and entitlements matter for
  interpreting capabilities (e.g., `com.apple.security.*`).

## ARM64e / pointer authentication

Apple Silicon uses pointer authentication (PAC): return addresses and some
pointers carry signature bits in high bits. Disassemblers may show `pacibsp`,
`autibsp`, `braa`, `blraa` — these are auth instructions, not ordinary
branches. `ret` variants (`retab`) authenticate before returning.
