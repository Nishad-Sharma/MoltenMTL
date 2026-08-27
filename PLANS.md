# Metal Objective-C Zig Bindings Robustness Plan

## Summary

Target parity is metal-cpp’s robustness and Objective-C semantics without exposing C++ concepts:

- `aarch64-macos` only, deployment floor macOS 26.0, generated from Xcode 26.5.
- Raw Zig object pointers following Cocoa ownership conventions.
- No x86 support, C++ headers, `MTL::` types, shared-pointer terminology, or Rust-style owned returns.
- No `zig-objc` dependency.
- Complete, fail-closed generation for the Metal, MetalFX, QuartzCore, and transitively required Foundation declarations.

Priority: P0 is a correctness blocker, P1 is required for parity, and P2 is hardening. Effort: S <1 day, M 1–3 days, L 4–8 days, XL multiple weeks.

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
- Require every `FunctionDecl`, `RecordDecl`, `VarDecl`, method, property, typedef, and enum in the selected surface to be generated, manually audited, or rejected.
- Reject unsupported arrays, vectors, pointer combinations, block signatures, anonymous records, and expressions rather than guessing.
- Generate a manifest recording declaration name, kind, header, generated/manual status, and exclusion reason.
- Limit the surface to Metal, MetalFX, QuartzCore, and declarations transitively required by their public signatures.

### 4. Nullability and ABI type fidelity — P0, M

- Preserve `_Nonnull`, `_Nullable`, `_Nullable_result`, `_Null_unspecified`, nullable blocks, nullable `instancetype`, and nested pointer nullability.
- Map `_Null_unspecified` to a nullable Zig pointer.
- Make `new`, `alloc`, and `allocInit` return optional pointers.
- Preserve signedness, integer width, pointer constness, enum underlying types, block calling conventions, and output-pointer shapes such as `NSError **`.
- Add size, alignment, and field-offset verification for every generated or manual record.

### 5. Ownership semantics without ownership wrappers — P1, M

- Parse method families and Clang ownership attributes: retained, not-retained, autoreleased, consumed arguments, consumed `self`, and CoreFoundation Create/Copy rules.
- Keep generated signatures as raw pointers.
- Emit generated documentation stating whether an object result is +1 or +0 and whether object arguments are borrowed or consumed.
- Store ownership classification in the generated manifest so it can be tested.
- Respect explicit attributes over selector-name inference.
- Do not add generic `Owned`, `Borrowed`, `SharedPtr`, or transfer-pointer types.

### 6. Constructors, properties, and lifetime annotations — P1, M

- Do not emit `new` or `allocInit` when the SDK marks the relevant initializer unavailable.
- Preserve property `strong`, `copy`, `weak`, and `assign` semantics in generated documentation and metadata.
- Highlight unretained stored properties explicitly.
- Preserve designated/unavailable initializer information where Clang exposes it.

### 7. Availability and weak linking — P1, L

- Parse introduced, deprecated, obsoleted, unavailable, platform, and replacement metadata.
- Treat macOS 26.0 as the deployment floor; APIs introduced after 26.0 require runtime availability checks.
- Resolve newer classes and exported constants weakly.
- Generate availability documentation and machine-readable manifest data.
- Ensure building against Xcode 26.5 does not unconditionally require every 26.5 symbol at runtime.
- Generate safe fallback behaviour only for Apple-style capability queries where returning `false` is semantically correct; other unavailable calls remain explicit caller errors.

### 8. Complete declaration surface — P1, L–XL

- Generate exported functions and their ownership/nullability attributes.
- Generate or explicitly audit exported constants, notification names, error domains, and counter names.
- Generate C records where practical; retain manual Zig records only when allowlisted and fully layout-verified.
- Preserve protocol inheritance, categories, generic object types, pointer-plus-count APIs, blocks, and error output parameters.
- Require manifest coverage to match the reachable Clang AST surface.

### 9. Block ABI and lifetime safety — P1, M

- Harden the existing in-tree block implementation rather than adding another runtime library.
- Cover global, stack, copied heap, escaping, nullable, captured-value, captured-object, cross-thread, multi-argument, and return-value blocks.
- Verify copy/dispose callbacks and captured Objective-C retain/release balance.
- Preserve `noescape`, nullability, and exact generated signatures.
- Use Apple’s Block ABI as the authority.

### 10. Documentation and package contract — P2, M

- Document supported architecture, deployment floor, SDK pin, ownership rules, availability behaviour, autorelease-pool requirements, and regeneration workflow.
- Keep generated names Zig/Objective-C-shaped.
- State that generated raw pointers follow Cocoa ownership rather than enforcing ownership in Zig’s type system.
- Report the SDK and manifest counts during generation.

## Dependency Assessment

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
- Verify every record’s size, alignment, and field offsets against Clang.
- Test nullable returns, nested output pointers, unavailable constructors, weak classes/constants, and post-macOS-26.0 availability.
- Test ownership classification for normal, `new`, `copy`, `init`, explicitly retained/not-retained, and consumed declarations.
- Test selector initialization concurrently.
- Test all block lifetime cases and autorelease pools with missing-pool diagnostics enabled.
- Regenerate from the pinned SDK and fail on checked-in diffs.
- Fail if the manifest contains unsupported or unaudited declarations.
- Retain the existing real Metal 4 smoke test as runtime evidence, while treating it separately from ABI and declaration completeness.

Parity is achieved only when the report shows zero unsupported declarations, all manual declarations are audited, generated sources are fresh, ABI/block/availability tests pass, and the selected SDK and architecture are recorded.

## Assumptions

- Primary and only claimed runtime target is Apple ARM64 macOS on M-series hardware.
- Deployment compatibility begins at macOS 26.0.
- Xcode 26.5 is the initial parity baseline; later SDK upgrades require explicit regenerated review.
- Generated bindings remain a raw Objective-C layer with Cocoa ownership semantics.
- Full RHI implementation and Vulkan work are outside this plan.
- Estimated effort for implementation after the plan is approved: approximately 4–6 focused weeks.
