# Metal Objective-C Zig Bindings Robustness Plan

## Summary

Target parity is metal-cpp API coverage with Objective-C robustness and semantics, without exposing C++ concepts:

- `aarch64-macos` only, deployment floor macOS 26.0, generated from Xcode 26.5.
- Raw Zig object pointers following Cocoa ownership conventions.
- No x86 support, C++ headers in the public or generated API, `MTL::` types, shared-pointer terminology, or Rust-style owned returns.
- No `zig-objc` dependency.
- The selected surface is the pinned metal-cpp API plus the existing narrow CALayer, CAMetalLayer, and AppKit native-hosting additions and all transitively required ABI types.
- Xcode 26.5 Objective-C declarations are the sole authority for signatures, ABI, enum values, record layouts, nullability, ownership, properties, availability, weak linking, and block signatures.
- metal-cpp is a generator-only API-scope inventory, never a semantic authority, runtime dependency, or source of generated Zig types.

Priority: P0 is a correctness blocker, P1 is required for parity, and P2 is hardening. Effort: S <1 day, M 1–3 days, L 4–8 days, XL multiple weeks.

Current state: Phases 1–3 are implemented. Phase 3 is committed at `39c6a2c`; only this planning-document revision remains in the working tree.

## Implementation Changes

### 1. ARM64 runtime and messaging — P0, M

- Add a compile-time error for non-ARM64 targets.
- Remove all x86, `objc_msgSend_stret`, and `objc_msgSend_fpret` paths.
- Use a correctly typed ordinary `objc_msgSend` for every ARM64 call.
- Replace the racy selector cache with an atomic per-call-site cache; concurrent initialization may register the selector more than once, but only the canonical runtime selector is stored.
- Verify instance, class, and superclass dispatch through an Objective-C ABI fixture.
- Validate Zig `bool` against ARM64 Objective-C `BOOL`; keep Zig `bool` only if the fixture confirms argument and return compatibility.

### 2. Runtime class and availability primitives — P0/P1, M

- Resolve classes through the Objective-C runtime rather than unconditional strong Mach-O class references.
- Give every generated class `classIfAvailable() ?*objc.Class`.
- Keep `class() *objc.Class` as a checked convenience that fails clearly when the class is unavailable.
- Add a generic `respondsTo` helper for selector capability checks.
- Retain existing raw `retain`, `release`, and `autorelease`.
- Add a Zig-native scoped autorelease-pool value with `init()`/`deinit()`.

### 3. Fail-closed AST conversion — P0, L

- Replace silent enum fallback-to-zero with Clang-evaluated values or a generation error.
- Require every `FunctionDecl`, `RecordDecl`, `VarDecl`, method, property, typedef, and enum to be classified as `generated`, `manual`, `rejected`, or `excluded`.
- Reject unsupported arrays, vectors, pointer combinations, block signatures, anonymous records, and expressions rather than guessing.
- Define `rejected` as a selected declaration that cannot be represented safely and `excluded` as valid SDK API outside the metal-cpp-plus-hosting surface.
- Generate the declaration manifest with declaration name, kind, Objective-C header, status, reason, and provenance. Provenance is `metal_cpp`, `hosting_overlay`, `transitive_dependency`, or `sdk_only`; Phase 4 supplies metal-cpp selection and cross-reference data.
- Inventory Metal, MetalFX, QuartzCore, the native-hosting AppKit subset, and declarations transitively required by their public signatures without treating every inventoried SDK declaration as selected.

### 4. Pinned metal-cpp scope inventory — P0, L

- Reuse Apple metal-cpp commit `c595afef4a5dc388f4047cd0c69f9e7f9468d9ed`, whose checked-in metadata identifies the macOS 26.4 surface.
- Add the same pinned dependency to the standalone `mach-objc` generator package and fail if its URL or hash drifts from the root package pin.
- Generate a deterministic scope manifest for the public classes, methods, functions, enums, records, and constants exposed by metal-cpp. These entries are coverage seeds only and do not supply generated types or semantics.
- Use Clang’s C++ AST only where useful to associate a public declaration with its enclosing wrapper and inline implementation; do not convert or compare the C++ type system.
- Strictly extract the private bridge macros for Objective-C runtime classes, protocols, selector strings, exported symbols, and constants as scope evidence.
- Map C++ methods to Objective-C declarations through runtime class or protocol, class-versus-instance dispatch, and the selector referenced by inline `sendMessage` or `sendMessageSafe`; do not match by translated C++ method name alone.
- Match global functions and constants by exported symbol. Map wrapper, enum, and record names to Objective-C identities through an explicit prefix table plus audited overrides, and fail on missing or ambiguous mappings.
- Exclude C++ conveniences such as `std::function` overloads, constructors, `Make` helpers, templates, and `NS::SharedPtr` from the Objective-C binding surface.
- Intersect the metal-cpp 26.4 surface with Xcode 26.5. Mark SDK-only declarations absent from the pin as excluded, and report metal-cpp declarations absent from the SDK without generating them.
- After matching each coverage seed, obtain its complete signature and semantics exclusively from the Objective-C Clang AST, then compute the transitive Objective-C type closure including Foundation, CoreFoundation, CoreGraphics, records, typedefs, enums, protocols, blocks, and superclass requirements.
- Preserve the current explicitly allowlisted CALayer, CAMetalLayer, and AppKit APIs as a `hosting_overlay`; do not discover additional AppKit or general QuartzCore APIs.
- Record the metal-cpp commit and release, SDK path and version, metal-cpp evidence location and kind, Objective-C header, runtime name or symbol, selector, and class-versus-instance dispatch.
- Treat `sendMessageSafe`, weak-constant machinery, C++ return types, and C++ parameter types only as evidence that an API belongs in the selected profile; infer no availability, fallback, ownership, nullability, or ABI semantics from them.

### 5. Nullability and ABI type fidelity — P0, M

- Preserve `_Nonnull`, `_Nullable`, `_Nullable_result`, `_Null_unspecified`, nullable blocks, nullable `instancetype`, and nested pointer nullability.
- Map `_Null_unspecified` to a nullable Zig pointer.
- Make `new`, `alloc`, and `allocInit` return optional pointers.
- Preserve signedness, integer width, pointer constness, enum underlying types, block calling conventions, and output-pointer shapes such as `NSError **`.
- Add size, alignment, and field-offset verification for every generated or manual record.

### 6. Ownership semantics without ownership wrappers — P1, M

- Parse method families and Clang ownership attributes: retained, not-retained, autoreleased, consumed arguments, consumed `self`, and CoreFoundation Create/Copy rules.
- Keep generated signatures as raw pointers.
- Emit generated documentation stating whether an object result is +1 or +0 and whether object arguments are borrowed or consumed.
- Store ownership classification in the generated manifest so it can be tested.
- Respect explicit Objective-C attributes over selector-name inference; do not infer ownership from metal-cpp method names or wrappers.
- Do not add generic `Owned`, `Borrowed`, `SharedPtr`, or transfer-pointer types.

### 7. Constructors, properties, and lifetime annotations — P1, M

- Do not emit `new` or `allocInit` when the SDK marks the relevant initializer unavailable.
- Preserve property `strong`, `copy`, `weak`, and `assign` semantics in generated documentation and metadata.
- Highlight unretained stored properties explicitly.
- Preserve designated/unavailable initializer information where Clang exposes it.

### 8. Availability and weak linking — P1, L

- Parse introduced, deprecated, obsoleted, unavailable, platform, and replacement metadata.
- Treat macOS 26.0 as the deployment floor; APIs introduced after 26.0 require runtime availability checks.
- Resolve newer classes and exported constants weakly.
- Derive availability, weak linking, and safe fallback behaviour exclusively from Objective-C declarations and runtime capability checks.
- Generate availability documentation and machine-readable manifest data.
- Ensure building against Xcode 26.5 does not unconditionally require every 26.5 symbol at runtime.
- Generate safe fallback behaviour only for Apple-style capability queries where returning `false` is semantically correct; other unavailable calls remain explicit caller errors.

### 9. Complete selected declaration surface — P1, L

- Generate selected exported functions and their ownership/nullability attributes.
- Generate or explicitly audit selected exported constants, notification names, error domains, and counter names.
- Generate C records where practical; retain manual Zig records only when allowlisted and fully layout-verified.
- Preserve protocol inheritance, categories, generic object types, pointer-plus-count APIs, blocks, and error output parameters within the selected closure.
- Require manifest coverage to match the selected metal-cpp-plus-hosting surface and its reachable Objective-C AST closure.
- Keep full SDK declarations visible as excluded audit entries without emitting them or allowing them to block parity.

### 10. Block ABI and lifetime safety — P1, M

- Harden the existing in-tree block implementation rather than adding another runtime library.
- Cover global, stack, copied heap, escaping, nullable, captured-value, captured-object, cross-thread, multi-argument, and return-value blocks.
- Verify copy/dispose callbacks and captured Objective-C retain/release balance.
- Preserve `noescape`, nullability, and exact generated signatures.
- Use Apple’s Block ABI as the authority.

### 11. Documentation and package contract — P2, M

- Document supported architecture, deployment floor, SDK pin, metal-cpp pin and role, ownership rules, availability behaviour, autorelease-pool requirements, and regeneration workflow.
- Keep generated names Zig/Objective-C-shaped and prevent C++ names, inheritance, overloads, templates, and ownership wrappers from entering generated Zig.
- State that generated raw pointers follow Cocoa ownership rather than enforcing ownership in Zig’s type system.
- Report the SDK, metal-cpp revision, selected/excluded counts, and manifest counts during generation.

## Generator Interfaces and Compatibility

- `zig build generate` resolves the pinned metal-cpp dependency automatically.
- Direct generator invocation requires `--metal-cpp-root <path>` for Metal, MetalFX, QuartzCore, and native-hosting surface generation.
- Existing generated Metal, MetalFX, QuartzCore, CALayer, and AppKit hosting APIs remain source-compatible unless the manifest proves that an API belongs to neither metal-cpp nor the existing hosting overlay.
- No project-minimal, workload-derived, or RHI-derived profile is introduced.
- Changing either the metal-cpp commit or SDK pin requires an explicit reviewed surface diff.

## Dependency Assessment

Use the pinned Apple metal-cpp source only as a generator-time API-scope inventory.

- The root package already pins commit `c595afef4a5dc388f4047cd0c69f9e7f9468d9ed`; the standalone generator must use the identical URL and content hash.
- Do not link metal-cpp into the generated bindings or expose its C++ declarations.
- Preserve required Apache-2.0 attribution when extracting or deriving metadata from metal-cpp.
- Never use metal-cpp declarations to generate or validate Zig ABI types, enum values, layouts, ownership, nullability, availability, or weak-linking behaviour. Objective-C SDK headers and ABI fixtures are authoritative for all of them.

Do not add `mitchellh/zig-objc`.

- ARM64 message dispatch, selector registration, class lookup, retain/release, and autorelease pools are small and already substantially present in-tree.
- Its largest potential benefit—cross-architecture message classification—is irrelevant after dropping x86.
- It does not provide Metal AST generation, nullability, ownership classification, availability, weak linking, or declaration completeness.
- It would introduce a second `Object`/`Class`/`Sel` type universe and translated-runtime-header build path.
- Its block implementation may be consulted as reference, but block fixes should remain in the canonical in-tree runtime.
- If implementation details are ported, preserve required MIT attribution.

## Test and Release Gate

- Add an ARM64 Objective-C fixture covering scalars, `BOOL`, pointers, nil, floats, structs of several sizes, class messages, superclass messages, and blocks.
- Test Debug, ReleaseSafe, and ReleaseFast.
- Add golden scope mappings for class/protocol lookup, ordinary and safe selector references, constants, global functions, overloaded wrapper methods, records, and enums.
- Verify `std::function`, `NS::SharedPtr`, constructors, templates, and convenience helpers never enter the Objective-C binding surface.
- Verify every selected metal-cpp scope entry maps to exactly one compatible Objective-C declaration or an explicit audited override, and that every emitted signature and semantic attribute originates from that Objective-C declaration.
- Verify out-of-profile QuartzCore and AppKit declarations are excluded rather than rejected.
- Verify every record’s size, alignment, and field offsets against Objective-C Clang.
- Test nullable returns, nested output pointers, unavailable constructors, weak classes/constants, and post-macOS-26.0 availability.
- Test ownership classification for normal, `new`, `copy`, `init`, explicitly retained/not-retained, and consumed declarations.
- Test selector initialization concurrently.
- Test all block lifetime cases and autorelease pools with missing-pool diagnostics enabled.
- Preserve the existing native AppKit/CAMetalLayer example and real Metal 4 smoke test as runtime evidence, while treating them separately from ABI and declaration completeness.
- Regenerate twice from the pinned inputs and require identical surface manifests, binding manifests, and Zig output.
- Fail on metal-cpp pin drift between packages, unmapped selected declarations, ambiguous mappings, unclassified declarations, missing exclusion reasons, unaudited manual declarations, or checked-in generation diffs.

Parity is achieved only when the selected surface has zero rejected or unsupported declarations, all selected manual declarations are audited, generated sources are fresh, ABI/block/availability tests pass, and the SDK, architecture, metal-cpp revision, and surface profile are recorded. Excluded SDK declarations are permitted and must retain deterministic reasons.

## Assumptions

- Primary and only claimed runtime target is Apple ARM64 macOS on M-series hardware.
- Deployment compatibility begins at macOS 26.0.
- The selected profile is the full pinned metal-cpp 26.4 surface plus the existing native-hosting overlay, intersected with Xcode 26.5; metal-cpp defines coverage only.
- Xcode 26.5 is the initial ABI baseline; later SDK upgrades require explicit regenerated review.
- Generated bindings remain a raw Objective-C layer with Cocoa ownership semantics.
- No project-minimal or RHI-derived binding profile is planned.
- Full RHI implementation and Vulkan work are outside this plan.
- The scope-inventory phase is estimated at 3–5 focused days; its narrower completeness target offsets much of the added implementation effort.
- Estimated remaining implementation effort after Phase 3 is approximately 4–6 focused weeks.
