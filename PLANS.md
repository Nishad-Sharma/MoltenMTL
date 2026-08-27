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

What the manifest currently shows:

- **No struct is generated.** All 42 Metal record entries are unbound. Every
  struct the bindings expose is hand-written in `src/metal.zig` — 23 of them,
  which the manifest detects as `manual` typedefs. Only 6 carry a `@sizeOf`
  assertion, and none assert alignment or field offsets.
- **All 30 `rejected` entries are a single bug.** Every one is a boolean
  property with a `getter=isFoo` attribute: `rasterizationEnabled`, `headless`,
  `lowPower`, `framebufferOnly`, `blendingEnabled`, `active`, `used`. The getter
  is generated correctly — `isRasterizationEnabled` is in the output. Only the
  property-to-accessor match fails, because property status is resolved by
  looking up a *method of the same name*.
- **The real gaps hide in `excluded`.**
  `MTLAccelerationStructureInstanceDescriptor`, `MTLPackedFloat3`,
  `MTLPackedFloat4x3`, `MTLComponentTransform`, and the three indirect-draw
  argument structs are filed as "valid SDK typedef outside the selected binding
  surface" — indistinguishable from genuinely irrelevant API, because
  reachability is never computed. Instance acceleration structures and indirect
  draws are RHI blockers, not out-of-scope API.

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

### 5. Reachability and the selected surface — P0, M

Moved ahead of record generation: it gives record generation a defined scope and
an acceptance criterion, and it is the cheaper of the two.

- Compute the transitive Objective-C type closure of the explicit selection
  list, so selecting a declaration also selects every type reachable from its
  public signature — records, typedefs, enums, protocols, blocks, superclasses,
  and Foundation/CoreGraphics types. The existing `registry.Type` already
  carries pointer, generic and function shapes to walk.
- Record provenance per declaration as `explicit`, `transitive_dependency`, or
  `sdk_only`.
- Fail generation on any declaration reachable from the explicit list that is
  neither generated nor audited. This is the point of the phase: `excluded` must
  become trustworthy as "genuinely not needed".
- Acceptance: the RHI-critical types currently sitting in `excluded` are
  reclassified as reachable, and the generator says so loudly.

### 6. Records and generated layout verification — P0, L

- Generate C records and their typedefs from the Clang AST instead of
  hand-writing them. Retain a manual Zig record only when it is allowlisted and
  layout-verified.
- For every generated or manual record, emit generated `comptime` assertions for
  size, alignment and every field offset, with values obtained from Clang rather
  than restated by hand. A record whose layout Clang cannot supply is a
  generation error. Replace the six hand-written `@sizeOf` asserts in
  `src/metal.zig` with generated ones.
- Resolve a named typedef of an anonymous struct to one Zig declaration, so
  `MTLOrigin` and its underlying anonymous record stop being two manifest
  entries.
- Generate exported C functions and constants, or record an audited reason for
  each that is not generated.
- Scope is whatever Phase 5 proves reachable — not all 42 record entries.
- Acceptance: zero bound structs whose layout is asserted by hand.

### 7. ABI type fidelity and nullability — P0, M

- Preserve signedness, integer width, pointer constness, enum underlying types,
  block calling conventions, and output-pointer shapes such as `NSError **`.
  This half is pure correctness and is not negotiable.
- Nullability follows one rule: **optional unless provably `_Nonnull`.** Map
  `_Nullable`, `_Nullable_result`, `_Null_unspecified` and unannotated pointers
  all to `?*T`. This is sound by default and avoids chasing attribute flavours
  that Zig cannot distinguish anyway.
- `new`, `alloc` and `allocInit` return optional pointers.
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
- **Pin the minimum macOS version explicitly** in `mach-objc/build.zig` via
  `os_version_min`. Nothing currently sets it — `objc.zig` enforces only
  `aarch64-macos`, and the old 26.0 check lived in the root build that was
  deleted. The removal of availability handling rests on floor-equals-SDK, so
  that assumption should be enforced by the build rather than assumed in a
  document.

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
