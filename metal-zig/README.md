# Metal Objective-C bindings for Zig

Generated direct Objective-C bindings for the graphics frameworks shipped with Xcode 26:

- Metal's complete `MTL*` and `MTL4*` Objective-C interfaces, protocols, methods, and enums
- MetalFX, including `MTLFX*` and `MTL4FX*`
- QuartzCore's `CALayer`, `CAMetalLayer`, and `CAMetalDrawable` presentation path
- the Objective-C and Foundation runtime types required by those APIs

The package deliberately does not generate unrelated Apple frameworks.

## Generate

The default generation command reads the SDK selected by the stable Xcode SDK symlink:

```sh
zig build generate
```

An explicit SDK can be selected when required:

```sh
zig build generate -Dmacos-sdk="$(xcrun --sdk macosx --show-sdk-path)"
```

Generated sources are checked in under `src/generated`. The handful of C records used by Metal
4 remain explicit `extern struct` declarations in `src/metal.zig`; Objective-C interfaces,
protocols, methods, and enums are generated from the SDK AST.

## Use

```zig
const apple = @import("metal-zig");

const device = apple.metal.createSystemDefaultDevice() orelse return error.NoDevice;
defer device.release();

const queue = device.newMTL4CommandQueue() orelse return error.Metal4Unavailable;
defer queue.release();
```

## Windowing

There is none, deliberately. The bindings cover Metal, MetalFX and the
`CALayer`/`CAMetalLayer`/`CAMetalDrawable` presentation path; the window that hosts the layer is
someone else's job -- SDL3, GLFW, or AppKit through whatever binding you already have. A
`CAMetalLayer` vends drawables whether or not it is attached to a window, so `tests/metal_drawable.zig`
covers `nextDrawable` and `present` without one.

`tests/metal4_raytrace.zig` is the end-to-end check: it compiles MSL from source, builds a
primitive acceleration structure, ray-queries it from a compute kernel, and asserts the hit through
a shared event. It needs a Metal device but no window server.

This package is derived from [metal-zig](https://code.hexops.org/hexops/metal-zig).
