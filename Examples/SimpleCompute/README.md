# SimpleCompute

Doubles every element in a 64-element GPU buffer, then reads the result back to the CPU.

Demonstrates: device creation, shader loading, compute pipeline, shared buffers, dispatch, readback.

## Requirements

- Windows 10/11 (64-bit)
- Vulkan SDK ≥ 1.3 — [download](https://vulkan.lunarg.com/sdk/home)
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
Input:  [1, 2, 3, 4, 5, 6, 7, 8]
Output: [2, 4, 6, 8, 10, 12, 14, 16]
```

## Editing the shader

Edit `Shaders/add.comp` and re-run `swift run` — the build recompiles it to SPIR-V
for you.
