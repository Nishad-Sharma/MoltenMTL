# RayTracedCube

Ray-traces a cube on the GPU and writes the result to `output.ppm` (256×256).

Demonstrates: BLAS/TLAS acceleration structure builds, instance transforms, ray queries from a compute shader, and pixel readback — the full ray-tracing path through MoltenMTL.

<p align="center">
  <img src="../../docs/raytraced-cube.png" alt="Ray-traced cube output" width="256">
</p>

## Requirements

- Windows 10/11 (64-bit)
- Vulkan SDK ≥ 1.3 with ray-tracing extensions — [download](https://vulkan.lunarg.com/sdk/home)
- A GPU with `VK_KHR_acceleration_structure` + `VK_KHR_ray_query` support
- Swift 6.2+ — [download](https://www.swift.org/install/windows/)
- `VULKAN_INSTALL` pointing at your SDK root:
  ```
  set VULKAN_INSTALL=C:\VulkanSDK\1.4.341.1
  ```

## Build & Run

From this directory:

```
swift run
```

Expected output:
```
[MoltenMTL] GPU: <your GPU name>
[MoltenMTL] Device ready (compute queue family: 0)
BLAS built ✓
TLAS built ✓
Rays cast  ✓
Wrote <path>\output.ppm
```

Open `output.ppm` with any image viewer (IrfanView, GIMP, or a VS Code PPM extension).

## Editing the shader

Edit `Shaders/raytrace.comp` and re-run `swift run` — the build recompiles it to
SPIR-V for you.
