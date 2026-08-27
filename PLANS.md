# Metal Objective-C Zig Bindings Robustness Plan

## Summary

This is a lightweight, internal code generator. Its only consumer is the RHI in
this repository. It is not a public-facing Zig bindings package, and it carries
no source-compatibility promise to anyone outside this repo. That constraint is
load-bearing: several features that a published bindings library would need are
deliberately out of scope, and are listed at the end of this document.

The goal is a raw Objective-C binding layer for Metal, MetalFX, and the narrow
QuartzCore and AppKit surface needed to host and present a Metal layer, correct
enough to build an RHI on:

- `aarch64-macos` only. Deployment floor equals the SDK generated from.
- Raw Zig object pointers following Cocoa ownership conventions.
- No C++ in the public or generated API, no `MTL::` types, no ownership
  wrapper types, no `zig-objc` dependency, no metal-cpp dependency.
- Xcode's Objective-C declarations are the sole authority for signatures, ABI,
  enum values, record layouts, nullability, and block signatures.

Priority: P0 is a correctness blocker, P1 is required for a usable RHI surface,
P2 is housekeeping. Effort: S <1 day, M 1-3 days, L 4-8 days.

Current state: Phases 1-3 are implemented and committed.

## The selected surface

The selected surface is defined by the generator itself, not by an external
inventory:

- An **explicit selection list** — the `addEnum`, `addInterface`, `addProtocol`
  and `add*WithPrefix` calls in `generateMetal`, `generateMetalFX`,
  `generateQuartzCore` and `generateAppKit`. APIs are added here as the RHI
  needs them.
- The **transitive Objective-C closure** of that list: every type reachable from
  a selected declaration's public signature.
- Everything else in the SDK is **excluded**, with a deterministic reason.

Selection decides only *what* is bound. Every semantic property comes from the
Objective-C Clang AST regardless of how a declaration was selected.

## Phase order

Correctness work lands before surface work, and the two cheap manifest-only
changes land before the one that churns generated output.

The governing principle is that **verification must be generated, not
hand-written**. If every record carries generated `comptime` size, alignment and
field-offset assertions derived from Clang, then layout fidelity is a property
of the generator rather than of a human transcribing constants, and the size of
the bound surface stops being a risk to manage.

What the manifest showed when this plan was written, and where each item stands:

- **No struct is generated.** All 42 Metal record entries are unbound. Every
  struct the bindings expose is hand-written in `src/metal.zig` — 23 of them,
  which the manifest detects as `manual` typedefs. Only 6 carry a `@sizeOf`
  assertion, and none assert alignment or field offsets.
- **All 46 `rejected` entries were a single bug** — resolved in Phase 4. Every
  one was a boolean property whose getter had been generated correctly all
  along; property status was resolved by looking up a *method of the same name*,
  which can never match `isHeadless`. Metal 30, MetalFX 12 and QuartzCore 4 now
  all report zero rejected, with generated Zig byte-identical.
- **The real gaps hide in `excluded`.**
  `MTLAccelerationStructureInstanceDescriptor`, `MTLPackedFloat3`,
  `MTLPackedFloat4x3`, `MTLComponentTransform`, and the three indirect-draw
  argument structs are filed as "valid SDK typedef outside the selected binding
  surface" — indistinguishable from genuinely irrelevant API, because
  reachability is never computed. Instance acceleration structures and indirect
  draws are RHI blockers, not out-of-scope API.

Phase 5 turned up a caveat on that last point: computing reachability is what
makes `excluded` trustworthy, but it does not find these particular types,
because none of them appears in a signature — they reach Metal inside buffer
contents. Phase 5 makes the rest of `excluded` safe to ignore; Phase 6 has to
name these explicitly.

Phases 4 and 5 change no generated Zig at all; their diffs are confined to
`.manifest.json`. Phase 6 is the first that rewrites `metal.zig`. Keeping that
order means the big diff lands against an otherwise verified baseline.

## Implementation Changes

### 1. ARM64 runtime and messaging — P0, M — **done**

- Compile-time error for non-ARM64 targets; no x86, `objc_msgSend_stret` or
  `objc_msgSend_fpret` paths.
- Correctly typed ordinary `objc_msgSend` for every call.
- Atomic per-call-site selector cache.
- Instance, class and superclass dispatch verified through an Objective-C ABI
  fixture; Zig `bool` validated against ARM64 `BOOL`.

### 2. Runtime class and availability primitives — P0/P1, M — **done**

- Classes resolved through the Objective-C runtime, not strong Mach-O refs.
- `classIfAvailable() ?*objc.Class` on every generated class; `class()` as a
  checked convenience.
- Generic `respondsTo` for selector capability checks.
- Raw `retain`/`release`/`autorelease` plus a scoped autorelease-pool value.

### 3. Fail-closed AST conversion — P0, L — **done**

- Clang-evaluated enum values or a generation error; no fallback to zero.
- Every declaration classified `generated`, `manual`, `excluded` or `rejected`.
- Unsupported arrays, vectors, pointer combinations and expressions rejected
  rather than guessed.
- Declaration manifest with name, kind, header, status and reason.
- Transactional output generation.

### 4. Property accessor resolution — P0, S — **done**

Split out from record work because it is small, isolated, and clears the entire
current `rejected` list on its own.

- Resolve a property against its real getter: honour Clang's `getter=` attribute
  and the `isFoo` convention rather than requiring a method whose name equals
  the property's.
- Apply the same rule to setters.
- Acceptance: the `rejected` count reaches zero, and the only `verify.sh` diff
  is in `.manifest.json`. All 46 rejected declarations across Metal (30),
  MetalFX (12) and QuartzCore (4) are properties, and every one resolves to a
  declared accessor under the implemented matcher.

### 5. Reachability and the selected surface — P0, M — **done**

Moved ahead of record generation: it gives record generation a defined scope and
an acceptance criterion, and it is the cheaper of the two.

- Compute the transitive Objective-C type closure of the explicit selection
  list, so selecting a declaration also selects every type reachable from its
  public signature — superclasses, adopted protocols, parameter and return
  types, property types, and whatever those resolve to through typedefs.
- Stop the walk at names this framework's inventory does not own. Foundation
  types are bound by hand in `src/foundation.zig`, and walking through them
  would manufacture reachability that says nothing about this framework.
- Treat reachability as satisfied by name, not by kind. Metal declares
  `@class MTL4BinaryFunction` beside a protocol of the same name and binds only
  the protocol; the unused sibling is not a gap.
- Follow the bindings, not the SDK. Walk only members the manifest records as
  generated: a container declares far more than the generator emits, and
  following an excluded method drags its parameter types in as dependencies of
  a binding that does not exist. Do not follow adopted protocols at all — every
  generated `ExternClass` and `ExternProtocol` carries an empty protocol list.
- Skip names and transitively reached containers owned by another framework's
  namespace. QuartzCore headers forward-declare `@protocol MTLDevice` though it
  is emitted into `metal.zig`, and `NSObject` — superclass of everything — is
  hand-written as `ObjectInterface`, invisible to name-based manual detection.
- Record provenance per declaration as `explicit`, `transitive_dependency`, or
  `sdk_only`.
- Classify a reachable declaration that is neither generated nor manually bound
  as `rejected` rather than `excluded`, so `excluded` becomes trustworthy as
  "genuinely not needed" and the rejected list stays the work queue.

**Correction to this phase's original acceptance criterion.** It was written
expecting the closure to reclassify the RHI-critical types sitting in
`excluded`. It will not, and the reason matters: reachability is a property of
the *type graph*, and those types appear in no signature.
`MTLAccelerationStructureInstanceDescriptor` and the indirect-draw argument
structs are filled in by the caller and copied into a buffer — no Metal method
takes one, and searching the generated and manual Metal sources finds no
reference to any of them.

The closure is therefore necessary but not sufficient. It is the standing guard
that catches a dependency forgotten when adding an API, and it proves the rest
of `excluded` unreachable. Structs that cross the API boundary inside a buffer
must still be named in the selection list by hand.

- Acceptance met. Once the walk followed bindings instead of declarations,
  QuartzCore went from 123 rejected to 0 and MetalFX to 0, leaving Metal with 13
  block typedefs — precisely what was missing, and the first slice of Phase 6.
  Reported split: Metal 705 explicit + 40 transitive, MetalFX 28 + 0,
  QuartzCore 5 + 0.

### 6. Records and generated layout verification — P0, L — **in progress**

- **Record generation was dropped.** `convertRecordDecl` is a stub, so this
  meant building field extraction and anonymous-record-to-typedef joining from
  scratch — and it would not have replaced the hand-written records anyway. They
  carry 14 `init`-style helpers used throughout the example and the raytrace
  test, which a generated bare struct cannot provide. With every hand-written
  record now asserted against Clang, a hand-written record is *provably* correct,
  which was the actual goal; generation would only have added a second way to
  produce declarations that still needed hand-written helpers on top.
- **Done:** emit generated `comptime` assertions for
  size, alignment and every field offset, with values obtained from Clang rather
  than restated by hand. The generator writes a probe translation unit that
  references each record through its typedef, runs
  `clang -Xclang -fdump-record-layouts`, and parses the result. The lazy dump is
  used rather than `-fdump-record-layouts-complete` because it names each record
  by the typedef the probe referenced, where the complete dump prints
  `struct (unnamed at file:line:col)` for the anonymous structs most Metal types
  are declared as. Bitfield layouts are rejected rather than guessed.
  The six hand-written `@sizeOf` asserts in `src/metal.zig` are gone, superseded
  by generated assertions that also cover alignment and every field offset.
- Resolve a named typedef of an anonymous struct to one Zig declaration, so
  `MTLOrigin` and its underlying anonymous record stop being two manifest
  entries.
- Generate exported C functions and constants, or record an audited reason for
  each that is not generated.
- Scope is whatever Phase 5 proves reachable, plus the buffer-only structs named
  below — not all 42 record entries.
- Add the buffer-only structs to the explicit selection list. They cross the API
  boundary inside `MTLBuffer` contents rather than in a signature, so Phase 5's
  closure cannot discover them: at minimum
  `MTLAccelerationStructureInstanceDescriptor` with its motion and user-ID
  variants, `MTLPackedFloat3`, `MTLPackedFloat4x3`, `MTLComponentTransform`,
  `MTLAxisAlignedBoundingBox`, and the `MTLDraw*IndirectArguments` and
  `MTLDispatchThreadsIndirectArguments` family.
- **Done:** emit block typedefs. Objective-C names its completion handlers, but
  the generator expanded them inline at each use, leaving the typedef with no
  Zig declaration — usable API, nothing a caller could spell, and the 13 unbound
  declarations Phase 5 reported. Every block typedef an emitted method uses now
  gets a `pub const` alias. Only typedefs collected during generation are
  aliased, so an alias can never name a type that was not bound.
- Acceptance: zero bound structs whose layout is asserted by hand.

### 7. ABI type fidelity and nullability — P0, M — **done**

- **Audited, already correct:** signedness, integer width, pointer constness,
  enum underlying types, block calling conventions, and output-pointer shapes.
  Enum underlying types come from Clang and vary as they should (`u64`, `u32`,
  `u8`, `c_int`); `NSError **` emits as `?*?*ns.Error` at 66 sites; 100 const
  pointers are preserved; integer widths keep their C spelling (`c_int`,
  `c_long`, `c_longlong`) rather than being normalised to fixed widths.
  One deliberate deviation, now documented at the mapping: plain `char` is
  signed on Apple ARM64 but is mapped to `u8`, because it only appears in C
  strings where `u8` is what Zig expects. Layout-identical, so it changes
  arithmetic semantics and never the ABI.
- **Done:** nullability follows one rule, **optional unless provably
  `_Nonnull`**. Measured over emitted pointers before the change: Metal 1014
  `_Nonnull`, 1206 `_Nullable`, 7 `_Nullable_result`, 0 `_Null_unspecified`, 206
  unannotated — so it moved about 8% of emitted pointers. `_Nullable_result` was
  a real bug, meaning null on the failure path. Measure over *emitted* pointers,
  not parsed ones: the converter walks every declaration in the translation unit,
  and a parse-time count is dominated by the system headers each framework drags
  in.
- **Done:** `new`, `alloc` and `allocInit` return optional pointers. The runtime
  returns a nullable id from all three, and the previous `@ptrCast` to `*T`
  discarded the only signal it gives.
- Treat nested pointers as optional rather than resolving inner nullability
  precisely.

### 8. Completion-handler blocks — P1, M

The block machinery in `src/system.zig` is already largely built: `Block`,
`BlockLiteral`, trivial and copy/dispose descriptors, `_Block_copy` and
`_Block_release`. This phase defines the supported shape and tests it, rather
than building anything new.

Every block in the current selected surface has the same shape — escaping, void
return, one or two object arguments, called once, possibly on another thread:

```
void (^)(id result, NSError *error)
```

- Support exactly that shape: escaping, void return, object and error pointer
  arguments, arbitrary calling thread.
- **Reject any other block signature at generation time** with a specific
  reason. Not implementing return-value blocks, by-value struct arguments, or
  `noescape` variants removes a whole class of ABI risk rather than testing it.
- Test what is supported: copy and dispose callbacks, captured Objective-C
  retain/release balance, invocation from a non-creating thread, and nullable
  handler arguments.
- Keep block fixes in the in-tree runtime; do not add a second block library.

### 9. Ownership by method family — P1, S

Downgraded from full ownership-attribute parsing. Cocoa's naming rule covers
essentially all of Metal, and the RHI encapsulates ownership once at its own
boundary.

- Classify results from the method family in the selector: `alloc`, `new`,
  `copy` and `mutableCopy` return +1; everything else returns +0.
- Emit that as a doc comment and store it in the manifest.
- **Fail generation** if a declaration carries an explicit
  `ns_returns_retained` / `ns_returns_not_retained` attribute that contradicts
  its family. That turns the assumption into a checked one instead of a hope.
- Do not parse consumed arguments or consumed `self`. Do not add `Owned`,
  `Borrowed` or transfer-pointer types.

### 10. Unavailable initializers — P1, S

What remains of the old constructors-and-properties phase.

- Do not emit `new` or `allocInit` when the SDK marks the relevant initializer
  `NS_UNAVAILABLE`. There is already a TODO for this at the emission site, and
  it is a live footgun: calling `new` on such a class fails at runtime.
- Preserve designated-initializer information only where it prevents emitting an
  unavailable constructor.

### 11. Package notes — P2, S

- Record architecture, deployment floor, SDK version, ownership rule,
  autorelease-pool requirement and the regeneration workflow in `README.md`.
  Internal does not mean undocumented; this is for future-you.
- Declaration counts are reported during generation as of `ffb533d`.
- The macOS floor is checked in `mach-objc/build.zig` against the resolved
  target. It is deliberately *not* pinned into the default target query:
  setting `os_version_min` makes `Query.isNativeOs()` false, Zig then stops
  discovering the host SDK, and every module that links `objc` or a framework
  fails to find it. A true pin would have to pass the SDK's framework, include
  and library paths to every module by hand. Worth doing only if binaries ever
  need to run on an older macOS than the build host.

## Deliberately out of scope

Cut because this generator has one internal consumer, on one architecture, with
the deployment floor pinned to the build SDK. Each entry names what would bring
it back.

- **Availability parsing and weak linking.** If the deployment floor equals the
  SDK generated from, every symbol is present at runtime and there is no
  availability problem to solve. `classIfAvailable()` and `respondsTo` already
  provide a manual escape hatch.
  *Revisit if:* you ship a binary that must run on an older macOS than the SDK
  it was built against.

- **Ownership attribute parsing beyond method families**, consumed arguments,
  consumed `self`, and CoreFoundation Create/Copy rules.
  *Revisit if:* the contradiction check in Phase 9 fires, which is exactly the
  signal that a real API deviates from the naming convention.

- **Property memory-semantics metadata** (`strong` / `copy` / `weak` /
  `assign`). You call a getter and receive +0; the callee's storage decision is
  not your concern at this layer.
  *Revisit if:* you bind a `weak` property, where the returned object can be
  deallocated out from under you.

- **General block support** — return-value blocks, by-value struct arguments,
  `noescape` propagation. Nothing in the selected surface needs them, and
  Phase 8 rejects them loudly rather than silently mis-binding them.
  *Revisit if:* generation fails on a block signature you actually need.

- **Public API stability and source-compatibility guarantees.** Generated names
  may change when the SDK pin moves. There is one consumer, in-repo, that can be
  updated in the same commit.
  *Revisit if:* the bindings are ever published separately.

- **x86, non-macOS targets, and pre-26.0 deployment.**
  *Revisit if:* never, ideally.

- **`mitchellh/zig-objc`.** ARM64 dispatch, selector registration, class lookup,
  retain/release and autorelease pools are already in-tree and small. Its main
  benefit is cross-architecture message classification, which is irrelevant
  after dropping x86, and it would introduce a second `Object`/`Class`/`Sel`
  universe. Its block implementation may be consulted as reference; preserve MIT
  attribution if anything is ported.

## Dependency Assessment: metal-cpp

metal-cpp was evaluated as a generator-time API-scope inventory and rejected.
The evaluation was implemented in full and measured; it is preserved on
`wip/phase4-metal-cpp`. Findings:

- Against the existing explicit selection list, the complete scope machinery
  changed generated output by **+15 / -28 lines across 13,400 lines**. The
  explicit list already produces effectively the same surface, because metal-cpp
  wraps whole classes and so does the generator.
- The delta was net negative. It removed real Xcode 26.5 APIs that metal-cpp
  26.4 does not declare: `MTLIndirectComputeCommandEncoder`,
  `MTLIndirectRenderCommandEncoder`, `MTLCaptureScope.mtl4CommandQueue`,
  `MTLFunctionReflection.userAnnotation`, `MTLFXFrameInterpolator.uiTextureUsage`
  and `MTLFXTemporalScaler.reactiveMaskTextureFormat`.
- It raised the Metal `rejected` count from 30 to 47 and introduced 11
  `sdk_absent` entries — permanent skew to maintain.
- It pinned the binding surface to Apple's C++ release cadence.
- It could not improve correctness by construction: by design it was never a
  semantic authority, so every ABI, nullability, ownership, enum and layout
  property still came from the Objective-C Clang AST.
- It converted "the surface I chose" into "parity with 3,292 external scope
  entries" — an obligation to verify, not an asset.

For hand-picking new APIs, Apple's documentation and the metal-cpp repository
are readable directly. Neither belongs in the build.

## Test and Release Gate

- Maintain the ARM64 Objective-C fixture covering scalars, `BOOL`, pointers,
  nil, floats, structs of several sizes, class messages and superclass messages.
- Verify every record's size, alignment and field offsets against Clang, through
  generated assertions rather than hand-written ones.
- Test the supported block shape: copy/dispose callbacks, captured
  retain/release balance, cross-thread invocation, nullable arguments.
- Test selector initialization concurrently — the caches are atomic and that is
  a real race surface.
- Test ownership classification for the four method families, and that a
  contradicting explicit attribute fails generation.
- Test nullable returns, nested output pointers and unavailable constructors.
- Test Debug and ReleaseFast.
- Regenerate twice from the pinned SDK and require identical manifests and Zig
  output.
- Fail on unclassified declarations, missing exclusion reasons, unaudited manual
  declarations, reachable-but-unbound declarations, or checked-in generation
  diffs. `verify.sh` is the gate.

The release gate for the selected surface is: zero rejected declarations, every
manual declaration audited, generated sources fresh, and the ABI, block and
record tests passing. Excluded SDK declarations are expected and must retain
deterministic reasons.

## Assumptions

- Apple ARM64 macOS on M-series hardware is the only target.
- The deployment floor equals the SDK generated from. Xcode 26.5 is the current
  baseline; moving it requires a reviewed regenerated diff.
- One in-repo consumer. No third-party source-compatibility guarantee.
- Generated bindings remain a raw Objective-C layer with Cocoa ownership
  semantics, not a safe wrapper. Safety belongs in the RHI above them.
- Full RHI implementation and Vulkan work are outside this plan.
- Remaining effort is roughly 2-3 focused weeks, dominated by Phase 6.
