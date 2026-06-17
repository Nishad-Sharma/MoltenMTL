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
swift build
.build\debug\SimpleCompute
```

Expected output:
```
[MoltenMTL] GPU: <your GPU name>
[MoltenMTL] Device ready (compute queue family: 0)
Input:  [1, 2, 3, 4, 5, 6, 7, 8]
Output: [2, 4, 6, 8, 10, 12, 14, 16]
```

## Recompile the shader (optional)

The pre-compiled `Shaders/add.spv` is already checked in. If you modify `add.comp`, recompile with:

```
%VULKAN_INSTALL%\Bin\glslc.exe Shaders\add.comp -o Shaders\add.spv
```
