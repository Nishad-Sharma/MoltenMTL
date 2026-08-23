# Create C API

The goal is to create a metal 4 like C API that can be used from zig or other languages. 
Same concept as MoltenMTL but has a public C API instead of a swift API.
Metal 4 cpp is used as a guide but does not need to comfort 100%.
metal-cpp and vulkan are he backend.

## Shader source and compilation

- HLSL/Slang is the default and only public source format. The C API does not
  expose Slang handles or backend shader-language types.
- `mmtlCreateLibrary()` parses an `MMTLLibraryDescriptor` as a Slang module.
  Compute entry points use ordinary HLSL `[numthreads(...)]`; pipeline creation
  supplies the compute stage to Slang, so `[shader("compute")]` is optional.
- On Metal, pipeline creation asks Slang to link the requested entry point and
  emit MSL, then Metal 4 compiles that generated MSL into the native pipeline.
- The Vulkan backend should use the same module and entry-point model but ask
  Slang for SPIR-V. HLSL source and the public C API should not change by
  backend.
- Use explicit HLSL `register(...)` bindings so the same numeric resource
  bindings map to MMTL argument-table indices and future Vulkan descriptors.
- `moduleName` and `sourcePath` are optional source identities. Use
  `searchPaths` for shared HLSL includes and imported Slang modules.
- Shader compilation diagnostics are available through
  `mmtlGetLastShaderError()`.

The Zig build requires the Slang development package path:

```sh
SLANG_INSTALL=/Users/rishflab/Library/Developer/Slang/2026.14 zig build test
```

## Public C API naming

- Use `MMTL` for public types, `mmtl` for functions, and `MMTL_` for constants.
- Use Vulkan-style action-first function names. The first handle argument already
  identifies the object that owns or receives the operation, so do not translate
  C++ receiver names into the C symbol. For example, use
  `mmtlCreateBuffer(device, ...)`, never `mmtlDeviceNewBuffer(...)`.
- Use established Vulkan-style forms where they make the operation clearer, such
  as `mmtlQueueSubmit(...)`, `mmtlQueueWaitIdle(...)`, and `mmtlCmdDispatchThreads(...)`.
- Keep struct fields and local variables in `camelCase`.

Use Metal 4 as the semantic reference and implement narrow vertical slices in both backends:

Device, queue, allocator and command buffer.
Buffer plus compute dispatch.
Output textures: 2D creation, compute binding and texture copies.
Sampler and sampled-texture support.
Render pipeline, attachment map and triangle.
Presentation: cross-platform surface with platform-specific native creation.
BLAS/TLAS and inline ray queries.
