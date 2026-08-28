# Slag

A Zig graphics API intended to abstract over Vulkan and Metal 4.

## Current state

The repository currently contains only `metal-zig`: a generator that produces
Zig bindings to the Objective-C APIs the RHI needs — Metal, MetalFX, and the
narrow QuartzCore surface required to present a Metal layer.
removed; the RHI will be rebuilt directly on the generated Objective-C
bindings.

See `PLANS.md` for the robustness plan and its phase order.

## metal-zig

Xcode's Objective-C headers are the sole authority for signatures, ABI, enum
values, record layouts, nullability, ownership, availability, and block
signatures. The generator reads Clang's Objective-C AST and fails generation
rather than guessing.

- Target is `aarch64-macos` only, deployment floor macOS 26.0.
- Generated bindings are a raw Objective-C layer: plain Zig pointers following
  Cocoa ownership conventions, with no ownership wrappers in the type system.
- Every declaration in the inventoried surface is classified in a checked-in
  manifest as `generated`, `manual`, `excluded`, or `rejected`, so coverage and
  known gaps are reviewable.

Build and test:

```sh
cd metal-zig
zig build test          # ABI fixture, runtime, generator and Metal 4 tests
./verify.sh             # regenerate, test, and fail on any checked-in diff
```

Windowing is out of scope: the bindings stop at `CAMetalLayer`, and whatever
owns the window — SDL3, GLFW — hands one over.

Objects returned by the bindings follow Cocoa retain/release ownership. Release
them explicitly, and use `objc.AutoreleasePool.init()`/`deinit()` on threads
that call into Metal.
