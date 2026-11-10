# YcodeDecompiler — Architecture

## Module map

```
YcodeDecompiler (SwiftPM target / XcodeGen static lib; deps: YcodeAssistant, YcodeSubprocess)
│
├── Core/                     Canonical model — Sendable value types, no I/O
│   ├── BinaryFormat.swift    BinaryFormat, BinaryArchitecture, CPUTypeIdentifier,
│   │                         ArchitectureResolver (Mach-O/ELF/PE → arch)
│   ├── BinaryImage.swift     BinaryIdentity (stableID = sha256[0..16]-s<slice>),
│   │                         BinaryImage, segments/sections, imports/exports/
│   │                         dependencies, VA↔file-offset translation, byteProvider
│   ├── DecompilerAddress.swift  Typed address: virtual / fileOffset /
│   │                            sectionRelative / imageRelative
│   ├── Function.swift        DecompilerFunction, AnalysisProvenance, AnalysisSource
│   ├── Instruction.swift     Instruction, InstructionOperand, BasicBlock
│   ├── Symbols.swift         BinarySymbol, CrossReference, TypeInfo
│   ├── DecompilerSupport.swift  DecompilerError, AnalysisProgress,
│   │                            AnalysisConfiguration, DecompilerCapabilities
│   ├── AnalysisStore.swift   actor — single source of truth for one session
│   ├── DecompilerSession.swift      actor — binary + analysis state + tasks
│   ├── DecompilerSessionManager.swift  actor — owns all sessions
│   └── AnalysisCoordinator.swift   parse → analyze → persist pipeline driver
│
├── Binary/                   Format detection and loading
│   ├── BinaryDetector.swift  magic-byte detection (never trusts extensions), SHA-256
│   └── BinaryLoader.swift    detection → slice enumeration → BinaryImage
│                             (parsers: MachOParser, ELFBinaryParser, PEBinaryParser)
│
├── Formats/                  Concrete BinaryParser implementations
│   ├── Common/FormatSupport.swift  ByteCursor (bounds-checked, endian-aware,
│   │                               ULEB128, cstring), readFileRegion, fileSize
│   ├── MachO/MachOParser.swift     thin + fat/universal, all load commands,
│   │                               symtab/dysymtab, dyld info, export trie,
│   │                               function starts, encryption, code signature,
│   │                               build version, min-OS, UUID
│   ├── ELF/ELFBinaryParser.swift   ELF32/64 LE/BE, phdrs+shdrs (extended
│   │                               numbering), .symtab/.dynsym, .dynamic
│   │                               DT_NEEDED, NT_GNU_BUILD_ID, PT_INTERP
│   └── PE/PEBinaryParser.swift     MZ/PE32/PE32+, COFF+optional header,
│                                   data directories (import/export/security/
│                                   debug→PDB), per-section segments
│
├── Analysis/                 Analysis passes (pure functions)
│   ├── FunctionDiscovery/   metadata-driven discovery + call-target refine
│   ├── StringAnalysis/      ASCII/UTF-16LE extraction → virtual addresses
│   ├── CrossReferences/     call/jump/data/string xrefs from instructions
│   ├── TypeRecovery/        format-declared types only (empty without debug info)
│   ├── ControlFlow/         ControlFlowAnalyzer (basic blocks),
│   │                        CallGraphAnalyzer (callers/callees/edges)
│   ├── DataFlow/            DataFlowAnalyzer — seam only; backend p-code/SSA
│   ├── DebugInformation/    DWARF/PDB *presence* reporting (no parsing)
│   ├── DependencyAnalysis/  linked libraries, imports by library
│   ├── ImportAnalysis/      ImportExportAnalysis helpers
│   ├── ExportAnalysis/      export listing helpers
│   └── SymbolAnalysis/      symbol search/grouping helpers
│
├── IntermediateRepresentation/  Canonical IR: IRModule, IRFunction,
│   │                            IRInstruction, IRBasicBlock + converter
│   │                            from decoded Instructions + functions
│
├── Engines/                  Provider contracts + registry
│   ├── EngineProtocols.swift BinaryParser, DisassemblerProvider,
│   │                         DecompilerProvider, AnalyzerProvider, SliceDescriptor
│   ├── EngineRegistry.swift  DecompilerCapabilitiesSet, EngineDescriptor,
│   │                         DecompilationRequest/Result
│   ├── EngineRegistry+Resolution.swift  actor registry, provider resolution,
│   │                                    descriptor cache, installDefaults hook
│   └── EngineBootstrap.swift  installDefaults(): registers ObjDumpDisassembler
│                              + GhidraDecompiler into EngineRegistry.shared
│
├── Disassembly/              llvm-objdump backend
│   ├── DisassemblerProvider.swift  DisassemblerBackends facade
│   └── Backends/ObjDumpDisassembler.swift  per-section raw-binary disassembly
│
├── Decompilation/            Ghidra headless backend
│   ├── DecompilerRegistry.swift    facade over EngineRegistry
│   └── Backends/GhidraDecompiler.swift  analyzeHeadless import/process flow
│
├── Storage/                  `.scdecomp` persistence
│   ├── ProjectManifest.swift       Project.json schema + DecompilerProject
│   ├── DecompilerProjectManager.swift  create/open/save/validate (actor)
│   ├── AnalysisPersistence.swift   Analysis.sqlite (CSQLite) / Analysis.json
│   ├── CacheManager.swift          actor — content-addressed result cache
│   └── DecompilerDatabase.swift    SQLite schema + migration list (doc)
│
├── Security/                 BinarySecurityPolicy, AnalysisSandbox,
│   │                         ResourceLimits, InputValidation,
│   │                         PermissionPolicy, TemporaryFilePolicy
│
├── Configuration/            UserDefaults-backed prefs:
│                             DecompilerConfiguration, EngineConfiguration,
│                             AnalysisPreferences, WorkspacePreferences
│
├── Symbols/                  SymbolDemangler (swift-demangle / c++filt / _ strip)
│
├── Export/                   Report/assembly/graph/project/pseudocode/symbol exporters
│
├── Interface/                SwiftUI/AppKit workspace
│   ├── Shared/               DecompilerObservableState (@MainActor @Observable
│   │                         facade over DecompilerSession), SharedComponents
│   ├── Friendly/             section-based guided UI + detail views
│   └── Master/               dense panes: browsers, editors (disassembly,
│                             pseudocode, hex, control flow)
│
├── App/                      DecompilerWindowManager (one window per session),
│                             DecompilerWindowController (toolbar), DecompilerCommands
│                             (16 commands), DecompilerLifecycle (startup hooks)
│
├── AI/DecompileAssist/       Prompt assets loader, config, provider policy,
│   │                         context builder, session (SDK multiplexing),
│   │                         tool registry + tools (BinaryInspection, Function,
│   │                         String, Symbol, Analysis, Annotation, Assistant)
│   └── (driven by GoogleCloudSDKRuntime via YcodeAssistant)
│
└── Resources/                SystemAssets/DecompileAssist/*.md (17 prompt docs),
                              EngineScripts/DecompileDump.py (Ghidra Jython bridge)
```

## Data flow

```
file on disk
   │  BinaryDetector.detect(url:)                 magic bytes only
   ▼
BinaryLoader.loadContainer → parser.detectSlices  [SliceDescriptor]
   │  session.importBinary(sliceIndex:)
   ▼
parser.parse → BinaryImage (canonical, backend-independent)
   │  store.setBinary(image)
   ▼
AnalysisCoordinator.runFullAnalysis
   1. upsertSymbols(image.symbols)
   2. FunctionDiscovery.discover(image:)        entry/functionStarts/symbols/exports
   3. StringAnalysis.extract(image:)            non-executable sections
   4. registry.resolveDisassembler → disassemble each executable section
      (ObjDumpDisassembler: llvm-objdump -D -b binary per section)
   5. CrossReferenceBuilder.build(instructions, image)
   6. FunctionDiscovery.refine(instructions)    call-target harvest + size fill
   7. TypeRecovery.recover(image)               (empty without debug info)
   8. AnalysisPersistence.save → .scdecomp / Analysis.sqlite|json
   ▼
AnalysisStore (actor) ──read by──▶ DecompilerObservableState (@MainActor)
        │                                    │
        │                                    ├── Friendly/Master SwiftUI views
        │                                    └── DecompileAssistSession tools
        └── per-function ops: session.disassembleFunction / decompileFunction
             (resolve provider on demand; decompile → GhidraDecompiler →
              analyzeHeadless + DecompileDump.py → DecompilationResult)
```

## Actor boundaries

| Actor / isolation | Owns |
|---|---|
| `AnalysisStore` (actor) | All analysis results for one session: image, functions, symbols, strings, xrefs, types, instructions map, pseudocode map, comments, labels, findings, history, pins |
| `DecompilerSession` (actor) | Mode, selected slice, source URL, attached project, nav history, bookmarks, analysis `Task`, import/analyze/disassemble/decompile entry points |
| `DecompilerSessionManager` (actor) | `[UUID: DecompilerSession]`, active id, `openProject`/`newProject` |
| `EngineRegistry` (actor) | Registered providers, descriptor cache |
| `DecompilerProjectManager` (actor) | `.scdecomp` create/open/save/validate |
| `CacheManager` (actor) | Content-addressed on-disk result cache (not yet instantiated by sessions) |
| `DecompilerObservableState` (@MainActor @Observable) | UI-facing snapshot facade; views never touch actors directly |
| `DecompileAssistSession` (@MainActor @Observable) | Conversation, tool events, Antigravity SDK session multiplexing |
| `DecompileAssistConfiguration` (@MainActor @Observable) | Assist prefs in UserDefaults |

Provider protocols are `Sendable` + `async`; backends may shell out via
`YcodeSubprocess` without blocking actors.

## Provider model

- `BinaryParser` — `format`, `matches(header:)`, `detectSlices(url:)`,
  `parse(url:sliceIndex:identity:byteProvider:)`. `BinaryLoader.parsers`
  is the static priority list (Mach-O, ELF, PE).
- `DisassemblerProvider` — `disassemble(image:start:end:progress:)` →
  `[Instruction]`; resolved by `EngineRegistry.resolveDisassembler`.
- `DecompilerProvider` — `decompile(DecompilationRequest)` /
  `decompileBatch` → `DecompilationResult`; `isPrimary` marks the
  recommended backend (Ghidra sets `isPrimary = true`).
- `AnalyzerProvider` — capability advertisement for lightweight backends.

Capabilities are per-image via `DecompilerCapabilitiesSet`
(`decompileFunction`, `decompileBatch`, `functionDiscovery`,
`typeRecovery`, `crossReferences`, `controlFlowGraph`, `callGraph`,
`pcode`); providers report fewer capabilities rather than fail at runtime.

## Provenance discipline

Every artifact carries `AnalysisSource`/`AnalysisProvenance`
(`formatParser`, `symbolTable`, `engine`, `heuristic`, `user`,
`aiSuggestion`). AI findings start `userConfirmed = false`; renames keep
`originalName`/`userName` separate (reversible); `DecompileAssistToolRegistry`
enforces per-tool `requiresApproval` on mutating tools.

## Evidence

| Claim | Level |
|---|---|
| Module map, data flow, actor boundaries, provider protocols | 1 — source inspection |
| Unwired extended passes/exporters/cache/config | 1 — grep-verified absence of call sites |
