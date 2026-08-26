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
const apple = @import("mach-objc");

const device = apple.metal.createSystemDefaultDevice() orelse return error.NoDevice;
defer device.release();

const queue = device.newMTL4CommandQueue() orelse return error.Metal4Unavailable;
defer queue.release();
```

This package is derived from [mach-objc](https://code.hexops.org/hexops/mach-objc).
