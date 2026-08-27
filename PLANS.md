# Metal Objective-C Zig Bindings Robustness Plan

## Summary

The goal is a raw Objective-C binding layer for Metal, MetalFX, and the narrow
QuartzCore and AppKit surface needed to host and present a Metal layer, robust
enough to build an RHI on:

- `aarch64-macos` only, deployment floor macOS 26.0, generated from Xcode 26.5.
- Raw Zig object pointers following Cocoa ownership conventions.
- No x86 support, no C++ in the public or generated API, no `MTL::` types, no
  shared-pointer terminology, no Rust-style owned returns.
- No `zig-objc` dependency, and no metal-cpp dependency.
- Xcode 26.5 Objective-C declarations are the sole authority for signatures,
  ABI, enum values, record layouts, nullability, ownership, properties,
  availability, weak linking, and block signatures.

Priority: P0 is a correctness blocker, P1 is required for a usable RHI surface,
and P2 is hardening. Effort: S <1 day, M 1-3 days, L 4-8 days, XL multiple weeks.

Current state: Phases 1-3 are implemented and committed.

## The selected surface

The selected surface is defined by the generator itself, not by an external
inventory:

- An **explicit selection list** — the `addEnum`, `addInterface`, `addProtocol`
  and `add*WithPrefix` calls in `generateMetal`, `generateMetalFX`,
  `generateQuartzCore` and `generateAppKit`. APIs are added here as the RHI
  needs them.
- The **transitive Objective-C closure** of those declarations: every type
  reachable from a selected declaration's public signature, including
  Foundation, CoreFoundation and CoreGraphics types, records, typedefs, enums,
  protocols, blocks, and superclass requirements.
- Everything else visible in the SDK is **excluded**, with a deterministic
  reason recorded in the manifest.

Selection decides only *what* is bound. Every semantic property comes from the
Objective-C Clang AST regardless of how a declaration was selected.

## Phase order

The phases are ordered so that correctness work lands before surface work.

The governing principle is that **verification must be generated, not
hand-written**. If every record carries generated `comptime` size, alignment and
field-offset assertions derived from Clang, and every signature is derived from
the AST, then robustness is a property of the generator rather than of the
surface, and the size of the bound surface stops being a risk to manage. This is
why surface curation is deliberately the *last* implementation phase rather than
the first.

The immediate backlog is what the manifest already reveals about the current
generator, once its own accounting is read carefully:

- **No struct is generated.** All 42 Metal record entries are unbound. Every
  struct the bindings actually expose is hand-written in `src/metal.zig` — 23 of
  them, which the manifest detects as `manual` typedefs. Only 6 carry a
  `@sizeOf` assertion, and none assert alignment or field offsets. Layout
  fidelity currently rests on hand-transcribed constants.
- **All 30 `rejected` entries are a single bug.** Every one is a boolean
  property with a `getter=isFoo` attribute: `rasterizationEnabled`, `headless`,
  `lowPower`, `framebufferOnly`, `blendingEnabled`, `active`, `used`, and so on.
  The getter itself is generated correctly — `isRasterizationEnabled` is present
  in the output. Only the property-to-accessor match fails, because property
  status is resolved by looking up a *method of the same name* and never
  considers the `is` form or Clang's `getter=` attribute.
- **The real gaps are hiding in `excluded`.**
  `MTLAccelerationStructureInstanceDescriptor`, `MTLPackedFloat3`,
  `MTLPackedFloat4x3`, `MTLComponentTransform`,
  `MTLDrawPrimitivesIndirectArguments`,
  `MTLDrawIndexedPrimitivesIndirectArguments` and
  `MTLDispatchThreadsIndirectArguments` are all classified as "valid SDK typedef
  outside the selected binding surface" — indistinguishable from genuinely
  irrelevant API. Instance acceleration structures and indirect draws are RHI
  blockers, not out-of-scope API.

The third point is the important one: `excluded` cannot be trusted to mean "safe
to ignore" until reachability from the selection list is actually computed. That
is Phase 10, and it is the one part of the abandoned Phase 4 worth keeping.

## Implementation Changes

### 1. ARM64 runtime and messaging — P0, M — **done**

- Add a compile-time error for non-ARM64 targets.
- Remove all x86, `objc_msgSend_stret`, and `objc_msgSend_fpret` paths.
- Use a correctly typed ordinary `objc_msgSend` for every ARM64 call.
- Replace the racy selector cache with an atomic per-call-site cache; concurrent
  initialization may register the selector more than once, but only the
  canonical runtime selector is stored.
- Verify instance, class, and superclass dispatch through an Objective-C ABI
  fixture.
- Validate Zig `bool` against ARM64 Objective-C `BOOL`.

### 2. Runtime class and availability primitives — P0/P1, M — **done**

- Resolve classes through the Objective-C runtime rather than unconditional
  strong Mach-O class references.
- Give every generated class `classIfAvailable() ?*objc.Class`.
- Keep `class() *objc.Class` as a checked convenience that fails clearly when the
  class is unavailable.
- Add a generic `respondsTo` helper for selector capability checks.
- Retain existing raw `retain`, `release`, and `autorelease`.
- Add a Zig-native scoped autorelease-pool value with `init()`/`deinit()`.

### 3. Fail-closed AST conversion — P0, L — **done**

- Replace silent enum fallback-to-zero with Clang-evaluated values or a
  generation error.
- Require every `FunctionDecl`, `RecordDecl`, `VarDecl`, method, property,
  typedef, and enum to be classified as `generated`, `manual`, `excluded`, or
  `rejected`.
- Reject unsupported arrays, vectors, pointer combinations, block signatures,
  anonymous records, and expressions rather than guessing.
- Define `rejected` as a selected declaration that cannot be represented safely
  and `excluded` as valid SDK API outside the selected surface.
- Generate a declaration manifest with declaration name, kind, Objective-C
  header, status, and reason.
- Add transactional output generation, preventing partially overwritten
  bindings.

### 4. Records, property accessors, and generated ABI verification — P0, L

This phase makes layout fidelity a generated property and clears the current
`rejected` list.

- Fix property-to-accessor resolution: match a property against its real getter,
  honouring Clang's `getter=` attribute and the `isFoo` convention, rather than
  requiring a method whose name equals the property's. This alone should take
  the Metal `rejected` count to zero.
- Generate C records and their typedefs from the Objective-C Clang AST instead
  of hand-writing them. Retain a manual Zig record only when it is allowlisted,
  audited, and layout-verified.
- For every generated or manual record, emit generated `comptime` assertions for
  size, alignment, and every field offset, with the values obtained from Clang
  rather than restated by hand. A record whose layout Clang cannot supply is a
  generation error, not a silent omission. Replace the six hand-written
  `@sizeOf` asserts in `src/metal.zig` with generated ones.
- Resolve named typedefs of anonymous structs to a single Zig declaration, so
  `MTLOrigin` and its underlying anonymous record are one entry rather than a
  manual typedef plus an excluded record.
- Generate exported C functions with their ownership and nullability attributes.
- Generate exported constants, notification names, error domains, and counter
  names, or record an explicit audited reason for each one that is not
  generated.
- Emit block typedefs, or reject them with a specific reason rather than a
  generic one.
- Preserve signedness, integer width, pointer constness, enum underlying types,
  and output-pointer shapes such as `NSError **`.
- Goal for this phase: zero `rejected` entries, and zero bound structs whose
  layout is asserted by hand.

### 5. Nullability and ABI type fidelity — P0, M

- Preserve `_Nonnull`, `_Nullable`, `_Nullable_result`, `_Null_unspecified`,
  nullable blocks, nullable `instancetype`, and nested pointer nullability.
- Map `_Null_unspecified` to a nullable Zig pointer.
- Make `new`, `alloc`, and `allocInit` return optional pointers.
- Preserve block calling conventions.
- Store nullability in the manifest so it can be tested.

### 6. Ownership semantics without ownership wrappers — P1, M

- Parse method families and Clang ownership attributes: retained, not-retained,
  autoreleased, consumed arguments, consumed `self`, and CoreFoundation
  Create/Copy rules.
- Keep generated signatures as raw pointers.
- Emit generated documentation stating whether an object result is +1 or +0 and
  whether object arguments are borrowed or consumed.
- Store ownership classification in the generated manifest so it can be tested.
- Respect explicit Objective-C attributes over selector-name inference.
- Do not add generic `Owned`, `Borrowed`, `SharedPtr`, or transfer-pointer types.

### 7. Block ABI and lifetime safety — P1, M

Moved ahead of the remaining surface work: blocks are required for async
pipeline and library compilation, and they are the least forgiving part of the
ABI.

- Harden the existing in-tree block implementation rather than adding another
  runtime library.
- Cover global, stack, copied heap, escaping, nullable, captured-value,
  captured-object, cross-thread, multi-argument, and return-value blocks.
- Verify copy/dispose callbacks and captured Objective-C retain/release balance.
- Preserve `noescape`, nullability, and exact generated signatures.
- Use Apple's Block ABI as the authority.

### 8. Availability and weak linking — P1, L

- Parse introduced, deprecated, obsoleted, unavailable, platform, and
  replacement metadata.
- Treat macOS 26.0 as the deployment floor; APIs introduced after 26.0 require
  runtime availability checks.
- Resolve newer classes and exported constants weakly.
- Derive availability, weak linking, and safe fallback behaviour exclusively from
  Objective-C declarations and runtime capability checks.
- Generate availability documentation and machine-readable manifest data.
- Ensure building against Xcode 26.5 does not unconditionally require every 26.5
  symbol at runtime.
- Generate safe fallback behaviour only for Apple-style capability queries where
  returning `false` is semantically correct; other unavailable calls remain
  explicit caller errors.

### 9. Constructors, properties, and lifetime annotations — P1, M

- Do not emit `new` or `allocInit` when the SDK marks the relevant initializer
  unavailable. (This replaces the current unconditional emission and its TODO.)
- Preserve property `strong`, `copy`, `weak`, and `assign` semantics in generated
  documentation and metadata.
- Highlight unretained stored properties explicitly.
- Preserve designated/unavailable initializer information where Clang exposes it.

### 10. Explicit selection profile and transitive closure — P1, M

- Keep the explicit selection list as the single source of what is bound. Adding
  an API is a one-line `addInterface`/`addProtocol`/`addEnum` edit followed by
  regeneration.
- Compute the transitive Objective-C type closure of the explicit list
  automatically, so selecting a declaration also selects every type reachable
  from its public signature — Foundation, CoreFoundation, CoreGraphics, records,
  typedefs, enums, protocols, blocks, and superclass requirements. Hand-tracking
  these dependencies is the failure mode this phase exists to remove.
- Record provenance per declaration as `explicit`, `transitive_dependency`, or
  `sdk_only`, and fail generation on any declaration reachable from the explicit
  list that is neither generated nor audited.
- Preserve protocol inheritance, categories, generic object types,
  pointer-plus-count APIs, blocks, and error output parameters within the
  closure.
- Keep the narrow CALayer, CAMetalLayer, and AppKit native-hosting allowlist as
  an explicit hosting selection; do not discover additional AppKit or general
  QuartzCore APIs.
- Keep full SDK declarations visible as excluded audit entries without emitting
  them.

### 11. Documentation and package contract — P2, S

- Document supported architecture, deployment floor, SDK pin, ownership rules,
  availability behaviour, autorelease-pool requirements, and the regeneration
  workflow.
- Keep generated names Zig/Objective-C-shaped.
- State that generated raw pointers follow Cocoa ownership rather than enforcing
  ownership in Zig's type system.
- Report the SDK version and the generated/manual/excluded/rejected counts during
  generation.

## Generator Interfaces and Compatibility

- `zig build generate` regenerates all frameworks from the pinned SDK.
- The generator requires no third-party source input. Its only external inputs
  are the macOS SDK root and the frameworks directory.
- Existing generated Metal, MetalFX, QuartzCore, CALayer, and AppKit APIs remain
  source-compatible unless the manifest proves an API is outside the selected
  surface.
- Changing the SDK pin requires an explicit reviewed surface diff.

## Dependency Assessment

### Do not add metal-cpp

metal-cpp was evaluated as a generator-time API-scope inventory and rejected.
The evaluation was implemented in full and measured; the branch is preserved at
`wip/phase4-metal-cpp`. Findings:

- Against the existing explicit selection list, the complete scope machinery
  changed generated output by **+15 / -28 lines across 13,400 lines** of
  bindings. The explicit list already produces effectively the same surface,
  because metal-cpp wraps whole classes and so does the generator.
- The delta was net negative. It removed real Xcode 26.5 APIs that metal-cpp
  26.4 does not declare, including `MTLIndirectComputeCommandEncoder`,
  `MTLIndirectRenderCommandEncoder`, `MTLCaptureScope.mtl4CommandQueue`,
  `MTLFunctionReflection.userAnnotation`, `MTLFXFrameInterpolator.uiTextureUsage`
  and `MTLFXTemporalScaler.reactiveMaskTextureFormat`.
- It raised the Metal `rejected` count from 30 to 47 and introduced 11
  `sdk_absent` entries — permanent skew to maintain.
- It pinned the binding surface to Apple's C++ release cadence. Every SDK bump
  would then require metal-cpp to catch up, or two pins that disagree.
- It could not improve robustness by construction: by design it was never a
  semantic authority, so every ABI, nullability, ownership, enum, layout and
  availability property still came from the Objective-C Clang AST.
- It converted "the surface I chose" into "parity with 3,292 external scope
  entries", which is an obligation to verify, not an asset.

For hand-picking new APIs, Apple's documentation and the metal-cpp repository
remain readable directly. Neither belongs in the build.

### Do not add `mitchellh/zig-objc`

- ARM64 message dispatch, selector registration, class lookup, retain/release,
  and autorelease pools are small and already substantially present in-tree.
- Its largest potential benefit — cross-architecture message classification — is
  irrelevant after dropping x86.
- It does not provide Metal AST generation, nullability, ownership
  classification, availability, weak linking, or declaration completeness.
- It would introduce a second `Object`/`Class`/`Sel` type universe and a
  translated-runtime-header build path.
- Its block implementation may be consulted as reference, but block fixes should
  remain in the canonical in-tree runtime.
- If implementation details are ported, preserve required MIT attribution.

## Test and Release Gate

- Maintain the ARM64 Objective-C fixture covering scalars, `BOOL`, pointers,
  nil, floats, structs of several sizes, class messages, superclass messages,
  and blocks.
- Test Debug, ReleaseSafe, and ReleaseFast.
- Verify every record's size, alignment, and field offsets against Objective-C
  Clang, through generated assertions rather than hand-written ones.
- Test nullable returns, nested output pointers, unavailable constructors, weak
  classes/constants, and post-macOS-26.0 availability.
- Test ownership classification for normal, `new`, `copy`, `init`, explicitly
  retained/not-retained, and consumed declarations.
- Test selector initialization concurrently.
- Test all block lifetime cases and autorelease pools with missing-pool
  diagnostics enabled.
- Verify that every declaration reachable from the explicit selection list is
  generated or audited, and that no reachable declaration is silently dropped.
- Verify out-of-profile QuartzCore and AppKit declarations are excluded rather
  than rejected.
- Preserve the existing native AppKit/CAMetalLayer example and the Metal 4 smoke
  test as runtime evidence, while treating them separately from ABI and
  declaration completeness.
- Regenerate twice from the pinned SDK and require identical manifests and Zig
  output.
- Fail on unclassified declarations, missing exclusion reasons, unaudited manual
  declarations, or checked-in generation diffs. `verify.sh` is the gate.

Parity is achieved only when the selected surface has zero rejected or
unsupported declarations, all selected manual declarations are audited,
generated sources are fresh, and ABI/block/availability tests pass. Excluded SDK
declarations are permitted and must retain deterministic reasons.

## Assumptions

- Primary and only claimed runtime target is Apple ARM64 macOS on M-series
  hardware.
- Deployment compatibility begins at macOS 26.0.
- The selected profile is the explicit selection list plus its transitive
  Objective-C closure; it grows as the RHI needs APIs.
- Xcode 26.5 is the initial ABI baseline; later SDK upgrades require an explicit
  regenerated review.
- Generated bindings remain a raw Objective-C layer with Cocoa ownership
  semantics.
- Full RHI implementation and Vulkan work are outside this plan.
- Estimated remaining implementation effort after Phase 3 is approximately 3-4
  focused weeks.
