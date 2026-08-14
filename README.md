# MoltenMTL
> ⚠️ **Work in progress.** The compute pipeline, ray tracing (BLAS/TLAS acceleration structures + ray queries), and the render pipeline (vertex/fragment shaders, depth/stencil, blending) are all implemented. The API surface is still growing — see [Status](#status) and [Known Limitations](#known-limitations).

MoltenMTL - a cross platform API that allows you to use the Metal API on windows (plans for linux) with spirv shaders

There is **no shader translation**. Shaders are plain SPIR-V, consumed natively by Vulkan. The `MTL*` wrappers are thin Swift classes that hold Vulkan handles directly.

<p align="center">
  <img src="docs/raytraced-cube.png" alt="Ray-traced cube rendered through MoltenMTL" width="256">
  &nbsp;&nbsp;
  <img src="docs/rasterized-cube.png" alt="Rasterized cube rendered through MoltenMTL" width="256">
  <br>
  <em>The same scene rendered two ways: ray-traced via Metal acceleration structures (left, <a href="Examples/RayTracedCube">RayTracedCube</a>) and rasterized through the render pipeline (right, <a href="Examples/RasterizedCube">RasterizedCube</a>).</em>
</p>

---

## Status

### Core

| Feature | Status |
|---|---|
| `MTLDevice` / `MTLCommandQueue` | ✅ Done |
| `MTLBuffer` (shared + private storage) | ✅ Done |
| `MTLTexture` / `MTLTextureDescriptor` (2D) | ✅ Done |
| `MTLHeap` | ✅ Done |
| `MTLBlitCommandEncoder` (copy, upload) | ✅ Done |
| `CAMetalLayer` / `CAMetalDrawable` (swapchain) | ✅ Done |
| Argument buffers (`MTLArgumentEncoder`) | 🚧 Stub — no-op |

### Compute & Ray Tracing

| Feature | Status |
|---|---|
| `MTLComputeCommandEncoder` | ✅ Done |
| Acceleration structures — BLAS / TLAS | ✅ Done |
| Ray queries (`VK_KHR_ray_query`) from compute shaders | ✅ Done |
| Intersection function tables | ❌ Not supported (see [Known Limitations](#known-limitations)) |

### Rendering (Raster)

| Feature | Status |
|---|---|
| Render pipeline — vertex/fragment shaders, blending (`MTLRenderCommandEncoder`) | ✅ Done |
| Vertex descriptors (`MTLVertexDescriptor`) | ✅ Done |
| Depth / stencil (`MTLDepthStencilState`) | ✅ Done |
| Samplers (`MTLSamplerState`) | ✅ Done |
| Instanced draws (`instanceCount` on draw calls) | ✅ Done |

---

## Requirements

- **Windows 10/11** (64-bit) - the only tested platform for now; Linux is planned
- **[Vulkan SDK](https://vulkan.lunarg.com/sdk/home)** ≥ 1.3 with ray-tracing extensions (`VK_KHR_acceleration_structure`, `VK_KHR_ray_query`). The SDK also bundles `glslc` (in `Bin/`), which the `CompileShaders` plugin uses to build shaders — no separate install needed. When installing, also tick the **SPIRV-Reflect source** component (the build compiles SPIRV-Reflect from `<SDK>/Source/SPIRV-Reflect`; a default install omits it and the build fails with a missing-header error).
- **Swift 6.2+** ([Swift for Windows](https://www.swift.org/install/windows/))
- The `VULKAN_INSTALL` environment variable must point to your SDK root before building:
  ```bat
  :: cmd
  set VULKAN_INSTALL=C:\VulkanSDK\1.4.341.1
  ```
  ```powershell
  # PowerShell
  $env:VULKAN_INSTALL = 'C:\VulkanSDK\1.4.341.1'
  ```
  To set it permanently, add it under *Settings → System → About → Advanced system settings → Environment Variables*.

The SDK is only needed to **build**. Running a built app requires just a Vulkan-capable GPU driver (the Vulkan runtime ships with graphics drivers).

---

## Building & Testing

With the [Requirements](#requirements) in place (`VULKAN_INSTALL` set), build and test from the repo root:

```powershell
swift build
swift test
```

The test suite covers device/queue creation, buffer allocation, an end-to-end compute dispatch with CPU readback, BLAS/TLAS size queries, and offscreen render-and-readback assertions for depth testing and stencil masking. Tests require a Vulkan-capable GPU; on a machine without one (e.g. headless CI) the whole suite skips cleanly instead of failing.

Each example is its own package — run one with:

```powershell
cd Examples/SDFTextSimple
swift run
```

---

## Examples

| Example | Description |
|---|---|
| [SimpleCompute](Examples/SimpleCompute) | Doubles a buffer of integers on the GPU - minimal end-to-end walkthrough |
| [RayTracedCube](Examples/RayTracedCube) | Builds BLAS/TLAS acceleration structures and ray-casts a cube in a compute shader, writing the image above to a PPM file |
| [RasterizedCube](Examples/RasterizedCube) | Renders the same scene through the raster pipeline - vertex/fragment shaders, depth buffer, texture sampling, Blinn-Phong lighting |
| [SDFTextSimple](Examples/SDFTextSimple) | Anti-aliased MSDF text - two fonts at five sizes from one atlas each, single-file walkthrough of the CPU/GPU division of labor |

---

## Getting Started

### Add as a Swift Package dependency

```swift
// Package.swift
.package(url: "https://github.com/Nishad-Sharma/MoltenMTL.git", branch: "main"),
```

```swift
// Your target
.target(name: "MyApp", dependencies: ["MoltenMTL"]),
```

### Minimal compute dispatch

```swift
import MoltenMTL

// 1. Initialise the GPU device (picks the first Vulkan-capable adapter)
guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("No Vulkan-capable GPU found")
}

// 2. Load a SPIR-V compute shader
guard let library  = device.makeLibrary(path: "myKernel.spv"),
      let function = library.makeFunction(name: "main") else {
    fatalError("Failed to load shader")
}

// 3. Compile the compute pipeline (SPIR-V bindings are reflected automatically)
let pso = try device.makeComputePipelineState(function: function)

// 4. Allocate a shared (CPU + GPU) buffer
let buffer = device.makeBuffer(length: 1024, options: .storageModeShared)!
buffer.contents().storeBytes(of: UInt32(42), as: UInt32.self)

// 5. Record and submit work
let queue     = device.makeCommandQueue()!
let cmdBuf    = queue.makeCommandBuffer()!
let encoder   = cmdBuf.makeComputeCommandEncoder()!

encoder.setComputePipelineState(pso)
encoder.setBuffer(buffer, offset: 0, index: 0)
encoder.dispatchThreadgroups(MTLSize(width: 64), threadsPerThreadgroup: MTLSize(width: 64))
encoder.endEncoding()

cmdBuf.commit()
cmdBuf.waitUntilCompleted()
```

### Explicit binding layout (when not using SPIR-V reflection)

If your shader is loaded without SPIR-V data, or you want to specify the layout explicitly, use `MTLComputePipelineDescriptor`:

```swift
let desc = MTLComputePipelineDescriptor()
desc.computeFunction         = function
desc.storageBufferCount      = 2   // bindings 0, 1
desc.accelerationStructureCount = 1   // binding 2
desc.storageImageCount       = 1   // binding 3

let pso = try device.makeComputePipelineState(descriptor: desc)
```

Binding slots are assigned in order: storage buffers → acceleration structures → storage images.

---

## Architecture

Each `MTL*` type wraps a Vulkan handle directly. `MTLDevice` holds a `VkDevice`, `MTLCommandBuffer` holds a `VkCommandBuffer`, and so on. Method calls forward to the corresponding Vulkan function with minimal overhead.

| Metal type | Vulkan backing |
|---|---|
| `MTLDevice` | `VkInstance` + `VkPhysicalDevice` + `VkDevice` + queue + VMA allocator |
| `MTLCommandQueue` | `VkQueue` + `VkCommandPool` |
| `MTLCommandBuffer` | `VkCommandBuffer` |
| `MTLBuffer` | `VkBuffer` + VMA allocation |
| `MTLTexture` | `VkImage` + `VkImageView` |
| `MTLHeap` | `VmaPool` (sub-allocation) |
| `MTLComputePipelineState` | `VkPipeline` + `VkPipelineLayout` + `VkDescriptorSetLayout` |
| `MTLRenderPipelineState` | `VkPipeline` (dynamic rendering) + `VkPipelineLayout` + `VkDescriptorSetLayout` |
| `MTLAccelerationStructure` | `VkAccelerationStructureKHR` |
| `CAMetalLayer` / `CAMetalDrawable` | `VkSwapchainKHR` + per-image `VkSemaphore`s |

Memory management uses [VMA (Vulkan Memory Allocator)](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator). `.shared` buffers are persistently host-mapped; `.private` buffers are GPU-only (`DEVICE_LOCAL`).

## Debugging

Set `MOLTENMTL_VALIDATION=1` to enable the Vulkan validation layer (`VK_LAYER_KHRONOS_validation`) for API-usage diagnostics. The layer ships with the Vulkan SDK. It is off by default and skipped gracefully when not installed.

## Known Limitations

- **Windows only** for now. Linux support is planned but untested.
- **Render pipeline gaps:** a single color attachment (no MRT), `.triangle` primitives only, and 2D textures only (no 3D, cube, or array textures). Mipmap generation and texture→texture copies in the blit encoder are not implemented yet.
- **No `commit()` completion handlers.** Use `waitUntilCompleted()` to synchronize with the GPU.
- **Ray tracing is ray queries only** (inline ray tracing in compute shaders, via `VK_KHR_ray_query`). The Vulkan ray-tracing pipeline (`VK_KHR_ray_tracing_pipeline` - raygen/hit/miss stages, shader binding tables) and Metal intersection function tables are not supported. This matches Metal's own model, where rays are traced by calling `intersect()` from compute shaders.
- **`MTLArgumentEncoder`** methods are no-ops. Vulkan uses descriptor sets for resource binding rather than argument buffers. The type exists for Metal source-level compatibility.
- **`storageMode` on textures** has no effect on allocation. Vulkan images always reside in device-local memory. The property exists for API parity with `MTLTextureDescriptor`.
- **`useResource(_:usage:)` and `useHeap(_:)`** are no-ops. Vulkan manages residency automatically through descriptor bindings.

## Acknowledgments

- [Vulkan Memory Allocator](https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator) (MIT) — all buffer/texture/heap memory management
- [SPIRV-Reflect](https://github.com/KhronosGroup/SPIRV-Reflect) (Apache-2.0) — automatic descriptor-layout reflection from SPIR-V; both are compiled from the Vulkan SDK's bundled sources
- [kvSIMD.swift](https://github.com/keyvariable/kvSIMD.swift) — `simd`-compatible vector/matrix types used by the examples
